export PreModelPipeline

using Lucky.Pipelines
using Lucky.Models
using Lucky.Config
using InteractiveBrokers

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

function Rocket.on_next!(pipeline::PreModelPipeline, msg::HistoricalDataMsg)
    pipeline.data = msg.dataframe
end

function Rocket.on_next!(pipeline::PreModelPipeline, msg::RunPipelineMsg)
    historicalDataActor = IBRequestActor{HistoricalDataMsg}(0, 0, nothing, pipeline)
    historicalDataActor.subscription = subscribe!(HistoricalDataSub, historicalDataActor)
    next!(registerRequestSubject, RegisterRequest(
        Pair(
            InteractiveBrokers.reqHistoricalData, 
            (
                InteractiveBrokers.Contract(symbol=String(PipelineSymbol(pipeline)),secType="STK",exchange="SMART",currency="USD"),
                "",
                "3 Y",
                "1 day",
                "TRADES",
                false,
                1, 
                false
            )
        ), 
        Pair(
            InteractiveBrokers.cancelHistoricalData, 
            ()
        ), 
        30000, 
        historicalDataActor
        )
    )
end