export AbstractOrderBook
export orderbook
export match

abstract type AbstractOrderBook end

@inline orderbook(s::Symbol) = orderbook(Val(s))

struct InMemoryOrderBook <: AbstractOrderBook
    pendingOrders::Dict{Instrument,Vector{AbstractOrder}}
end

orderbook(::Val{:inmemory}) = InMemoryOrderBook(Dict{Instrument,Vector{AbstractOrder}}())

@inline match(ord::MarketOrder, qte::PriceQuote) = fillPriceQuote(ord, qte)
function match(ord::LimitOrder, qte::PriceQuote)
    ord.size >= zero(ord.size) && ord.limit >= qte.price && return fillPriceQuote(ord,qte)
    ord.size <= zero(ord.size) && ord.limit <= qte.price && return fillPriceQuote(ord,qte)
    return nothing
end

# OHLC handling
@inline match(ord::MarketOrder, qte::OhlcQuote) = match(ord, Quote(qte.instrument, qte.tick, qte.ohlc.open, timestamp(qte)))
function match(ord::LimitOrder, qte::OhlcQuote)
    ord.limit >= qte.ohlc.low && ord.limit <= qte.ohlc.high && return Fill(fillUUID(), ord, ord.limit, ord.size, fee(ord, ord.limit), timestamp(qte))
    return nothing
end

@inline fillPriceQuote(ord, qte) = Fill(fillUUID(), ord, qte.price, ord.size, fee(ord, qte.price), timestamp(qte))

fillUUID() = string(uuid5(uuid4(), "FakeExchange"))