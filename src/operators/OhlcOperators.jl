module OhlcOperators

export ohlc

using Lucky.Ohlcs

using Rocket
using Dates

# Operator
ohlc(period::Dates.Period, cutoff::Bool=true, seedTime::Union{Nothing,DateTime}=nothing, seedPrice::Union{Nothing,DateTime}=nothing) = OhlcOperatorFromTrade(seedTime, seedTime, period, seedPrice, seedPrice, seedPrice, seedPrice, cutoff, false)

mutable struct OhlcOperatorFromTrade <: LeftTypedOperator{Any}
    first::Union{Nothing,DateTime}
    last::Union{Nothing,DateTime}
    period::Dates.Period
    open::Union{Nothing,Float64}
    high::Union{Nothing,Float64}
    low::Union{Nothing,Float64}
    close::Union{Nothing,Float64}
    cutoff::Bool
    set::Bool
end 

Rocket.operator_right(::OhlcOperatorFromTrade, ::Type{L}) where {L} = Ohlc

function Rocket.on_call!(::Type{L}, ::Type{R}, operator::OhlcOperatorFromTrade, source) where {L,R}
    return proxy(R, source, OhlcSourceProxy(operator.first, operator.last, operator.period, operator.open, operator.high, operator.low, operator.close, operator.cutoff, operator.set))
end

# Proxy
mutable struct OhlcSourceProxy <: ActorProxy
    first::Union{Nothing,DateTime}
    last::Union{Nothing,DateTime}
    period::Dates.Period
    open::Union{Nothing,Float64}
    high::Union{Nothing,Float64}
    low::Union{Nothing,Float64}
    close::Union{Nothing,Float64}
    cutoff::Bool
    set::Bool
end

function Rocket.actor_proxy!(::Type{Ohlc}, proxy::OhlcSourceProxy, actor::A) where {A}
    return OhlcObservableFromTrade{A}(proxy.first, proxy.last, proxy.period, proxy.open, proxy.high, proxy.low, proxy.close, proxy.cutoff, proxy.set, actor)
end

# Observable
mutable struct OhlcObservableFromTrade{A} <: Actor{Any} where {A}
    first::Union{Nothing,DateTime}
    last::Union{Nothing,DateTime}
    period::Dates.Period
    open::Union{Nothing,Float64}
    high::Union{Nothing,Float64}
    low::Union{Nothing,Float64}
    close::Union{Nothing,Float64}
    cutoff::Bool
    set::Bool
    next::A
end

Rocket.on_error!(actor::OhlcObservableFromTrade, error) = error!(actor.next, error)
Rocket.on_complete!(actor::OhlcObservableFromTrade) = complete!(actor.next)

end