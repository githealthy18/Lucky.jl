export AbstractQuote
export Quote, QuoteType
export timestamp
export PriceQuote, OhlcQuote, VolumeQuote
export Bid, Ask, Mark, Last, Open, High, Low, Close, Volume, BidSize, AskSize, LastSize

abstract type AbstractQuote end

function quotes end

QuoteType(I::Type{<:Instrument}, params...) = error("You probably forgot to implement QuoteType(::$(I), $(params...))")
QuoteType(Q::Type{<:AbstractQuote}) = Q
TimestampType(Q::Type{<:AbstractQuote}) = error("You probably forgot to implement TimestampType(::$(Q))")

abstract type AbstractTick end

struct Bid <: AbstractTick end
struct Ask <: AbstractTick end
struct Mark <: AbstractTick end
struct Last <: AbstractTick end
struct Open <: AbstractTick end
struct High <: AbstractTick end
struct Low <: AbstractTick end
struct Close <: AbstractTick end
struct Volume <: AbstractTick end
struct BidSize <: AbstractTick end
struct AskSize <: AbstractTick end
struct LastSize <: AbstractTick end
struct OpenInterest <: AbstractTick end
struct AverageOptVolume <: AbstractTick end

TickType(T::Type{<:AbstractTick}, params...) = error("You probably forgot to implement TickType(::$(T), $(params...))")
TickType(::T) where {T<:AbstractTick} = T

struct PriceQuote{I,T,Q,S,D} <: AbstractQuote
    instrument::I
    tick::T
    price::Q
    size::S
    timestamp::D
end

struct OhlcQuote{I,T,Q} <: AbstractQuote
    instrument::I
    tick::T
    ohlc::Q
end

struct VolumeQuote{I,T,Q,D} <: AbstractQuote
    instrument::I
    tick::T
    volume::Q
    timestamp::D
end

# Interfaces
Quote(instrument::Instrument, tick::T, price::Q, size::S, stamp::D) where {T<:AbstractTick,Q<:Union{Nothing,Number},S<:Union{Nothing,Number},D<:Dates.AbstractTime} = PriceQuote(instrument, tick, price, size, stamp)
Quote(instrument::Instrument, tick::T, ohlc::Q) where {T<:AbstractTick, Q<:Ohlc} = OhlcQuote(instrument, tick, ohlc)
Quote(instrument::Instrument, tick::T, volume::Q, stamp::D) where {T<:AbstractTick,Q<:Number,D<:Dates.AbstractTime} = VolumeQuote(instrument, tick, volume, stamp)

QuoteType(I::Type{<:Instrument}, T::Type{<:AbstractTick}, Q::Type{<:Ohlc}) = OhlcQuote{I,T,Q}
QuoteType(I::Type{<:Instrument}, T::Type{<:AbstractTick}, S::Type{<:Number}, P::Type{<:Number}, D::Type{<:Dates.AbstractTime}=Dates.DateTime) = PriceQuote{I,T,P,S,D}
QuoteType(I::Type{<:Instrument}, T::Type{<:AbstractTick}, V::Type{<:Number}, D::Type{<:Dates.AbstractTime}=Dates.DateTime) = VolumeQuote{I,T,V,D}
QuoteType(i::Instrument, T::Type{<:AbstractTick}, Q::Type{<:Ohlc}) = QuoteType(InstrumentType(i), T, Q)
QuoteType(i::Instrument, T::Type{<:AbstractTick}, S::Type{<:Number}, P::Type{<:Number}, D::Type{<:Dates.AbstractTime}=DateTime) = QuoteType(InstrumentType(i), T, P, S, D)
QuoteType(i::Instrument, T::Type{<:AbstractTick}, V::Type{<:Number}, D::Type{<:Dates.AbstractTime}=DateTime) = QuoteType(InstrumentType(i), T, V, D)

TickType(::PriceQuote{I,T,P,S,D}) where {I,T,P,S,D} = T
TickType(::VolumeQuote{I,T,V,D}) where {I,T,V,D} = T
TickType(::Type{<:PriceQuote{I,T,P,S,D}}) where {I,T,P,S,D} = T
TickType(::Type{<:VolumeQuote{I,T,V,D}}) where {I,T,V,D} = T

currency(q::AbstractQuote) = currency(q.instrument)
timestamp(q::OhlcQuote) = q.ohlc.timestamp
timestamp(q::PriceQuote) = q.timestamp
timestamp(q::VolumeQuote) = q.timestamp

TimestampType(::Type{<:OhlcQuote{I,T,O}}) where {I,T,O} = TimestampType(O)
TimestampType(::Type{<:PriceQuote{I,T,P,S,D}}) where {I,T,P,S,D} = D
TimestampType(::Type{<:VolumeQuote{I,T,V,D}}) where {I,T,V,D} = D

import Base: +, -, *, /, convert, isless
# https://github.com/JuliaLang/julia/blob/0a8916446b782eae1a09681b2b47c1be26fab7f3/base/missing.jl#L119
for f in (:(+), :(-)) #, :(*), :(/), :(^), :(mod), :(rem))
    @eval begin
        ($f)(::Missing, ::AbstractQuote) = missing
        ($f)(::AbstractQuote, ::Missing) = missing
    end
end

+(x::I, y::I) where {I<:PriceQuote} = I(x.instrument, x.tick, x.price + y.price, mean((x.size, y.size)), max(timestamp(x), timestamp(y)))
-(x::I, y::I) where {I<:PriceQuote} = I(x.instrument, x.tick, x.price - y.price, mean((x.size, y.size)), max(timestamp(x), timestamp(y)))
*(x::I, y::N) where {I<:PriceQuote,N<:Number} = I(x.instrument, x.tick, x.price * y, x.size, timestamp(x))
/(x::I, y::N) where {I<:PriceQuote,N<:Number} = I(x.instrument, x.tick, x.price / y, x.size, timestamp(x))
convert(T::Type{<:Number}, x::PriceQuote) = convert(T, x.price)
isless(x::I, y::I) where {I<:PriceQuote} = isless(x.price, y.price)

+(x::I, y::I) where {I<:OhlcQuote} = I(x.instrument, x.tick, x.ohlc + y.ohlc)
-(x::I, y::I) where {I<:OhlcQuote} = I(x.instrument, x.tick, x.ohlc - y.ohlc)
*(x::I, y::N) where {I<:OhlcQuote,N<:Number} = I(x.instrument, x.tick, x.ohlc * y)
/(x::I, y::N) where {I<:OhlcQuote,N<:Number} = I(x.instrument, x.tick, x.ohlc / y)
convert(T::Type{<:Number}, x::OhlcQuote) = convert(T, x.ohlc)
isless(x::I, y::I) where {I<:OhlcQuote} = isless(x.ohlc, y.ohlc)

+(x::I, y::I) where {I<:VolumeQuote} = I(x.instrument, x.tick, x.volume + y.volume, max(timestamp(x), timestamp(y)))
-(x::I, y::I) where {I<:VolumeQuote} = I(x.instrument, x.tick, x.volume - y.volume, max(timestamp(x), timestamp(y)))
*(x::I, y::N) where {I<:VolumeQuote,N<:Number} = I(x.instrument, x.tick, x.volume * y, timestamp(x))
/(x::I, y::N) where {I<:VolumeQuote,N<:Number} = I(x.instrument, x.tick, x.volume / y, timestamp(x))
convert(T::Type{<:Number}, x::VolumeQuote) = convert(T, x.volume)
isless(x::I, y::I) where {I<:VolumeQuote} = isless(x.volume, y.volume)
