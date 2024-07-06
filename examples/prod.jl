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
using Lucky.Utils: after_hours

BusinessDays.initcache(:USNYSE)

const cfg = MinioConfig("http://localhost:9000")

function base_processor(data::DataFrame)
    df = copy(data)
    dropmissing!(df)
    # df[!,2:end] = convert.(Float32, df[!,2:end])
    df.time = DateTime.(df.time, "yyyymmdd")
    date_vec = df.time[begin]:Day(1):df.time[end] |> collect
    date_df = DataFrame(time=date_vec)
    df = outerjoin(df, date_df, on=:time)
    sort!(df, [:time])
    Impute.interp!(df)
    df.returns = (log.(df.close) - ShiftedArrays.lag(log.(df.close)))
    dropmissing!(df)
    bday_col = assign_businessday(df[:, 1])
    return data
end

mutable struct PreModelProcessor{S, A} <: AbstractStrategy
    processor::Function
    markov::MarkovModel{S}
    arch::ArchModel{S}
    next::A
end

PreModelProcessor(processor::Function, markov::MarkovModel{S}, arch::ArchModel{S}, next::A) where {S, A} = PreModelProcessor(missing, processor, markov, arch, next)

function Rocket.on_next!(step::PreModelProcessor, data::DataFrame)
    result = step.processor(data)
    next!(step.next, result)
    next!(step.markov, result.returns)
    next!(step.arch, result.returns)
end

mutable struct PreModelDataset{S} <: AbstractStrategy
    data::Union{Missing, DataFrame}
end

PreModelDataset(::I) where {I<:Instrument} = PreModelDataset{I}(missing)

function Rocket.on_next!(step::PreModelDataset, data::DataFrame)
    step.data = data
end

function Rocket.on_next!(step::PreModelDataset, msg::MarkovPrediction)
    println("Markov Prediction: $(msg)")
end

function Rocket.on_next!(step::PreModelDataset, msg::ArchPrediction)
    println("Arch Prediction: $(msg)")
end

mutable struct PreModel{A} <: AbstractStrategy
    data::DataFrame
    open::Union{Missing, Lucky.PriceQuote{I,Open,P,S,D} where {I,P,S,D}}
    high::Union{Missing,Lucky.PriceQuote{I,High,P,S,D} where {I,P,S,D}}
    low::Union{Missing, Lucky.PriceQuote{I,Low,P,S,D} where {I,P,S,D}}
    close::Union{Missing, Lucky.PriceQuote{I,Close,P,S,D} where {I,P,S,D}, Lucky.PriceQuote{I,Mark,P,S,D} where {I,P,S,D}}
    volume::Union{Missing, Lucky.VolumeQuote{I,Volume,P,D} where {I,P,D}}
    next::A
end

PreModel(next::A) where {A} = PreModel(DataFrame(), missing, missing, missing, missing, missing, next)

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

client = Lucky.service(:interactivebrokers)
connect(client)


stock = Stock(:AAPL,:USD)
stockType = InstrumentType(stock)
dataset = PreModelDataset(stock)
premodelProcessor = PreModelProcessor(base_processor, MarkovModel(stockType, cfg, "prod", dataset), ArchModel(stockType, cfg, "prod", dataset), dataset)
actor = PreModel(lambda(DataFrame; on_complete = ()->println("Done!")))
hist = Lucky.feed(client, stock, Val(:historicaldata))
feeds = Lucky.feed(client, stock, Val(:livedata))
source = merged((hist |> first(), feeds.openPrice |> first(), feeds.highPrice |> first(), feeds.lowPrice |> first(), feeds.markPrice |> first(), feeds.volume |> first()))
subscribe!(source, actor)
InteractiveBrokers.reqMarketDataType(client, InteractiveBrokers.FROZEN)

mutable struct GoldenCross{A} <: AbstractStrategy
    cashPosition::Union{Nothing,CashPositionType}
    aaplPosition::Union{Nothing,StockPositionType}
    prevSlowSMA::SlowIndicatorType
    prevFastSMA::FastIndicatorType
    slowSMA::SlowIndicatorType
    fastSMA::FastIndicatorType
    next::A
end