using Dates
using Lucky
using Rocket
using DataFrames

mutable struct PreModel{A} <: AbstractStrategy
    data::DataFrame
    next::A
end

mutable struct GoldenCross{A} <: AbstractStrategy
    cashPosition::Union{Nothing,CashPositionType}
    aaplPosition::Union{Nothing,StockPositionType}
    prevSlowSMA::SlowIndicatorType
    prevFastSMA::FastIndicatorType
    slowSMA::SlowIndicatorType
    fastSMA::FastIndicatorType
    next::A
end