module InteractiveBrokers

using Jib

abstract type AbstractMsg end

abstract type IBBaseMsg <: AbstractMsg end

struct TickPriceMsg{A} <: IBBaseMsg
    tickerId::Int
    field::String
    price::Union{Float64,Nothing}
    size::Union{Float64,Nothing}
    attrib::Jib.TickAttrib
end

struct TickSizeMsg{A} <: IBBaseMsg
    tickerId::Int
    field::String
    size::Union{Float64,Nothing}
  end

end