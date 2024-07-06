export MarkovModel, MarkovPrediction

using Lucky.Models
using Lucky.Instruments
import Lucky.Units as Units
using Rocket
using Minio
using MarSwitching
using Serialization


struct MarkovModel{I<:Instrument,A} <: AbstractModel
    model::MSM
    next::A
end

function MarkovModel(I::Instrument, server::MinioConfig, bucket::String, next::A) where {A}
    stream = s3_get(server, bucket, Units.symbol(I) * "/markov_switching.jld2")
    model = deserialize(IOBuffer(stream))
    MarkovModel{I,A}(model, next)
end

function MarkovModel(I::Type{<:Instrument}, server::MinioConfig, bucket::String, next::A) where {A}
    stream = s3_get(server, bucket, Units.symbol(I) * "/markov_switching.jld2")
    model = deserialize(IOBuffer(stream))
    MarkovModel{I,A}(model, next)
end

struct MarkovPrediction{I<:Instrument}
    beta::Vector{Float64}
    regime1::Vector{Float64}
    regime2::Vector{Float64}
    regime3::Vector{Float64}
end

function Rocket.on_next!(model::MarkovModel{I,A}, returns::Vector{Float64}) where {I,A}
    println("MARKOVING STARTED")
    pred_values, pred_probabilities = MarSwitching.predict(model.model; y=returns)
    pred_beta = Vector{Union{Missing, Float64}}(undef, length(returns))
    pred_prob1 = Vector{Union{Missing, Float64}}(undef, length(returns))
    pred_prob2 = Vector{Union{Missing, Float64}}(undef, length(returns))
    pred_prob3 = Vector{Union{Missing, Float64}}(undef, length(returns))
    pred_beta[2:end] = pred_values
    pred_prob1[2:end] = pred_probabilities[:,1]
    pred_prob2[2:end] = pred_probabilities[:,2]
    pred_prob3[2:end] = pred_probabilities[:,3]
    println("MARKOVING FINISHED")
    result = MarkovPrediction{I}(pred_beta, pred_prob1, pred_prob2, pred_prob3)
    next!(model.next, result)
end