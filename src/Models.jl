module Models

using Rocket

export AbstractModel, ReadModelMsg

abstract type AbstractModel <: Actor{Any} end

ModelType(T::Type{<:AbstractModel}, params...) = error("You probably forgot to implement ModelType(::$(T), $(params...))")
ModelType(::M) where {I<:AbstractModel} = M

struct ReadModelMsg{S, B}
    server::S
    bucket::B
end

include("models/ArchModel.jl")
include("models/MarkovModel.jl")
end