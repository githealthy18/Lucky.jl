export ArchModel, ReadModelMsg

using Lucky.Models
using Rocket
using Minio
using MarSwitching
using Serialization


mutable struct MarkovModel{S} <: AbstractModel
    model::Union{Nothing, <:MSM}
end

Base.eltype(::Type{ArchModel{S}}) where {S} = S

function Rocket.on_next!(model::ArchModel, msg::ReadModelMsg)
    stream = s3_get(msg.server, msg.bucket, String(eltype(model)) * "/archmodel.jld2")
    model.model = deserialize(IOBuffer(stream))
end