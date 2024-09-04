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
-(order::O, fill::F) where {O<:MarketOrder,F<:Fill{O}} = MarketOrder(order.id, order.instrument, order.action, order.size - fill.size, order.timestamp)