export ArchModel

using Lucky.Models
using Lucky.Instruments
using Rocket
using Minio
using ARCHModels
using Serialization


struct ArchModel{I<:Instrument} <: AbstractModel
    model::UnivariateARCHModel
end

function ArchModel(I::Instrument, server::MinioConfig, bucket::String) 
    stream = s3_get(server, bucket, symbol(I) * "/archmodel.jld2")
    model = deserialize(IOBuffer(stream))
    ArchModel{I}(model)
end