export AbstractFill
export Fill
export FillType

"""
    AbstractFill

Abstract Type for Fills.
"""
abstract type AbstractFill end

FillType(::F) where {F<:AbstractFill} = F

"""
    Fill

Standard fill.
"""
struct Fill{O,S,D} <: AbstractFill
    id::Int
    order::O
    price::Float64
    size::S
    fee::Float64
    timestamp::D
end

currency(::Fill{O,S,D}) where {O<:AbstractOrder,S,D} = currency(O)

import Base: -
-(order::O, fill::F) where {O<:MarketOrder,F<:Fill{O}} = MarketOrder(order.id, order.instrument, order.action, order.side, order.size - fill.size, order.timestamp)
-(order::O, fill::F) where {O<:LimitOrder,F<:Fill{O}} = LimitOrder(order.id, order.instrument, order.action, order.side, order.size - fill.size, order.limit, order.timestamp)
-(order::O, fill::F) where {O<:AlgorithmicMarketOrder,F<:Fill{O}} = AlgorithmicMarketOrder(order.id, order.instrument, order.action, order.side, order.size - fill.size, order.algorithm, order.algorithmParams, order.timestamp)
-(order::O, fill::F) where {O<:AlgorithmicLimitOrder,F<:Fill{O}} = AlgorithmicLimitOrder(order.id, order.instrument, order.action, order.side, order.size - fill.size, order.limit, order.algorithm, order.algorithmParams, order.timestamp)

+(x::F, y::F) where {F<:Fill} = Fill(x.id, x.order, mean((x.price, y.price)), x.size + y.size, x.fee + y.fee, x.timestamp)