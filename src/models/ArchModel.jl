export ArchModel, ReadModelMsg

using Minio
using ARCHModels
using Serialization
const cfg = MinioConfig("http://localhost:9000")

struct ArchModel{S} <: AbstractModel
    model::Union{Nothing, <:UnivariateARCHModel}
end

Base.eltype(::Type{ArchModel{S}}) where {S} = S

struct ReadModelMsg{S, B}
    server::S
    bucket::B
    suffix::String
end

function Rocket.on_next!(model::ArchModel, msg::ReadModelMsg)
    stream = s3_get(msg.server, msg.bucket, String(eltype(model)) * "/" * msg.suffix)
    model.model = deserialize(IOBuffer(stream))
end