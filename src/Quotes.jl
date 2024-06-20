module Quotes

export AbstractQuote
export Quote, QuoteType
export timestamp
export PriceQuote, OhlcQuote, PRICE_QUOTES
export AbstractTick
export BidTick, AskTick, LastTick, OpenTick, HighTick, LowTick, CloseTick

using Lucky.Instruments
using Lucky.Ohlcs
import Lucky.Units as Units

using Dates

abstract type AbstractQuote end

QuoteType(I::Type{<:Instrument}, params...) = error("You probably forgot to implement QuoteType(::$(I), $(params...))")
QuoteType(Q::Type{<:AbstractQuote}) = Q
Units.TimestampType(Q::Type{<:AbstractQuote}) = error("You probably forgot to implement TimestampType(::$(Q))")

abstract type AbstractTick end

struct BidTick <: AbstractTick end
struct AskTick <: AbstractTick end
struct LastTick <: AbstractTick end
struct OpenTick <: AbstractTick end
struct HighTick <: AbstractTick end
struct LowTick <: AbstractTick end
struct CloseTick <: AbstractTick end
struct VolumeTick <: AbstractTick end
struct BidSizeTick <: AbstractTick end
struct AskSizeTick <: AbstractTick end
struct LastSizeTick <: AbstractTick end

TickType(T::Type{<:AbstractTick}, params...) = error("You probably forgot to implement TickType(::$(T), $(params...))")
TickType(::T) where {T<:AbstractTick} = T

struct PriceQuote{I,Q,D,T} <: AbstractQuote
    instrument::I
    price::Q
    timestamp::D
    tick::T
end

struct OhlcQuote{I,Q} <: AbstractQuote
    instrument::I
    ohlc::Q
end

# struct BidQuote{Q, D} <: PriceQuote
#     tickerId::Int
#     price::Q
#     timestamp::D
# end

# struct AskQuote{Q, D} <: PriceQuote
#     tickerId::Int
#     price::Q
#     timestamp::D
# end

# struct LastQuote{Q, D} <: PriceQuote
#     tickerId::Int
#     price::Q
#     timestamp::D
# end

# struct OpenQuote{Q, D} <: PriceQuote
#     tickerId::Int
#     price::Q
#     timestamp::D
# end

# struct HighQuote{Q, D} <: PriceQuote
#     tickerId::Int
#     price::Q
#     timestamp::D
# end

# struct LowQuote{Q, D} <: PriceQuote
#     tickerId::Int
#     price::Q
#     timestamp::D
# end

# Rocket Subjects

const PRICE_QUOTES = Subject(PriceQuote)

# Interfaces
Quote(instrument::Instrument, price::Q, stamp::D, tick::T) where {Q<:Number,D<:Dates.AbstractTime,T<:AbstractTick} = PriceQuote(instrument, price, stamp, tick)
Quote(instrument::Instrument, ohlc::Q) where {Q<:Ohlc} = OhlcQuote(instrument, ohlc)

QuoteType(I::Type{<:Instrument}, Q::Type{<:Ohlc}) = OhlcQuote{I,Q}
QuoteType(I::Type{<:Instrument}, T::Type{<:AbstractTick}, P::Type{<:Number}=Float64, D::Type{<:Dates.AbstractTime}=Dates.DateTime) = PriceQuote{I,P,D,T}
QuoteType(i::Instrument, Q::Type{<:Ohlc}) = QuoteType(InstrumentType(i), Q)
QuoteType(i::Instrument, P::Type{<:Number}=Float64, D::Type{<:Dates.AbstractTime}=DateTime) = QuoteType(InstrumentType(i), P, D)

Units.currency(q::AbstractQuote) = Units.currency(q.instrument)
timestamp(q::OhlcQuote) = q.ohlc.timestamp
timestamp(q::PriceQuote) = q.timestamp

Units.TimestampType(::Type{<:OhlcQuote{I,O}}) where {I,O} = Units.TimestampType(O)
Units.TimestampType(::Type{<:PriceQuote{I,P,D}}) where {I,P,D} = D

