using Dates
using Lucky
using Rocket
using DataFrames
using InteractiveBrokers
using BusinessDays
using Minio
using Impute
using ShiftedArrays
using Lucky.Quotes: Last, Bid, Ask, Mark, High, Low, Close, Open, Volume, AskSize, BidSize, LastSize
using Lucky.Utils: after_hours, assign_businessday
using Dictionaries
@everywhere using PyCall
@everywhere import Pandas

function pd_to_df(df_pd)
    colnames = PyAny.(df_pd.columns.values)
    vv = Vector[]
    for c in colnames
      col = get(df_pd, c)
      v =  col.values
      if v isa PyObject
        T = Vector{typeof(col[1])}
        v = convert(T,  col)
      elseif !isa(col[1], PyObject)
        v = [col[i] for i in 1:length(col)]
      elseif v[1] isa PyObject
        PyAny.(v)
      else
        v
      end
      push!(vv, v)
    end
    DataFrame(vv, Symbol.(colnames))
  end

function __init__()
@everywhere py"""
import sys
from datetime import date
sys.path.append(r"C:\Users\Ande Olson\OneDrive - The Gunter Group\Documents\Python Projects\SDE Colab")
sys.path.append(r"/Users/andeolson/Documents/PythonProjects/ScoreGradPred")
sys.path.append(r"/Users/andeolson/Documents/PythonProjects/CfC")

import psycopg2

import matplotlib.pyplot as plt
import pandas as pd
import torch
from torch.multiprocessing import Pool
torch.multiprocessing.set_start_method('spawn', force=True)
import numpy as np
from gluonts.dataset.multivariate_grouper import MultivariateGrouper
from gluonts.dataset.util import to_pandas
from gluonts.dataset.field_names import FieldName
from gluonts.dataset.common import ListDataset
import time
from configs.config import get_configs
from score_sde.score_sde_estimator import ScoreGradEstimator
from score_sde.trainer import Trainer
from utils import *
import multiprocess as mp
from sqlalchemy import create_engine
engine = create_engine('postgresql://andeolson:@localhost:5432/prod')

def create_prediction_set(symbol, data, future_bday_df, prediction_length=1):
    data.set_index('time', inplace=True)
    bday = data["bday"]
    bday = pd.concat([bday] * 15, axis=1, ignore_index=True)
    future_bday = pd.concat([future_bday_df] * 15, axis=1, ignore_index=True)
    future_bday = torch.tensor(future_bday.values).unsqueeze(0)
    data = data.drop(columns="bday")
    config = get_configs(dataset=f'{symbol}_cfc', name='subvpsde')
    # Sets a common random seed - both for initialization and ensuring graph is the same
    torch.manual_seed(config.seed)
    future_bday = future_bday.to(config.device)

    data = data.dropna()

    custom_ds_metadata = {
        'num_series': 15,
        'num_steps': 30,
        'prediction_length': prediction_length,
        'freq': '1D',
        'start': [
            data.index[0]
            for _ in range(15)
        ]
    }
    feat_static_cat = list(range(0,15))

    ds = ListDataset(
        [
            {
                FieldName.TARGET: target,
                FieldName.START: start,
                FieldName.FEAT_STATIC_CAT: [fsc],
                FieldName.FEAT_DYNAMIC_CAT: [fdc],
            }
            for (target, start, fsc, fdc) in zip(
                data.values.T,
                custom_ds_metadata['start'],
                feat_static_cat, 
                bday.values.T,)
        ],
        freq=custom_ds_metadata['freq']
    )


    pred_grouper = MultivariateGrouper(max_target_dim=min(2000, int(len(data.columns))))

    pred_ds = pred_grouper(ds)

    pred_ds[0]["feat_dynamic_cat"] = np.array(bday.values.T)

    estimator = ScoreGradEstimator(
        input_size=config.input_size,
        freq=custom_ds_metadata['freq'],
        prediction_length=custom_ds_metadata['prediction_length'],
        target_dim=int(len(data.columns)),
        context_length=custom_ds_metadata['num_steps'],
        num_layers=config.num_layers,
        num_cells=config.num_cells,
        cell_type='CfC',
        num_parallel_samples=config.num_parallel_samples,
        dropout_rate=config.dropout_rate,
        conditioning_length=config.conditioning_length,
        diff_steps=config.modeling.num_scales,
        beta_min=config.modeling.beta_min,
        beta_end=config.modeling.beta_max,
        residual_layers=config.modeling.residual_layers,
        residual_channels=config.modeling.residual_channels,
        dilation_cycle_length=config.modeling.dilation_cycle_length,
        scaling=config.modeling.scaling,
        md_type=config.modeling.md_type,
        continuous=config.training.continuous,
        reduce_mean=config.reduce_mean,
        likelihood_weighting=config.likelihood_weighting,
        config=config,
        future_dynamic_cat=future_bday,
        trainer=Trainer(
            epochs=config.epochs,
            batch_size=config.batch_size,
            num_batches_per_epoch=config.num_batches_per_epoch,
            learning_rate=config.learning_rate,
            decay=config.weight_decay,
            device=config.device,
            wandb_mode='offline',
            config=config))

    trainnet = estimator.create_training_network(config.device)
    checkpoint = torch.load(config.path)
    trainnet.load_state_dict(checkpoint['model_state_dict'])
    transformation = estimator.create_transformation()
    predictor = estimator.create_predictor(transformation, trainnet, config.device)
    forecast_it = predictor.predict(pred_ds, num_samples=100)
    forecasts = list(forecast_it)[0]
    prediction_dataframe = pd.DataFrame(forecasts._sorted_samples[:, 0, :], columns=data.columns)
    prediction_dataframe["symbol"] = symbol
    prediction_dataframe["date"] = date.today()
    # prediction_dataframe.to_sql("prediction", engine, index=False, schema="trade", if_exists="append", method="multi")
    return prediction_dataframe
"""
end

