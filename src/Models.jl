module Models

using Rocket

export AbstractModel

abstract type AbstractModel <: Actor{Any} end

ModelType(T::Type{<:AbstractModel}, params...) = error("You probably forgot to implement ModelType(::$(T), $(params...))")
ModelType(::M) where {M<:AbstractModel} = M

include("models/ArchModel.jl")
include("models/MarkovModel.jl")
end