mutable struct QuoteAggregator{S, R, A} <: Actor{Union{RegisterResponse, PriceQuote, <:CompleteQuoteMsg, IncompleteDataRequest}}
    tickerId::Union{Nothing, Int}
    queueId::Union{Nothing, Int}
    bundle::Dict{DataType, Union{Nothing, PriceQuote}}
    subscription::Union{Nothing, Rocket.SubjectSubscription}
    strategy::S
    requestManager::R
    next::A
end

QuoteAggregator(bundle::Dict{DataType, Union{Nothing,PriceQuote}}, strategy::S, requestManager::R, next::A) where {S, R, A} = QuoteAggregator(
    nothing, 
    nothing,
    bundle,
    nothing,
    strategy,
    requestManager,
    next
)

Rocket.on_next!(actor::QuoteAggregator, quotes::PriceQuote) = begin
    if eltype(quotes.instrument) == actor.tickerId
        actor.bundle[typeof(quotes.tick)] = quotes
        next!(actor, CompleteQuoteMsg(quotes))
    end
end

function Rocket.on_next!(actor::QuoteAggregator, msg::RegisterResponse) 
    actor.tickerId = msg.reqId
    actor.queueId = msg.queueId

    actor.subscription = subscribe!(PRICE_QUOTES, actor)
end

Rocket.on_next!(actor::QuoteAggregator, msg::CompleteQuoteMsg) = begin
    if haskey(actor.subjects, msg.body) 
        unsubscribe!(actor.subscription)
        delete!(actor.subjects, msg.body)
        if isempty(actor.subjects)
            complete!(actor)
        end
    end
end

function Rocket.on_next!(actor::QuoteAggregator, msg::IncompleteDataRequest)
    unsubscribe!(subscription)
    next!(actor.strategy, false)
end

Rocket.on_complete!(actor::QuoteAggregator) = begin
    next!(actor.next, actor.bundle)
    next!(actor.requestManager, CompleteRequestMsg(actor.tickerId, actor.queueId))
end


import Base: +, -, *, /, convert, isless
# https://github.com/JuliaLang/julia/blob/0a8916446b782eae1a09681b2b47c1be26fab7f3/base/missing.jl#L119
for f in (:(+), :(-)) #, :(*), :(/), :(^), :(mod), :(rem))
    @eval begin
        ($f)(::Missing, ::AbstractQuote) = missing
        ($f)(::AbstractQuote, ::Missing) = missing
    end
end

+(x::I, y::I) where {I<:PriceQuote} = I(x.instrument, x.price + y.price, max(timestamp(x), timestamp(y)))
-(x::I, y::I) where {I<:PriceQuote} = I(x.instrument, x.price - y.price, max(timestamp(x), timestamp(y)))
*(x::I, y::N) where {I<:PriceQuote,N<:Number} = I(x.instrument, x.price * y, timestamp(x))
/(x::I, y::N) where {I<:PriceQuote,N<:Number} = I(x.instrument, x.price / y, timestamp(x))
convert(T::Type{<:Number}, x::PriceQuote) = convert(T, x.price)
isless(x::I, y::I) where {I<:PriceQuote} = isless(x.price, y.price)

+(x::I, y::I) where {I<:OhlcQuote} = I(x.instrument, x.ohlc + y.ohlc)
-(x::I, y::I) where {I<:OhlcQuote} = I(x.instrument, x.ohlc - y.ohlc)
*(x::I, y::N) where {I<:OhlcQuote,N<:Number} = I(x.instrument, x.ohlc * y)
/(x::I, y::N) where {I<:OhlcQuote,N<:Number} = I(x.instrument, x.ohlc / y)
convert(T::Type{<:Number}, x::OhlcQuote) = convert(T, x.ohlc)
isless(x::I, y::I) where {I<:OhlcQuote} = isless(x.ohlc, y.ohlc)

end