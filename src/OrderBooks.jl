export AbstractOrderBook
export orderbook

using Dictionaries

abstract type AbstractOrderBook end

@inline orderbook(s::Symbol) = orderbook(Val(s))

struct InMemoryOrderBook <: AbstractOrderBook
    pendingOrders::Dictionary{Type{<:Instrument},Vector{AbstractOrder}}
end

orderbook(::Val{:inmemory}) = InMemoryOrderBook(Dictionary{Type{<:Instrument},Vector{AbstractOrder}}())
