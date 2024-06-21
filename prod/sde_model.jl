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

const REGISTER_REQUEST_SUB = Subject(RegisterRequest)

const BOOTSTRAP_SUB = Subject(BootStrapSystem)

const COMPLETED_REQUESTS_SUB = Subject(CompleteRequestMsg)

const CONNECTION_SUB = Subject(ConnectionMsg)

const DEFAULT_IB_SERVICE = Lucky.service(Val(:interactivebrokers))


const ACCOUNT_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :accountSummary)
const ERROR_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :error)
const NEXT_VALID_ID_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :nextValidId)
const TICK_PRICE_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :tickPrice)
const TICK_SIZE_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :tickSize)
const TICK_OPTION_COMPUTATION_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :tickOptionComputation)
const HISTORICAL_DATA_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :historicalData)
const SEC_DEF_OPTIONAL_PARAM_SUB = Lucky.feed(DEFAULT_IB_SERVICE, :securityDefinitionOptionalParameter)

const DEFAULT_IB_SERVICE_MANAGER = ServiceManager(DEFAULT_IB_SERVICE, nothing, CONNECTION_SUB)

subscribe!(BOOTSTRAP_SUB, DEFAULT_IB_SERVICE_MANAGER)

const DEFAULT_REQUEST_MANAGER = RequestManager(nothing, 1, BitArray{1}(), Vector{Pair{<:Function, <:Tuple}}(), Vector{Pair{<:Function, <:Tuple}}())
subscribe!(REGISTER_REQUEST_SUB, DEFAULT_REQUEST_MANAGER)
subscribe!(BOOTSTRAP_SUB, DEFAULT_REQUEST_MANAGER)
subscribe!(CONNECTION_SUB, DEFAULT_REQUEST_MANAGER)
subscribe!(COMPLETED_REQUESTS_SUB, DEFAULT_REQUEST_MANAGER)

next!(BOOTSTRAP_SUB, BootStrapSystem())

defaultAgg = QuoteAggregator(Dict{DataType, Union{Nothing, PriceQuote}}(LastTick=>nothing, BidTick=>nothing), logger("strategy"), DEFAULT_REQUEST_MANAGER, Rocket.lambda(Dict{DataType, Union{Nothing, PriceQuote}}; on_next=(d)->println(d)))

next!(REGISTER_REQUEST_SUB, RegisterRequest(
    Pair(
        InteractiveBrokers.reqMktData, 
        (InteractiveBrokers.Contract(symbol="AAPL",secType="STK",exchange="SMART",currency="USD"),"",false,false)
    ), 
    Pair(
        InteractiveBrokers.cancelMktData, 
        ()
    ), 
    60000, 
    defaultAgg
    )
)


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
