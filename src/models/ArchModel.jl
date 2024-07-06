export ArchModel

using Lucky.Models
using Lucky.Instruments
import Lucky.Units as Units
using Rocket
using Minio
using ARCHModels
using Serialization


struct ArchModel{I<:Instrument} <: AbstractModel
    model::UnivariateARCHModel
end

function ArchModel(I::Instrument, server::MinioConfig, bucket::String) 
    stream = s3_get(server, bucket, Units.symbol(I) * "/archmodel.jld2")
    model = deserialize(IOBuffer(stream))
    ArchModel{I}(model)
end