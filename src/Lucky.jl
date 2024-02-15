module Lucky

# ==== Constants
include("Constants.jl")
using .Constants
export ORDER_SIDE

# ==== Financial types
include("Units.jl")
using .Units
export Unit, UnitType, Currency, CurrencyType, TimestampType
export symbol, currency

include("Ohlcs.jl")
using .Ohlcs
export Ohlc

include("Instruments.jl")
using .Instruments
export Instrument, InstrumentType
export Cash, Stock

include("Quotes.jl")
using .Quotes
export AbstractQuote, Quote, QuoteType
export timestamp

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
export AbstractIndicator, IndicatorType
export SMAIndicator

# ==== Rocket Dependant

include("Exchanges.jl")
using .Exchanges
export AbstractExchange, FakeExchange, FakePosition

include("Blotters.jl")
using .Blotters
export AbstractBlotter
export InMemoryBlotter

include("Operators.jl")
using .Operators
export ohlc, rolling, sma

include("Strategies.jl")
using .Strategies
export AbstractStrategy

# === Others

include("Performances.jl")
using .Performances
export drawdown

end # module Lucky