BusinessDays.initcache(:USNYSE)

const cfg = MinioConfig("http://localhost:9000")

struct PredictActor <: Actor{Any}
    remotecalls::Dictionary{Instrument,Future}
end

struct PredictionDataMsg{I}
    instrument::I
    data::DataFrame
    bday::DataFrame
end

struct FetchPrediction{I, A} 
    instrument::I
    next::A
end

const predictionSubject = Subject(PredictionDataMsg; scheduler = Rocket.ThreadsScheduler())

function Rocket.on_next!(actor::PredictActor, msg::PredictionDataMsg{I}) where {I}
    pandas_data = Pandas.DataFrame(msg.data)
    pandas_bday = Pandas.DataFrame(msg.bday)
    stock = symbol(I)
    insert!(actor.remotecalls, I, @spawnat :any py"create_prediction_set"(stock, pandas_data, pandas_bday))
end

function Rocket.on_next!(actor::PredictActor, msg::FetchPrediction{I}) where {I}
    data = fetch(actor.remotecalls[I])
    df = pd_to_df(data)
    next!(msg.next, df)
end

const predictActor = PredictActor(Dictionaries.Dictionary{Instrument,Future}())

subscribe!(predictionSubject, predictActor)

function base_processor(data::DataFrame)
    df = copy(data[!, [:time, :high, :low, :open, :close, :volume]])
    dropmissing!(df)
    df.time = DateTime.(df.time, "yyyymmdd")
    date_vec = df.time[begin]:Day(1):df.time[end] |> collect
    date_df = DataFrame(time=date_vec)
    df = outerjoin(df, date_df, on=:time)
    sort!(df, [:time])
    Impute.interp!(df)
    df.returns = (log.(df.close) - ShiftedArrays.lag(log.(df.close)))
    dropmissing!(df)
    bday_col = assign_businessday(df[:, 1])
    df.bday = bday_col
    return df
end

mutable struct PreModelProcessor{I, A} <: AbstractStrategy
    instrument::I
    processor::Function
    markov::MarkovModel{I}
    arch::ArchModel{I}
    next::A
end

