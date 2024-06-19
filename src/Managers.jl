module Managers

using Rocket

export AbstractManager, ManagerType

abstract type AbstractManager <: Actor{Any} end

ManagerType(::M) where {M<:AbstractManager} = M

end