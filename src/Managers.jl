module Managers

export AbstractManager, ManagerType
export BaseManager

abstract type AbstractManager end

ManagerType(::M) where {M<:AbstractManager} = M

struct BaseManager{A, B} <: AbstractManager
    data_connection::A
    broker_connection::B
end

end