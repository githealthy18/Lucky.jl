using Lucky
using LibPQ
using DBInterface
using DuckDB
using Minio
using AWSS3
using Serialization
using ARCHModels
using MarSwitching
using Dates
using TimeZones
using LibPQ
using DataFrames
using SQLStrings
using FunSQL: From, Fun, Where, Get, DB
using Impute
using ShiftedArrays
using BusinessDays
using Rocket
using Setfield
using AQFED; using AQFED.American
import AQFED.TermStructure: ConstantBlackModel
import AQFED.American: makeFDMPriceInterpolation
using FredData
using Knapsacks
using Oxygen
using ForwardDiff
import AQFED.Black
using HTTP
using StatsBase
using Lucky

function Rocket.on_next!(pipeline::PreModelPipeline, msg::HistoricalDataMsg)
    pipeline.data = msg.dataframe
end

function Rocket.on_next!(pipeline::PreModelPipeline, msg::RunPipelineMsg)
    historicalDataActor = IBRequestActor{HistoricalDataMsg}(0, 0, nothing, pipeline)
    historicalDataActor.subscription = subscribe!(HistoricalDataSub, historicalDataActor)
    next!(registerRequestSubject, RegisterRequest(
        Pair(
            InteractiveBrokers.reqHistoricalData, 
            (
                InteractiveBrokers.Contract(symbol=String(PipelineSymbol(pipeline)),secType="STK",exchange="SMART",currency="USD"),
                "",
                "3 Y",
                "1 day",
                "TRADES",
                false,
                1, 
                false
            )
        ), 
        Pair(
            InteractiveBrokers.cancelHistoricalData, 
            ()
        ), 
        30000, 
        historicalDataActor
        )
    )
end


mutable struct SDEModel{A} <: AbstractStrategy
    cashPosition::Union{Nothing,CashPositionType}
    stockPosition::Union{Nothing,StockPositionType}
    optionPosition::Union{Nothing,OptionPositionType}
    preModel::ModelType
    prevSlowSMA::SlowIndicatorType
    prevFastSMA::FastIndicatorType
    slowSMA::SlowIndicatorType
    fastSMA::FastIndicatorType
    next::A
end
