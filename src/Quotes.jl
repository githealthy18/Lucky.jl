module Quotes

export AbstractQuote
export Quote, QuoteType
export timestamp
export PriceQuote, OhlcQuote, VolumeQuote

using Lucky.Instruments
using Lucky.Ohlcs
import Lucky.Units as Units

using Dates
using Statistics

abstract type AbstractQuote end

QuoteType(I::Type{<:Instrument}, params...) = error("You probably forgot to implement QuoteType(::$(I), $(params...))")
QuoteType(Q::Type{<:AbstractQuote}) = Q
Units.TimestampType(Q::Type{<:AbstractQuote}) = error("You probably forgot to implement TimestampType(::$(Q))")

struct PriceQuote{I,Q,S,D} <: AbstractQuote
    instrument::I
    price::Q
    size::S
    timestamp::D
end

struct OhlcQuote{I,Q} <: AbstractQuote
    instrument::I
    ohlc::Q
end

struct VolumeQuote{I,Q,D} <: AbstractQuote
    instrument::I
    volume::Q
    timestamp::D
end

# Interfaces
Quote(instrument::Instrument, price::Q, size::S, stamp::D) where {Q<:Union{Nothing,Number},S<:Union{Nothing,Number},D<:Dates.AbstractTime} = PriceQuote(instrument, price, size, stamp)
Quote(instrument::Instrument, ohlc::Q) where {Q<:Ohlc} = OhlcQuote(instrument, ohlc)
Quote(instrument::Instrument, volume::Q, stamp::D) where {Q<:Number,D<:Dates.AbstractTime} = VolumeQuote(instrument, volume, stamp)

QuoteType(I::Type{<:Instrument}, Q::Type{<:Ohlc}) = OhlcQuote{I,Q}
QuoteType(I::Type{<:Instrument}, P::Type{<:Number}=Float64, S::Type{<:Number}=Float64, D::Type{<:Dates.AbstractTime}=Dates.DateTime) = PriceQuote{I,P,S,D}
QuoteType(I::Type{<:Instrument}, V::Type{<:Number}, D::Type{<:Dates.AbstractTime}=Dates.DateTime) = VolumeQuote{I,V,D}
QuoteType(i::Instrument, Q::Type{<:Ohlc}) = QuoteType(InstrumentType(i), Q)
QuoteType(i::Instrument, P::Type{<:Number}=Float64, S::Type{<:Number}=Float64, D::Type{<:Dates.AbstractTime}=DateTime) = QuoteType(InstrumentType(i), P, S, D)
QuoteType(i::Instrument, V::Type{<:Number}, D::Type{<:Dates.AbstractTime}=DateTime) = QuoteType(InstrumentType(i), V, D)

Units.currency(q::AbstractQuote) = Units.currency(q.instrument)
timestamp(q::OhlcQuote) = q.ohlc.timestamp
timestamp(q::PriceQuote) = q.timestamp

Units.TimestampType(::Type{<:OhlcQuote{I,O}}) where {I,O} = Units.TimestampType(O)
Units.TimestampType(::Type{<:PriceQuote{I,P,S,D}}) where {I,P,S,D} = D

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

+(x::I, y::I) where {I<:VolumeQuote} = I(x.instrument, x.volume + y.volume, max(timestamp(x), timestamp(y)))
-(x::I, y::I) where {I<:VolumeQuote} = I(x.instrument, x.volume - y.volume, max(timestamp(x), timestamp(y)))
*(x::I, y::N) where {I<:VolumeQuote,N<:Number} = I(x.instrument, x.volume * y, timestamp(x))
/(x::I, y::N) where {I<:VolumeQuote,N<:Number} = I(x.instrument, x.volume / y, timestamp(x))
convert(T::Type{<:Number}, x::VolumeQuote) = convert(T, x.volume)
isless(x::I, y::I) where {I<:VolumeQuote} = isless(x.volume, y.volume)

end