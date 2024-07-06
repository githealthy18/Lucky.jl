export MarkovModel

using Lucky.Models
using Rocket
using Minio
using MarSwitching
using Serialization


struct MarkovModel{I} <: AbstractModel
    model::MSM
end

function MarkovModel(I::Instrument, server::MinioConfig, bucket::String) 
    stream = s3_get(server, bucket, symbol(I) * "/markov_switching.jld2")
    model = deserialize(IOBuffer(stream))
    MarkovModel{I}(model)
end