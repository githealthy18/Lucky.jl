module Managers

using Rocket

export AbstractManager, ManagerType

abstract type AbstractManager <: Actor{Any} end

ManagerType(::M) where {M<:AbstractManager} = M

include("managers/RequestManagers.jl")
include("managers/ServiceManagers.jl")
end