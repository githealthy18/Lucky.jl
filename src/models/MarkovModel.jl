export MarkovModel, MarkovPrediction

using Lucky.Models
using Lucky.Instruments
import Lucky.Units as Units
using Rocket
using Minio
using MarSwitching
using Serialization


struct MarkovModel{I<:Instrument} <: AbstractModel
    model::MSM
    next::Actor{Any}
end

function MarkovModel(I::Instrument, server::MinioConfig, bucket::String, next::Actor{Any}) 
    stream = s3_get(server, bucket, Units.symbol(I) * "/markov_switching.jld2")
    model = deserialize(IOBuffer(stream))
    MarkovModel{I}(model)
end

struct MarkovPrediction{I<:Instrument}
    beta::Vector{Float64}
    regime1::Vector{Float64}
    regime2::Vector{Float64}
    regime3::Vector{Float64}
end

function Rocket.on_next!(model::MarkovModel{I, A}, returns::Vector{Float64}) where {I, A}
    pred_values, pred_probabilities = MarSwitching.predict(model.model; y=returns)
    pred_beta = Vector{Union{Missing, Float32, Float64}}(undef, length(returns))
    pred_prob1 = Vector{Union{Missing, Float32, Float64}}(undef, length(returns))
    pred_prob2 = Vector{Union{Missing, Float32, Float64}}(undef, length(returns))
    pred_prob3 = Vector{Union{Missing, Float32, Float64}}(undef, length(returns))
    pred_beta[2:end] = pred_values
    pred_prob1[2:end] = pred_probabilities[:,1]
    pred_prob2[2:end] = pred_probabilities[:,2]
    pred_prob3[2:end] = pred_probabilities[:,3]
    next!(model.next, MarkovPrediction{I}(pred_values, pred_prob1, pred_prob2, pred_prob3))
end