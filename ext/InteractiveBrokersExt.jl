module InteractiveBrokers

using Jib
import Lucky: QuoteType, AbstractQuote, Quote
import Lucky: IB, IBAccount

abstract type AbstractMsg end

abstract type IBBaseMsg <: AbstractMsg end

struct TickPriceMsg <: IBBaseMsg
    tickerId::Int
    field::String
    price::Union{Float64,Nothing}
    size::Union{Float64,Nothing}
    attrib::Jib.TickAttrib
end

struct BidQuote <: AbstractQuote
    tickerId::Int
    price::Float64
end

struct AskQuote <: AbstractQuote
    tickerId::Int
    price::Float64
end

struct LastQuote <: AbstractQuote
    tickerId::Int
    price::Float64
end

struct OpenQuote <: AbstractQuote
    tickerId::Int
    price::Float64
end

struct HighQuote <: AbstractQuote
    tickerId::Int
    price::Float64
end

struct LowQuote <: AbstractQuote
    tickerId::Int
    price::Float64
end

# Rocket Subjects

ibPriceQuotes = Subject(TickPriceMsg)

bidQuotes = Subject(BidQuote)
askQuotes = Subject(AskQuote)
lastQuotes = Subject(LastQuote)
openQuotes = Subject(OpenQuote)
highQuotes = Subject(HighQuote)
lowQuotes = Subject(LowQuote)

function Rocket.on_subscribe!(subject::Subject, actor::IBQuoteAggregator)
    actor.subscriptions[eltype(subject)] = subscribe!(subject, actor)
end


mutable struct IBPriceActor <: Actor{TickPriceMsg} end

Rocket.on_next!(actor::IBPriceActor, msg::TickPriceMsg) = begin
    if msg.field == "BID"
        next!(bidQuotes, BidQuote(msg.tickerId, msg.price))
    elseif msg.field == "ASK"
        next!(askQuotes, AskQuote(msg.tickerId, msg.price))
    elseif msg.field == "LAST"
        next!(lastQuotes, LastQuote(msg.tickerId, msg.price))
    elseif msg.field == "OPEN"
        next!(openQuotes, OpenQuote(msg.tickerId, msg.price))
    elseif msg.field == "HIGH"
        next!(highQuotes, HighQuote(msg.tickerId, msg.price))
    elseif msg.field == "LOW"
        next!(lowQuotes, LowQuote(msg.tickerId, msg.price))
    end
end

subscribe!(ibPriceQuotes, IBPriceActor())

struct TickSizeMsg <: IBBaseMsg
    tickerId::Int
    field::String
    size::Union{Float64,Nothing}
end

struct BidSize <: AbstractQuote
    tickerId::Int
    size::Float64
end

struct AskSize <: AbstractQuote
    tickerId::Int
    size::Float64
end

struct LastSize <: AbstractQuote
    tickerId::Int
    size::Float64
end

struct VolumeQuote <: AbstractQuote
    tickerId::Int
    volume::Float64
end

# Rocket Subjects

bidSizes = Subject(BidSize)
askSizes = Subject(AskSize)
lastSizes = Subject(LastSize)
volumeQuotes = Subject(VolumeQuote)

mutable struct IBSizeActor <: Actor{TickSizeMsg} end

Rocket.on_next!(actor::IBSizeActor, msg::TickSizeMsg) = begin
    if msg.field == "BID_SIZE"
        next!(bidSizes, BidSize(msg.tickerId, msg.size))
    elseif msg.field == "ASK_SIZE"
        next!(askSizes, AskSize(msg.tickerId, msg.size))
    elseif msg.field == "LAST_SIZE"
        next!(lastSizes, LastSize(msg.tickerId, msg.size))
    elseif msg.field == "VOLUME"
        next!(volumeQuotes, VolumeQuote(msg.tickerId, msg.size))
    end
end

ibSizeQuotes = Subject(TickSizeMsg)

subscribe!(ibSizeQuotes, IBSizeActor())

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

historicalData = Subject(HistoricalDataMsg)
  
struct SecDefOptParamsMsg <: IBBaseMsg
    reqId::Int
    exchange::String
    underlyingConId::Int
    tradingClass::String
    multiplier::String
    expirations::Vector{String}
    strikes::Vector{Float64}
end

secDefOptParams = Subject(SecDefOptParamsMsg)
  
struct ErrorMsg <: IBBaseMsg
    id::Union{Int,Nothing}
    errorCode::Union{Int,Nothing}
    errorString::String
    advancedOrderRejectJson::String
end
  
errors = Subject(ErrorMsg)
  
