module Lucky

# ==== Constants & Utils
include("Constants.jl")
using .Constants
export ORDER_SIDE, BUY_SIDE, SELL_SIDE
export OPTION_RIGHT, CALL, PUT

include("Utils.jl")

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
export Cash, Stock, Option

include("Quotes.jl")
using .Quotes
export AbstractQuote, Quote, QuoteType
export timestamp
export PriceQuote, OhlcQuote
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
include("observables/TickQuoteFeeds.jl")
# Do not export feed (too generic name)
using .Feeders
using .TickQuoteFeeds
export TickQuoteFeed

include("Services.jl")
using .Services
# Do not export service (too generic name)

# ==== Rocket Dependant

include("Exchanges.jl")
using .Exchanges
export AbstractExchange, FakeExchange
export QuoteAggregator, PRICE_QUOTES

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

end # module Lucky
