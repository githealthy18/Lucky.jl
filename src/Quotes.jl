module Quotes

export AbstractQuote
export Quote, QuoteType
export timestamp
export PriceQuote, OhlcQuote
export AbstractTick
export BidTick, AskTick, LastTick, OpenTick, HighTick, LowTick, CloseTick
export VolumeTick, BidSizeTick, AskSizeTick, LastSizeTick

using Lucky.Instruments
using Lucky.Ohlcs
using Lucky.ProcessMsgs
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