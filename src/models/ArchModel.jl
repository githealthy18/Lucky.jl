export ArchModel, ArchPrediction

using Lucky.Models
using Lucky.Instruments
import Lucky.Units as Units
using Rocket
using Minio
using ARCHModels
using Serialization


struct ArchModel{I,A} <: AbstractModel
    model::UnivariateARCHModel
    next::A
end

function ArchModel(I::Instrument, server::MinioConfig, bucket::String, next::A) where {A}
    stream = s3_get(server, bucket, Units.symbol(I) * "/archmodel.jld2")
    model = deserialize(IOBuffer(stream))
    ArchModel{I,A}(model, next)
end

function ArchModel(I::Type{<:Instrument}, server::MinioConfig, bucket::String, next::A) where {A}
    stream = s3_get(server, bucket, Units.symbol(I) * "/archmodel.jld2")
    model = deserialize(IOBuffer(stream))
    ArchModel{I,A}(model, next)
end

struct ArchPrediction{I}
    vars::Vector{Float64}
    volatilities::Vector{Float64}
    pred_vars::Vector{Union{Missing, Float64}}
    pred_vols::Vector{Union{Missing, Float64}}
    pred_variances::Vector{Union{Missing, Float64}}
end

function Rocket.on_next!(model::ArchModel{I}, returns::Vector{Float64}) where {I}
    l = length(returns)
    pred_variances = Vector{Union{Missing, Float64}}(undef, l)
    pred_vars = Vector{Union{Missing, Float64}}(undef, l)
    pred_vols = Vector{Union{Missing, Float64}}(undef, l)
    for i in 1:l-1000
        pred_model = ARCHModels.UnivariateARCHModel(model.model.spec, returns[1:1000+i];fitted=true)
        pred_variances[1000+i] = ARCHModels.predict.(pred_model, :variance)
        pred_vars[1000+i] = ARCHModels.predict.(pred_model, :VaR)
        pred_vols[1000+i] = ARCHModels.predict.(pred_model, :volatility)
    end
    pred_modeler = UnivariateARCHModel(model.model.spec, returns; fitted=true)
    vars = VaRs(pred_modeler, 0.05)
    volatilities_ = ARCHModels.volatilities(pred_modeler)
    
    next!(model.next, ArchPrediction{I}(vars, volatilities_, pred_vars, pred_vols, pred_variances))
end