export MarkovModel

using Lucky.Models
using Rocket
using Minio
using MarSwitching
using Serialization


struct MarkovModel{I} <: AbstractModel
    model::MSM

    MarkovModel{I}(server::S, bucket::String) where {I, S} = begin
        stream = s3_get(server, bucket, symbol(I) * "/markov_switching.jld2")
        model = deserialize(IOBuffer(stream))
        new{I}(model)
    end
end