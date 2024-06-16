export MarkovModel

import Base: eltype

using Lucky.Models
using Rocket
using Minio
using MarSwitching
using Serialization


mutable struct MarkovModel{S} <: AbstractModel
    model::Union{Nothing, <:MSM}
end

Base.eltype(::Type{MarkovModel{S}}) where {S} = S

function Rocket.on_next!(model::MarkovModel, msg::ReadModelMsg)
    stream = s3_get(msg.server, msg.bucket, String(eltype(model)) * "/markov_switching.jld2")
    model.model = deserialize(IOBuffer(stream))
end
