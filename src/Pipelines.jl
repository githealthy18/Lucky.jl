module Pipelines

using Rocket
using DataFrames

export AbstractPipeline

abstract type AbstractPipeline <: Actor{Any} end

PipelineType(::P) where {P<:AbstractPipeline} = P

include("pipelines/SdeModel.jl")

end