function Rocket.on_next!(step::PreModelProcessor, data::DataFrame)
    result = step.processor(data)
    next!(step.next, result)
    Threads.@spawn next!(step.markov, result.returns)
    Threads.@spawn next!(step.arch, result.returns)
end

mutable struct PreModelDataset{I} <: AbstractStrategy
    instrument::I
    data::Union{Missing, DataFrame}
end

PreModelDataset(I::Instrument) = PreModelDataset(I, missing)

function Rocket.on_next!(step::PreModelDataset, data::DataFrame)
    step.data = data
end

function Rocket.on_complete!(step::PreModelDataset{I}) where {I}
    dropmissing!(step.data)
    step.data[!,2:end] = convert.(Float32, step.data[!,2:end])

    select!(step.data,[:time, :high, :low, :open, :close, :volume, :returns, :vars, :volatilities, :variances1, :vars1, :volatilities1, :beta, :prob1, :prob2, :prob3, :bday])
    dr = Dates.today()+Day(1):Day(1):Dates.today()+Day(7) |> collect
    future_bdays = assign_businessday(dr)
    future_bday_df = DataFrame(bday=future_bdays)
    next!(predictionSubject, PredictionDataMsg(I, step.data, future_bday_df))
    println("Completed PreModelDataset")
end

function Rocket.on_next!(step::PreModelDataset{I}, msg::MarkovPrediction{I}) where {I}
    step.data.beta = msg.beta
    step.data.prob1 = msg.regime1
    step.data.prob2 = msg.regime2
    step.data.prob3 = msg.regime3
end

function Rocket.on_next!(step::PreModelDataset{I}, msg::ArchPrediction{I}) where {I}
    step.data.vars = msg.vars
    step.data.volatilities = msg.volatilities
    step.data.variances1 = msg.pred_variances
    step.data.vars1 = msg.pred_vars
    step.data.volatilities1 = msg.pred_vols
end

mutable struct PreModel{I,A} <: AbstractStrategy
    instrument::I
    data::DataFrame
    open::Union{Missing, Lucky.PriceQuote{I,Open,P,S,D} where {P,S,D}}
    high::Union{Missing,Lucky.PriceQuote{I,High,P,S,D} where {P,S,D}}
    low::Union{Missing, Lucky.PriceQuote{I,Low,P,S,D} where {P,S,D}}
    close::Union{Missing, Lucky.PriceQuote{I,Close,P,S,D} where {P,S,D}, Lucky.PriceQuote{I,Mark,P,S,D} where {P,S,D}}
    volume::Union{Missing, Lucky.VolumeQuote{I,Volume,P,D} where {P,D}}
    next::A
end

PreModel(I::Instrument, next::A) where {A} = PreModel(I, DataFrame(), missing, missing, missing, missing, missing, next)

function Rocket.on_next!(strat::PreModel, data::DataFrame)
    strat.data = data
end

function Rocket.on_next!(strat::PreModel, data::Lucky.PriceQuote{I,T,P,S,D}) where {I,T<:Mark,P,S,D}
    strat.close = data
end

function Rocket.on_next!(strat::PreModel, data::Lucky.PriceQuote{I,T,P,S,D}) where {I,T,P,S,D}
    setproperty!(strat, Symbol(lowercase(String(Symbol(T)))), data)
end

function Rocket.on_next!(strat::PreModel, data::Lucky.VolumeQuote{I,T,S,D}) where {I,T,S,D}
    setproperty!(strat, Symbol(lowercase(String(Symbol(T)))), data)
end

function Rocket.on_complete!(strat::PreModel)
    if !after_hours()
        strat.data.high[end] = strat.high.price
        strat.data.low[end] = strat.low.price
        strat.data.close[end] = strat.close.price
        strat.data.open[end] = strat.open.price
        strat.data.volume[end] = strat.volume.volume
    end
    next!(strat.next, strat.data)
end

mutable struct ChainData{I,A} <: AbstractStrategy
    client
    instrument::I
    spot::Union{Missing, Lucky.PriceQuote{I,Mark,P,S,D} where {P,S,D}}
    expiration_count::Int
    strike_tolerance::Float64
    next::A
