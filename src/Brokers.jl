module Brokers

export AbstractBroker, AbstractAccount

using Rocket

abstract type AbstractBroker <: Actor{Any} end

abstract type AbstractAccount <: Actor{Any} end

include("brokers/InteractiveBrokers.jl")
using .InteractiveBrokers
export IB, IBAccount
end