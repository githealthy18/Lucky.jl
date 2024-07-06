export ArchModel

using Lucky.Models
using Rocket
using Minio
using ARCHModels
using Serialization


mutable struct ArchModel{S} <: AbstractModel
    model::Union{Nothing, <:UnivariateARCHModel}
end

ModelSymbol(::ArchModel{S}) where S = S

function Rocket.on_next!(model::ArchModel, msg::ReadModelMsg)
    stream = s3_get(msg.server, msg.bucket, String(ModelSymbol(model)) * "/archmodel.jld2")
    model.model = deserialize(IOBuffer(stream))
end