module Lucky

# ==== Constants & Utils
include("Constants.jl")
using .Constants
export ORDER_SIDE, ENVIRONMENT

include("Utils.jl")

include("Config.jl")
using .Config
export FILESTORE

# ==== Process types
include("Connections.jl")
using .Connections
export Connection, ConnectionType

include("ProcessMsgs.jl")
using .ProcessMsgs
export AbstractProcessMsg, RegisterRequest, RegisterResponse, BootStrapSystem, IncompleteDataRequest, CompleteQuoteMsg, CompleteRequestMsg, ConnectionMsg

include("observables/Requesters.jl")
using .Requesters
export RequestActor

include("Managers.jl")
using .Managers
export AbstractManager, ManagerType
export ServiceManager, RequestManager

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
export AskTick, BidTick, LastTick, OpenTick, HighTick, LowTick, VolumeTick, BidSizeTick, AskSizeTick, LastSizeTick, TickType

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

include("observables/Feeders.jl")
# Do not export feed (too generic name)
using .Feeders

include("Services.jl")
using .Services
# Do not export service (too generic name)

# ==== Rocket Dependant

include("Exchanges.jl")
using .Exchanges
export AbstractExchange, FakeExchange
export QuoteAggregator

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

include("Models.jl")
using .Models
export AbstractModel, ModelType
export ArchModel, MarkovModel

include("Pipelines.jl")
using .Pipelines
export AbstractPipeline, PipelineType
export PreModelPipeline

end # module Lucky
