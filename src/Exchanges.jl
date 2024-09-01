export AbstractExchange, exchange, placeorder

@inline exchange(s::Symbol, params...) = exchange(Val(s), params...)

abstract type AbstractExchange <: Actor{Any} end

placeorder(x::Any) = error("You probably forgot to implement placeorder($(x))")