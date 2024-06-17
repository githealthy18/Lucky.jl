export PreModelPipeline

using Lucky.Pipelines
using Lucky.Models
using Lucky.Config
using Lucky.Constants

mutable struct PreModelPipeline{S} <: AbstractPipeline
    archmodel::ArchModel{S}
    markovmodel::MarkovModel{S}

    historical_data::Union{Nothing, <:DataFrame}
    live_data::Union{Nothing, <:Dict}
end

PipelineSymbol(::PreModelPipeline{S}) where S = S

function Rocket.on_next!(pipeline::PreModelPipeline, msg::BuildPipelineMsg)
    next!(pipeline.archmodel, ReadModelMsg(FILESTORE, lowercase(Symbol(msg.stage))))
    next!(pipeline.markovmodel, ReadModelMsg(FILESTORE, lowercase(Symbol(msg.stage))))
end