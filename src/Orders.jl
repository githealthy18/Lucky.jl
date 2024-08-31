export AbstractOrder
export LimitOrder, MarketOrder, AlgorithmicMarketOrder, AlgorithmicLimitOrder
export OrderType

abstract type AbstractOrder end

OrderType(::O) where {O<:AbstractOrder} = O

"""
    MarketOrder

Standard Data Type carrying inforamtion for a market order on an instrument for a given size.
"""
struct MarketOrder{I,S,A} <: AbstractOrder
    instrument::I
    action::ORDER_SIDE
    size::S
end

"""
    LimitOrder

Standard Data Type carrying inforamtion for a limit order on an instrument for a given size.
"""
struct LimitOrder{I,S,A} <: AbstractOrder
    instrument::I
    action::ORDER_SIDE
    size::S
    limit::Float64
end

"""
    AlgorithmicMarketOrder

Standard Data Type carrying inforamtion for an algorithmic order on an instrument for a given size.
"""
struct AlgorithmicMarketOrder{I,S,A} <: AbstractOrder
    instrument::I
    action::ORDER_SIDE
    size::S
    algorithm::A
end

"""
    AlgorithmicLimitOrder
Standard Data Type carrying inforamtion for an algorithmic limit order on an instrument for a given size.
"""
struct AlgorithmicLimitOrder{I,S,A} <: AbstractOrder
    instrument::I
    action::ORDER_SIDE
    size::S
    limit::Float64
    algorithm::A
end

currency(::MarketOrder{I,S}) where {I<:Instrument,S<:Number} = currency(I)
currency(::LimitOrder{I,S}) where {I<:Instrument,S<:Number} = currency(I)
currency(::Type{<:MarketOrder{I,S}}) where {I<:Instrument,S<:Number} = currency(I)
currency(::Type{<:LimitOrder{I,S}}) where {I<:Instrument,S<:Number} = currency(I)