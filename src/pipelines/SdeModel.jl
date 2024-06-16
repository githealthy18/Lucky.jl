

using Lucky.Pipelines
using Lucky.Models

mutable struct PreModelPipeline <: AbstractPipeline
    name::String
    description::String
    archmodel::Union{Nothing, <:ArchModel}
    markovmodel::Union{Nothing, <:MarkovModel}

    data::Union{Nothing, <:DataFrame}
end