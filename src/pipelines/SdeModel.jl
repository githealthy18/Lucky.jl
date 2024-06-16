export PreModelPipeline

using Lucky.Pipelines
using Lucky.Models

mutable struct PreModelPipeline <: AbstractPipeline
    archmodel::ArchModel
    markovmodel::MarkovModel

    data::Union{Nothing, <:DataFrame}
end