end

ChainData(I::Instrument, client, next::A) where {A} = ChainData(client, I, missing, 4, 0.05, next)
ChainData(I::Type{<:Instrument}, client, next::A) where {A} = ChainData{I,A}(client, missing, 4.0, 0.05, next)

function Rocket.on_next!(strat::PostModel{I,A}, data::Lucky.PriceQuote) where {I,A}
    strat.spot = data

    expirationSubject, strikeSubject = Lucky.feed(strat.client, strat.instrument, Val(:securityDefinitionOptionalParameter))
    source = combineLatest(expirationSubject |> take(strat.expiration_count), strikeSubject |> filter((d) -> isapprox(d, strat.spot.price; rtol=strat.strike_tolerance))) |> merge_map(Tuple, d -> from([CALL, PUT]) |> map(Tuple, r -> (d..., r))) |> map(Option, d -> Option(strat.instrument, d[3], d[2], d[1]))
    subscribe!(source, strat.next)
end

function Rocket.on_complete!(strat::PostModel)
    next!(strat.next, strat.spot)
end

mutable struct OptionProcessor{I,A} <: AbstractStrategy
    instrument::I
    spot::Union{Missing, Lucky.PriceQuote{I,Mark,P,S,D} where {P,S,D}}
    chain::Vector{Lucky.Option}
    next::A
end

OptionProcessor(I::Instrument, next::A) where {A} = OptionProcessor(I, missing, Vector{Lucky.Option}(), next)

function Rocket.on_next!(strat::OptionProcessor{I, A}, data::Lucky.PriceQuote{I,Mark,P,S,D}) where {I,A,P,S,D}
    strat.spot = data
end

function Rocket.on_next!(strat::OptionProcessor{I, A}, data::Lucky.Option{I, R, K, E}) where {I,A,R,K,E}
    push!(strat.chain, data)
end

function Rocket.on_complete!(strat::OptionProcessor)
    next!(strat.next, strat.chain)
end

client = Lucky.service(:interactivebrokers)
connect(client)

InteractiveBrokers.reqMarketDataType(client, InteractiveBrokers.REALTIME)
stock = Stock(:AAPL,:USD)
stockType = InstrumentType(stock)
dataset = PreModelDataset(stock)

data = Subject(DataFrame)
markov = Subject(MarkovPrediction; scheduler = Rocket.ThreadsScheduler())
arch = Subject(ArchPrediction; scheduler = Rocket.ThreadsScheduler())

source = merged((data |> first(), markov |> first(), arch |> first()))

subscribe!(source, dataset)

premodelProcessor = PreModelProcessor(stock, base_processor, MarkovModel(stockType, cfg, "prod", markov), ArchModel(stockType, cfg, "prod", arch), data)
actor = PreModel(stock, premodelProcessor)
hist = Lucky.feed(client, stock, Val(:historicaldata))
feeds = Lucky.feed(client, stock, Val(:livedata); timeout=60000)
source = merged((hist |> first(), feeds.openPrice |> first(), feeds.highPrice |> first(), feeds.lowPrice |> first(), feeds.markPrice |> first(), feeds.volume |> first()))
subscribe!(source, actor)
# InteractiveBrokers.reqMarketDataType(client, InteractiveBrokers.FROZEN)

postModel = PostModel(stock, client, lambda(Int; on_next=(d)->println(d)))
subscribe!(feeds.markPrice |> first(), postModel)

mutable struct GoldenCross{A} <: AbstractStrategy
    cashPosition::Union{Nothing,CashPositionType}
    aaplPosition::Union{Nothing,StockPositionType}
    prevSlowSMA::SlowIndicatorType
    prevFastSMA::FastIndicatorType
    slowSMA::SlowIndicatorType
    fastSMA::FastIndicatorType
    next::A
end

r1 = @spawnat :any py"create_prediction_set"("AAPL", dist_df, dist_bday)
r2 = @spawnat :any py"create_prediction_set"("AAPL", dist_df, dist_bday)