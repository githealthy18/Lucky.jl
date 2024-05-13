module Managers

using Rocket

export AbstractManager, ManagerType
export BaseManager

abstract type AbstractManager <: Actor{Any} end

ManagerType(::M) where {M<:AbstractManager} = M

struct BaseManager{A, B} <: AbstractManager
    data_connection::A
    broker_connection::B
end

end