module Lucky

include("Connections.jl")
using .Connections
export Connection, ConnectionType

include("ProcessMsgs.jl")
using .ProcessMsgs
export AbstractProcessMsg, RegisterRequest, RegisterResponse, BootStrapSystem, IncompleteDataRequest, CompleteQuoteMsg, CompleteRequestMsg, ConnectionMsg

include("observables/Feeders.jl")
# Do not export feed (too generic name)
using .Feeders

include("observables/Requesters.jl")
using .Requesters
export RequestActor


include("Services.jl")
using .Services
# Do not export service (too generic name)

# ==== Constants & Utils
include("Constants.jl")
using .Constants
export ORDER_SIDE, ENVIRONMENT
export REGISTER_REQUEST_SUBJECT, BOOT_STRAP_SUBJECT, COMPLETED_REQUESTS, CONNECTION_SUB
export DEFAULT_IB_SERVICE, ACCOUNT_SUB, ERROR_SUB, NEXT_VALID_ID_SUB, TICK_PRICE_SUB, TICK_SIZE_SUB, TICK_OPTION_COMPUTATION_SUB, HISTORICAL_DATA_SUB, SEC_DEF_OPTIONAL_PARAM_SUB
export DEFAULT_IB_SERVICE_MANAGER, DEFAULT_REQUEST_MANAGER

include("Utils.jl")

include("Config.jl")
using .Config
export FILESTORE

# ==== Financial types
include("Units.jl")
using .Units
export Unit, UnitType, Currency, CurrencyType, TimestampType
export symbol, currency

include("Ohlcs.jl")
using .Ohlcs
export Ohlc, Bar, Volume, HistoricalData

include("Instruments.jl")
using .Instruments
export Instrument, InstrumentType
export Cash, Stock, Option, DataRequest

include("Quotes.jl")
using .Quotes
export AbstractQuote, Quote, QuoteType
export timestamp
export PriceQuote, OhlcQuote, PriceQuotes

include("Positions.jl")
using .Positions
export Position, PositionType

include("Orders.jl")
using .Orders
export AbstractOrder, OrderType
export LimitOrder, MarketOrder

include("Fills.jl")
using .Fills
export AbstractFill, FillType
export Fill

include("Indicators.jl")
using .Indicators
export AbstractIndicator, IterableIndicator, ValueIndicator, IndicatorType
export DrawdownIndicator, EMAIndicator, HighWaterMarkIndicator, PeriodicValueIndicator, RollingIndicator, SMAIndicator

# ==== Rocket Dependant

include("Exchanges.jl")
using .Exchanges
export AbstractExchange, FakeExchange

include("Blotters.jl")
using .Blotters
export AbstractBlotter
export InMemoryBlotter

include("Operators.jl")
using .Operators
export drawdown, ema, highwatermark, ohlc, rolling, sma

include("Strategies.jl")
using .Strategies
export AbstractStrategy

include("Managers.jl")
using .Managers
export AbstractManager, ManagerType

include("Models.jl")
using .Models
export AbstractModel, ModelType
export ArchModel, MarkovModel

include("Pipelines.jl")
using .Pipelines
export AbstractPipeline, PipelineType
export PreModelPipeline

end # module Lucky
