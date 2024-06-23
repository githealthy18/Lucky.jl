module Quotes

export AbstractQuote
export Quote, QuoteType
export timestamp
export PriceQuote, OhlcQuote
export AbstractTick, TickType

using Lucky.Instruments
using Lucky.Ohlcs
import Lucky.Units as Units

using Dates
using Statistics

abstract type AbstractQuote end
abstract type AbstractTick end

QuoteType(I::Type{<:Instrument}, params...) = error("You probably forgot to implement QuoteType(::$(I), $(params...))")
QuoteType(Q::Type{<:AbstractQuote}) = Q
Units.TimestampType(Q::Type{<:AbstractQuote}) = error("You probably forgot to implement TimestampType(::$(Q))")

TickType(T::Type{<:AbstractTick}, params...) = error("You probably forgot to implement TickType(::$(T), $(params...))")
TickType(::T) where {T<:AbstractTick} = T

struct PriceQuote{I,T,Q,S,D} <: AbstractQuote
    instrument::I
    tick::T
    price::Q
    size::S
    timestamp::D
end

struct OhlcQuote{I,Q} <: AbstractQuote
    instrument::I
    ohlc::Q
end

# Interfaces
Quote(instrument::Instrument, tick::T, price::Q, size::S, stamp::D) where {T<:AbstractTick,Q<:Number,S<:Number,D<:Dates.AbstractTime} = PriceQuote(instrument, tick, price, size, stamp)
Quote(instrument::Instrument, ohlc::Q) where {Q<:Ohlc} = OhlcQuote(instrument, ohlc)

QuoteType(I::Type{<:Instrument}, Q::Type{<:Ohlc}) = OhlcQuote{I,Q}
QuoteType(I::Type{<:Instrument}, T::Type{<:AbstractTick}, P::Type{<:Number}=Float64, S::Type{<:Number}=Float64, D::Type{<:Dates.AbstractTime}=Dates.DateTime) = PriceQuote{I,T,P,S,D}
QuoteType(i::Instrument, Q::Type{<:Ohlc}) = QuoteType(InstrumentType(i), Q)
QuoteType(i::Instrument, T::Type{<:AbstractTick}, P::Type{<:Number}=Float64, S::Type{<:Number}=Float64, D::Type{<:Dates.AbstractTime}=DateTime) = QuoteType(InstrumentType(i), T, P, S, D)

Units.currency(q::AbstractQuote) = Units.currency(q.instrument)
timestamp(q::OhlcQuote) = q.ohlc.timestamp
timestamp(q::PriceQuote) = q.timestamp

Units.TimestampType(::Type{<:OhlcQuote{I,O}}) where {I,O} = Units.TimestampType(O)
Units.TimestampType(::Type{<:PriceQuote{I,T,P,S,D}}) where {I,T,P,S,D} = D

import Base: +, -, *, /, convert, isless
# https://github.com/JuliaLang/julia/blob/0a8916446b782eae1a09681b2b47c1be26fab7f3/base/missing.jl#L119
for f in (:(+), :(-)) #, :(*), :(/), :(^), :(mod), :(rem))
    @eval begin
        ($f)(::Missing, ::AbstractQuote) = missing
        ($f)(::AbstractQuote, ::Missing) = missing
    end
end

+(x::I, y::I) where {I<:PriceQuote} = I(x.instrument, x.price + y.price, mean((x.size, y.size)), max(timestamp(x), timestamp(y)))
-(x::I, y::I) where {I<:PriceQuote} = I(x.instrument, x.price - y.price, mean((x.size, y.size)), max(timestamp(x), timestamp(y)))
*(x::I, y::N) where {I<:PriceQuote,N<:Number} = I(x.instrument, x.price * y, x.size, timestamp(x))
/(x::I, y::N) where {I<:PriceQuote,N<:Number} = I(x.instrument, x.price / y, x.size, timestamp(x))
convert(T::Type{<:Number}, x::PriceQuote) = convert(T, x.price)
isless(x::I, y::I) where {I<:PriceQuote} = isless(x.price, y.price)

+(x::I, y::I) where {I<:OhlcQuote} = I(x.instrument, x.ohlc + y.ohlc)
-(x::I, y::I) where {I<:OhlcQuote} = I(x.instrument, x.ohlc - y.ohlc)
*(x::I, y::N) where {I<:OhlcQuote,N<:Number} = I(x.instrument, x.ohlc * y)
/(x::I, y::N) where {I<:OhlcQuote,N<:Number} = I(x.instrument, x.ohlc / y)
convert(T::Type{<:Number}, x::OhlcQuote) = convert(T, x.ohlc)
isless(x::I, y::I) where {I<:OhlcQuote} = isless(x.ohlc, y.ohlc)

end