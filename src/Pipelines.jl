module Pipelines

export AbstractPipeline, PipelineType, BuildPipelineMsg, RunPipelineMsg

using Lucky.Constants
using Rocket
using DataFrames

abstract type AbstractPipeline <: Actor{Any} end

PipelineType(::P) where {P<:AbstractPipeline} = P

struct BuildPipelineMsg
    stage::ENVIRONMENT
end

struct RunPipelineMsg 
    stage::ENVIRONMENT
end

include("pipelines/SdeModel.jl")

end