module Pipelines

using Rocket
using DataFrames

export AbstractPipeline

abstract type AbstractPipeline <: Actor{Any} end

PipelineType(::P) where {P<:AbstractPipeline} = P

struct Pipeline{D<:DataFrame,S<:Real,D} <: AbstractPipeline
    data::D
    size::S
    timestamp::D
end

PositionType(instrument::Instrument, S::Type{<:Real}, Q::Type{<:Any}) = Position{InstrumentType(instrument),S,Units.TimestampType(Q)}
Units.TimestampType(::Position{I,S,D}) where {I,S,D} = D
Units.currency(::Position{I,S}) where {I<:Instrument,S} = Units.currency(I)

end