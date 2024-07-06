export ArchModel

using Lucky.Models
using Rocket
using Minio
using ARCHModels
using Serialization


struct ArchModel{I<:Instrument, S} <: AbstractModel
    server::S
    bucket::String
    model::UnivariateARCHModel

    ArchModel{I}(server::S, bucket::String) where {I, S} = begin
        stream = s3_get(server, bucket, symbol(I) * "/archmodel.jld2")
        model = deserialize(IOBuffer(stream))
        new{I, S, B}(server, bucket, model)
    end
end