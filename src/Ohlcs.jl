export Ohlc

export OHLC_PART, body, top, bottom
export gap, ohlcpart

struct Ohlc{T<:Dates.AbstractTime}
    open::Float64
    high::Float64
    low::Float64
    close::Float64
    time::T
end

Base.show(io::IO, ohlc::Ohlc{T}) where {T<:Dates.AbstractTime} = show(io, "Ohlc @ $(ohlc.time): O:$(ohlc.open) H:$(ohlc.high) L:$(ohlc.low) C:$(ohlc.close)")

TimestampType(::Type{Ohlc{T}}) where {T} = T
TimestampType(o::Ohlc{T}) where {T} = T

@enum OHLC_PART body top bottom
@inline function ohlcpart(ohlc::Ohlc, ::Val{body})
    ohlc.open > ohlc.close && return [ohlc.close, ohlc.open]
    return [ohlc.open, ohlc.close]
end

@inline ohlcpart(ohlc::Ohlc, ::Val{top}) = [max(ohlc.open, ohlc.close), ohlc.high]
@inline ohlcpart(ohlc::Ohlc, ::Val{bottom}) = [ohlc.low, min(ohlc.open, ohlc.close)]
@inline ohlcpart(ohlc::Ohlc, part::OHLC_PART) = ohlcpart(ohlc, Val(part))


@inline function gap(ohlc::Ohlc, ref::Ohlc)
    ohlc.low > ref.high && return (up, [ref.high, ohlc.low])
    ohlc.high < ref.low && return (down, [ohlc.high, ref.low])
    return nothing
end

struct Volume{T<:Dates.AbstractTime}
    volume::Float64
    time::T
end

Base.show(io::IO, volume::Volume{T}) where {T<:Dates.AbstractTime} = show(io, "Volume @ $(volume.time): $(volume.volume)")
TimestampType(::Type{Volume{T}}) where {T} = T
TimestampType(v::Volume{T}) where {T} = T

struct Bar{T<:Dates.AbstractTime}
    ohlc::Ohlc{T}
    volume::Volume{T}
end

Base.show(io::IO, bar::Bar{T}) where {T<:Dates.AbstractTime} = show(io, "Bar @ $(bar.ohlc.time): $(bar.ohlc) $(bar.volume)")
TimestampType(::Type{Bar{T}}) where {T} = T
TimestampType(b::Bar{T}) where {T} = T

struct HistoricalData{T<:Dates.AbstractTime}
    bar::DataFrame
    time::T
end

# Operators
import Base: +, -, *, /, convert, isless, push!
+(x::I, y::I) where {I<:Ohlc} = I(x.open, max(x.high, y.high), min(x.low, y.low), y.close, max(x.time, y.time))
+(x::I, y::N) where {I<:Volume,N<:Number} = I(x.volume + y, x.time)
+(x::I, y::N) where {I<:Ohlc, N<:Volume} = Bar(x, y)
push!(x::I, y::N) where {I<:Ohlc, N<:Volume}  = Bar(x, y)
push!(x::I, y::N) where {I<:Volume, N<:Ohlc}  = Bar(y, x)
push!(x::I, y::N) where {I<:HistoricalData, N<:Bar}  = HistoricalData(vcat(x.bar, DataFrame(y)), y.time)
#-(x::I, y::I) where {I<:Ohlc} = I(x.ohlc - y.ohlc)
*(x::I, y::N) where {I<:Ohlc,N<:Number} = I(x.open * y, x.high * y, x.low * y, x.close * y, x.time)
*(x::I, y::N) where {I<:Volume,N<:Number} = I(x.volume * y, x.time)
/(x::I, y::N) where {I<:Ohlc,N<:Number} = I(x.open / y, x.high / y, x.low / y, x.close / y, x.time)
/(x::I, y::N) where {I<:Volume,N<:Number} = I(x.volume / y, x.time)
# Convert on close
convert(T::Type{<:Number}, x::Ohlc) = convert(T, x.close)
isless(x::I, y::I) where {I<:Ohlc} = isless(x.close, y.close)
convert(T::Type{<:Volume}, x::Volume) = convert(T, x.volume)
isless(x::I, y::I) where {I<:Volume} = isless(x.volume, y.volume)

# Rocket stuffs
Rocket.scalarness(::Type{<:Ohlc{T}}) where {T} = Rocket.Scalar()
Rocket.scalarness(::Type{<:Volume{T}}) where {T} = Rocket.Scalar()
Rocket.scalarness(::Type{<:Bar{T}}) where {T} = Rocket.Scalar()