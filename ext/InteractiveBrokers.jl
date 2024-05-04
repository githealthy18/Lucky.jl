module InteractiveBrokers

using Jib
import Lucky: QuoteType, AbstractQuote, Quote

abstract type AbstractMsg end

abstract type IBBaseMsg <: AbstractMsg end

struct TickPriceMsg <: IBBaseMsg
    tickerId::Int
    field::String
    price::Union{Float64,Nothing}
    size::Union{Float64,Nothing}
    attrib::Jib.TickAttrib
end


struct TickSizeMsg <: IBBaseMsg
    tickerId::Int
    field::String
    size::Union{Float64,Nothing}
end

struct BidSize{I} <: AbstractQuote
    size::Float64
end

struct AskSize{I} <: AbstractQuote
    size::Float64
end

struct LastSize{I} <: AbstractQuote
    size::Float64
end

struct VolumeQuote{I} <: AbstractQuote
    volume::Float64
end

function Quote(msg::TickSizeMsg)
    if msg.field == "BID_SIZE"
        BidSize{msg.tickerId}(msg.size)
    elseif msg.field == "ASK_SIZE"
        AskSize{msg.tickerId}(msg.size)
    elseif msg.field == "LAST_SIZE"
        LastSize{msg.tickerId}(msg.size)
    elseif msg.field == "VOLUME"
        VolumeQuote{msg.tickerId}(msg.size)
    else
        error("Unknown field: $(msg.field)")
    end
end

struct TickOptionMsg <: IBBaseMsg
    tickerId::Int
    tickType::String
    tickAttrib::Int
    impliedVol::Union{Float64,Nothing}
    delta::Union{Float64,Nothing}
    optPrice::Union{Float64,Nothing}
    pvDividend::Union{Float64,Nothing}
    gamma::Union{Float64,Nothing}
    vega::Union{Float64,Nothing}
    theta::Union{Float64,Nothing}
    undPrice::Union{Float64,Nothing}
end

struct HistoricalDataMsg <: IBBaseMsg
    tickerId::Int
    dataframe::DataFrame
end
  
struct SecDefOptParamsMsg <: IBBaseMsg
    reqId::Int
    exchange::String
    underlyingConId::Int
    tradingClass::String
    multiplier::String
    expirations::Vector{String}
    strikes::Vector{Float64}
end
  
struct ErrorMsg <: IBBaseMsg
    id::Union{Int,Nothing}
    errorCode::Union{Int,Nothing}
    errorString::String
    advancedOrderRejectJson::String
end
  
  
struct AccountSummaryMsg <: IBBaseMsg
    id::I
    account::A
    tag::T 
    value::V
    currency::C
end
end