struct AccountSummaryMsg <: IBBaseMsg
    id::Int
    account::String
    tag::String
    value::String
    currency::String
end

accountSummary = Subject(AccountSummaryMsg)

mutable struct IBQuoteAggregator{I, R, A} <: Actor{AbstractQuote}
    tickerId::Int
    instrument::I
    subscriptions::Dict{Type{<:AbstractQuote}, Rocket.SubjectSubscription}
    bid::BidQuote
    ask::AskQuote
    last::LastQuote
    open::OpenQuote
    high::HighQuote
    low::LowQuote
    volume::VolumeQuote
    requestManager::R
    next::A
end

IBQuoteAggregator(tickerId::Int, instrument::I, requestManager::R, next::A) where {I, R, A} = IBQuoteAggregator(
    tickerId, 
    instrument,
    Dict{Type{<:AbstractQuote}, Rocket.SubjectSubscription}(), 
    BidQuote(tickerId, 0.0), 
    AskQuote(tickerId, 0.0), 
    LastQuote(tickerId, 0.0), 
    OpenQuote(tickerId, 0.0), 
    HighQuote(tickerId, 0.0),
    LowQuote(tickerId, 0.0), 
    VolumeQuote(tickerId, 0.0),
    requestManager,
    next
)

struct CompleteMsg{B} <: AbstractMsg 
    body::B
end

completedRequests = Subject(CompleteMsg)

Rocket.on_next!(actor::IBQuoteAggregator, quotes::BidQuote) = begin
    if quotes.tickerId == actor.tickerId
        actor.bid = quotes
        next!(actor, CompleteMsg{quotes}())
    end
end

Rocket.on_next!(actor::IBQuoteAggregator, quotes::AskQuote) = begin
    if quotes.tickerId == actor.tickerId
        actor.ask = quotes
        next!(actor, CompleteMsg{quotes}())
    end
end

Rocket.on_next!(actor::IBQuoteAggregator, quotes::LastQuote) = begin
    if quotes.tickerId == actor.tickerId
        actor.last = quotes
        next!(actor, CompleteMsg{quotes}())
    end
end

Rocket.on_next!(actor::IBQuoteAggregator, quotes::OpenQuote) = begin
    if quotes.tickerId == actor.tickerId
        actor.open = quotes
        next!(actor, CompleteMsg{quotes}())
    end
end

Rocket.on_next!(actor::IBQuoteAggregator, quotes::HighQuote) = begin
    if quotes.tickerId == actor.tickerId
        actor.high = quotes
        next!(actor, CompleteMsg{quotes}())
    end
end

Rocket.on_next!(actor::IBQuoteAggregator, quotes::LowQuote) = begin
    if quotes.tickerId == actor.tickerId
        actor.low = quotes
        next!(actor, CompleteMsg{quotes}())
    end
end

Rocket.on_next!(actor::IBQuoteAggregator, quotes::VolumeQuote) = begin
    if quotes.tickerId == actor.tickerId
        actor.volume = quotes
        next!(actor, CompleteMsg{quotes}())
    end
end

Rocket.on_next!(actor::IBQuoteAggregator, msg::CompleteMsg) = begin
    if haskey(actor.subscriptions, typeof(msg.body)) 
        unsubscribe!(actor.subscriptions[typeof(msg.body)])
        delete!(actor.subscriptions, typeof(msg.body))
        if isempty(actor.subscriptions)
            complete!(actor)
        end
    end
end

Rocket.on_complete!(actor::IBQuoteAggregator) = begin
    next!(actor.next, Bar{Dates.now()}(
        Ohlc(actor.open.price, actor.high.price, actor.low.price, actor.last.price, Dates.now()), 
        Volume(Dates.now(), actor.volume.volume))
    )
    next!(actor.requestManager, CompleteMsg{actor}())

end

struct RequestManagerChildActorFactory{I, A} <: Rocket.AbstractActorFactory
    main :: A
end

__make_request_manager_child_actor_factory(index::Int, main::A) where A = RequestManagerChildActorFactory{index, A}(main)

Rocket.create_actor(::Type{L}, factory::RequestManagerChildActorFactory{I, A}) where { L, I, A } = IBRequestActor{L, I, A}(factory.main)


struct IBRequestManager{I, R, C} <: Actor{Any}
    reqId::Int
    completion_status::BitArray{1}
    timeout::Int
    requests::R
    cancels::C
end

IBRequestManager

struct IBRequestActor{L, I, A} <: Actor{I}
    main::A
end

struct RegisteredSymbols{A} <: Actor{Any}
    symbols::Set{Symbol}
    date::Date
    next::A
end

end