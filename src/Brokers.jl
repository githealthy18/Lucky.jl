module Brokers

export AbstractBroker, AbstractAccount

using Rocket

abstract type AbstractBroker <: Actor{Any} end

abstract type AbstractAccount <: Actor{Any} end

struct ConnectMsg
    port::Int
end

struct DisconnectMsg end

struct Connection
    conn
end

connectSubject = Subject(ConnectMsg)
disconnectSubject = Subject(DisconnectMsg)

connections = Subject(Connection)


include("brokers/InteractiveBrokers.jl")
using .InteractiveBrokers
export IB, IBAccount
end