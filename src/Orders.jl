export AbstractOrder
export LimitOrder, MarketOrder, AlgorithmicMarketOrder, AlgorithmicLimitOrder
export OrderType

abstract type AbstractOrder end
abstract type AbstractMarketOrder <: AbstractOrder end

OrderType(::O) where {O<:AbstractOrder} = O

"""
    MarketOrder

Standard Data Type carrying inforamtion for a market order on an instrument for a given size.
"""
@auto_hash_equals fields=(id,instrument,action,timestamp) mutable struct MarketOrder{I,S,A,D} <: AbstractMarketOrder
    id::Union{Missing, Int}
    instrument::I
    action::A
    size::S
    timestamp::D
end

"""
    LimitOrder

Standard Data Type carrying inforamtion for a limit order on an instrument for a given size.
"""
@auto_hash_equals fields=(id,instrument,action,timestamp) mutable struct LimitOrder{I,S,A,D} <: AbstractOrder
    id::Union{Missing, Int}
    instrument::I
    action::A
    size::S
    limit::Float64
    timestamp::D
end

"""
    AlgorithmicMarketOrder

Standard Data Type carrying inforamtion for an algorithmic order on an instrument for a given size.
"""
@auto_hash_equals fields=(id,instrument,action,timestamp) mutable struct AlgorithmicMarketOrder{I,S,A,D} <: AbstractOrder
    id::Union{Missing, Int}
    instrument::I
    action::A
    size::S
    algorithm::String
    timestamp::D
end

"""
    AlgorithmicLimitOrder
Standard Data Type carrying inforamtion for an algorithmic limit order on an instrument for a given size.
"""
@auto_hash_equals fields=(id,instrument,action,timestamp) mutable struct AlgorithmicLimitOrder{I,S,A,D} <: AbstractOrder
    id::Union{Missing, Int}
    instrument::I
    action::A
    size::S
    limit::Float64
    algorithm::String
    timestamp::D
end

currency(::MarketOrder{I,S}) where {I<:Instrument,S<:Number} = currency(I)
currency(::LimitOrder{I,S}) where {I<:Instrument,S<:Number} = currency(I)
currency(::Type{<:MarketOrder{I,S}}) where {I<:Instrument,S<:Number} = currency(I)
currency(::Type{<:LimitOrder{I,S}}) where {I<:Instrument,S<:Number} = currency(I)