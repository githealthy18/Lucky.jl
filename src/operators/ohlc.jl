export ohlc

# Operator
ohlc(period::Dates.Period, cutoff::Bool=true, seedTime::Union{Nothing,DateTime}=nothing, seedPrice::Union{Nothing,DateTime}=nothing, seedVolume::Union{Nothing, Float64}=nothing) = OhlcOperatorFromTrade(seedTime, seedTime, period, seedPrice, seedPrice, seedPrice, seedPrice, seedVolume, cutoff, false)

struct OhlcOperatorFromTrade <: InferableOperator
    first::Union{Nothing,DateTime}
    last::Union{Nothing,DateTime}
    period::Dates.Period
    open::Union{Nothing,Float64}
    high::Union{Nothing,Float64}
    low::Union{Nothing,Float64}
    close::Union{Nothing,Float64}
    volume::Union{Nothing,Float64}
    cutoff::Bool
    set::Bool
end

Rocket.operator_right(::OhlcOperatorFromTrade, ::Type{L}) where {L} = Ohlc

function Rocket.on_call!(::Type{L}, ::Type{R}, operator::OhlcOperatorFromTrade, source) where {L,R}
    return proxy(R, source, OhlcSourceProxy{L}(operator.first, operator.last, operator.period, operator.open, operator.high, operator.low, operator.close, operator.volume, operator.cutoff, operator.set))
end

# Proxy
struct OhlcSourceProxy{LeftType} <: ActorProxy
    first::Union{Nothing,DateTime}
    last::Union{Nothing,DateTime}
    period::Dates.Period
    open::Union{Nothing,Float64}
    high::Union{Nothing,Float64}
    low::Union{Nothing,Float64}
    close::Union{Nothing,Float64}
    volume::Union{Nothing,Float64}
    cutoff::Bool
    set::Bool
end

function Rocket.actor_proxy!(::Type{Ohlc}, proxy::OhlcSourceProxy{LeftType}, actor::A) where {A,LeftType}
    return OhlcObservableFromTrade{A,LeftType}(proxy.first, proxy.last, proxy.period, proxy.open, proxy.high, proxy.low, proxy.close, proxy.volume, proxy.cutoff, proxy.set, actor)
end

# Observable
mutable struct OhlcObservableFromTrade{A,LeftType} <: Actor{LeftType}
    first::Union{Nothing,DateTime}
    last::Union{Nothing,DateTime}
    period::Dates.Period
    open::Union{Nothing,Float64}
    high::Union{Nothing,Float64}
    low::Union{Nothing,Float64}
    close::Union{Nothing,Float64}
    volume::Union{Nothing,Float64}
    cutoff::Bool
    set::Bool
    next::A
end

Rocket.on_error!(actor::OhlcObservableFromTrade, error) = error!(actor.next, error)
Rocket.on_complete!(actor::OhlcObservableFromTrade) = complete!(actor.next)