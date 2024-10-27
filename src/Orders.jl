export AbstractOrder
export LimitOrder, MarketOrder, AlgorithmicMarketOrder, AlgorithmicLimitOrder
export Order, OrderType

abstract type AbstractOrder end
abstract type AbstractMarketOrder <: AbstractOrder end

OrderType(::O) where {O<:AbstractOrder} = O

"""
    MarketOrder

Standard Data Type carrying inforamtion for a market order on an instrument for a given size.
"""
@auto_hash_equals fields=(id,instrument,action,side,timestamp) mutable struct MarketOrder{I,S,V,D} <: AbstractMarketOrder
    id::Union{Missing, Int}
    instrument::I
    action::ACTION
    side::S
    size::V
    timestamp::D
end

MarketOrder(instrument::Instrument, action::A, side::S, size::V, stamp::D) where {A,S,V,D} = MarketOrder(missing, instrument, action, side, size, stamp)

"""
    LimitOrder

Standard Data Type carrying inforamtion for a limit order on an instrument for a given size.
"""
@auto_hash_equals fields=(id,instrument,action,side,timestamp) mutable struct LimitOrder{I,S,V,D} <: AbstractOrder
    id::Union{Missing, Int}
    instrument::I
    action::ACTION
    side::S
    size::V
    limit::Float64
    timestamp::D
end

LimitOrder(instrument::Instrument, action::A, side::S, size::V, limit::Float64, stamp::D) where {A,S,V,D} = LimitOrder(missing, instrument, action, side, size, limit, stamp)

"""
    AlgorithmicMarketOrder

Standard Data Type carrying inforamtion for an algorithmic order on an instrument for a given size.
"""
@auto_hash_equals fields=(id,instrument,action,side,timestamp) mutable struct AlgorithmicMarketOrder{I,S,V,D} <: AbstractOrder
    id::Union{Missing, Int}
    instrument::I
    action::ACTION
    side::S
    size::V
    algorithm::String
    timestamp::D
end

AlgorithmicMarketOrder(instrument::Instrument, action::A, side::S, size::V, algorithm::String, stamp::D) where {A,S,V,D} = AlgorithmicMarketOrder(missing, instrument, action, side, size, algorithm, stamp)

"""
    AlgorithmicLimitOrder
Standard Data Type carrying inforamtion for an algorithmic limit order on an instrument for a given size.
"""
@auto_hash_equals fields=(id,instrument,action,side,timestamp) mutable struct AlgorithmicLimitOrder{I,S,V,D} <: AbstractOrder
    id::Union{Missing, Int}
    instrument::I
    action::ACTION
    side::S
    size::V
    limit::Float64
    algorithm::String
    timestamp::D
end

AlgorithmicLimitOrder(instrument::Instrument, action::A, side::S, size::V, limit::Float64, algorithm::String, stamp::D) where {A,S,V,D} = AlgorithmicLimitOrder(missing, instrument, action, side, size, limit, algorithm, stamp)

currency(m::MarketOrder{I,S,V,D}) where {I<:Instrument,S<:ORDER_SIDE,V<:Number,D<:Dates.AbstractTime} = currency(m.instrument)
currency(::Type{MarketOrder{I,S,V,D}}) where {I<:Instrument,S<:ORDER_SIDE,V<:Number,D<:Dates.AbstractTime} = currency(I)
currency(l::LimitOrder{I,S,V,D}) where {I<:Instrument,S<:ORDER_SIDE,V<:Number,D<:Dates.AbstractTime} = currency(l.instrument)
currency(::Type{LimitOrder{I,S,V,D}}) where {I<:Instrument,S<:ORDER_SIDE,V<:Number,D<:Dates.AbstractTime} = currency(I)
currency(a::AlgorithmicMarketOrder{I,S,V,D}) where {I<:Instrument,S<:ORDER_SIDE,V<:Number,D<:Dates.AbstractTime} = currency(a.instrument)
currency(::Type{AlgorithmicMarketOrder{I,S,V,D}}) where {I<:Instrument,S<:ORDER_SIDE,V<:Number,D<:Dates.AbstractTime} = currency(I)
currency(a::AlgorithmicLimitOrder{I,S,V,D}) where {I<:Instrument,S<:ORDER_SIDE,V<:Number,D<:Dates.AbstractTime} = currency(a.instrument)
currency(::Type{AlgorithmicLimitOrder{I,S,V,D}}) where {I<:Instrument,S<:ORDER_SIDE,V<:Number,D<:Dates.AbstractTime} = currency(I)

Order(instrument::Instrument, action::A, side::S, size::V, stamp::D) where {A,S,V,D} = MarketOrder(instrument, action, side, size, stamp)
Order(instrument::Instrument, action::A, side::S, size::V, limit::Float64, stamp::D) where {A,S,V,D} = LimitOrder(instrument, action, side, size, limit, stamp)
Order(instrument::Instrument, action::A, side::S, size::V, algorithm::String, stamp::D) where {A,S,V,D} = AlgorithmicMarketOrder(instrument, action, side, size, algorithm, stamp)
Order(instrument::Instrument, action::A, side::S, size::V, limit::Float64, algorithm::String, stamp::D) where {A,S,V,D} = AlgorithmicLimitOrder(instrument, action, side, size, limit, algorithm, stamp)
