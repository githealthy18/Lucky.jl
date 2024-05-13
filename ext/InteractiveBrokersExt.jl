module InteractiveBrokersExt

using Lucky

using InteractiveBrokers
using Rocket
using DataFrames
using Dates

import Lucky: QuoteType, AbstractQuote, Quote, AbstractManager

orderId = 1

nextValidId = nothing

available_ids = Vector{Int}()

function validId()
  function increment()
    global orderId += 1
    return orderId
  end
  return increment
end


struct InteractiveBrokersObservable <: Subscribable{Nothing}
    events::Vector{Symbol}
    targets::Vector{Rocket.Subject}
    applys::Vector{Function}   

    host::Union{Nothing, Any} # IPAddr (not typed to avoid having to add Sockets to Project.toml 1.10)
    port::Int

    clientId::Int

    connectOptions::String
    optionalCapabilities::String

    function InteractiveBrokersObservable(host=nothing, port::Int=7497, clientId::Int=1, connectOptions::String="", optionalCapabilities::String="")
        return new(Vector{Symbol}(), Vector{Rocket.Subject}(), Vector{Function}(), host, port, clientId, connectOptions, optionalCapabilities)
    end
end

struct InteractiveBrokersObservableSubscription <: Teardown
    connection::InteractiveBrokers.Connection
end

function Rocket.on_subscribe!(obs::InteractiveBrokersObservable, actor::AbstractManager)
    ib = InteractiveBrokers.connect(;host=obs.host, port=obs.port, clientId=obs.clientId, obs.connectOptions, obs.optionalCapabilities)
    InteractiveBrokers.start_reader(ib, wrapper(obs))
    return InteractiveBrokersObservableSubscription(ib)
end

Rocket.as_teardown(::Type{<:InteractiveBrokersObservableSubscription}) = UnsubscribableTeardownLogic()

function Rocket.on_unsubscribe!(subscription::InteractiveBrokersObservableSubscription)
    InteractiveBrokers.disconnect(subscription.connection)
end

function Lucky.service(::Val{:interactivebrokers}, host=nothing, port::Int=7497, clientId::Int=1, connectOptions::String="", optionalCapabilities::String="")
    obs = InteractiveBrokersObservable(host, port, clientId, connectOptions, optionalCapabilities)
    refCounts[obs] = obs |> share()
    return obs
end

abstract type AbstractMsg end

abstract type IBBaseMsg <: AbstractMsg end

struct TickPriceMsg <: IBBaseMsg
    tickerId::Int
    field::String
    price::Union{Float64,Nothing}
    size::Union{Float64,Nothing}
    attrib::InteractiveBrokers.TickAttrib
end

struct TickSizeMsg <: IBBaseMsg
    tickerId::Int
    field::String
    size::Union{Float64,Nothing}
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
    id::Int
    account::String
    tag::String
    value::String
    currency::String
end

struct OrderIdMsg <: IBBaseMsg
    id::Int
end


defaultMapper = Dict{Symbol,Pair{Function,Type}}()
defaultMapper[:tickPrice] = Pair((x...) -> TickPriceMsg(x...), TickPriceMsg)
defaultMapper[:tickSize] = Pair((x...) -> TickSizeMsg(x...), TickSizeMsg)
defaultMapper[:tickOptionComputation] = Pair((x...) -> TickOptionMsg(x...), TickOptionMsg)
defaultMapper[:historicalData] = Pair((x...) -> HistoricalDataMsg(x...), HistoricalDataMsg)
defaultMapper[:securityDefinitionOptionalParameter,] = Pair((x...) -> SecDefOptParamsMsg(x...), SecDefOptParamsMsg)
defaultMapper[:error] = Pair((x...) -> ErrorMsg(x...), ErrorMsg)
defaultMapper[:nextValidId] = Pair((x...) -> OrderIdMsg(x...), OrderIdMsg)
defaultMapper[:accountSummary] = Pair((x...) -> AccountSummaryMsg(x...), AccountSummaryMsg)
refCounts = Dict{InteractiveBrokersObservable, Rocket.Subscribable}()

function Lucky.feed(client::InteractiveBrokersObservable, event::Symbol, applyFunction::Function, outputType::Type)
    subject = Subject(outputType)

    push!(client.events, event)
    push!(client.targets, subject)
    push!(client.applys, applyFunction)

    return subject
end

function Lucky.feed(client::InteractiveBrokersObservable, event::Symbol)
    haskey(defaultMapper, event) && return Lucky.feed(client, event, defaultMapper[event][1], defaultMapper[event][2])
    return faulted("No default mapping function for $(event). Provide one or contribute a default implementation.")
end

function wrapper(client::InteractiveBrokersObservable)
    wrap = InteractiveBrokers.Wrapper()
    for (idx, _) in enumerate(client.events)
        setproperty!(wrap, client.events[idx], (x...) -> next!(client.targets[idx], client.applys[idx](x...)))
    end
    return wrap
end

# # import Lucky: IB, IBAccount


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

mutable struct IBQuoteAggregator{I, R, A} <: Actor{AbstractQuote}
    tickerId::Int
    instrument::I
    subscriptions::Dict{Type{<:AbstractQuote}, Rocket.SubjectSubscription}
    bundle::Dict{Type{<:AbstractQuote}, AbstractQuote}
    requestManager::R
    next::A
end

IBQuoteAggregator(tickerId::Int, instrument::I, requestManager::R, next::A) where {I, R, A} = IBQuoteAggregator(
    tickerId, 
    instrument,
    Dict{Type{<:AbstractQuote}, Rocket.SubjectSubscription}(),
    Dict{Type{<:AbstractQuote}, AbstractQuote}(),
    requestManager,
    next
)

struct CompleteMsg{B} <: AbstractMsg 
    body::B
end

completedRequests = Subject(CompleteMsg)

Rocket.on_next!(actor::IBQuoteAggregator, quotes::AbstractQuote) = begin
    if quotes.tickerId == actor.tickerId
        actor.bundle[typeof(quotes)] = quotes
        next!(actor, CompleteMsg{quotes}())
    end
end

# Rocket.on_next!(actor::IBQuoteAggregator, quotes::AskQuote) = begin
#     if quotes.tickerId == actor.tickerId
#         actor.ask = quotes
#         next!(actor, CompleteMsg{quotes}())
#     end
# end

# Rocket.on_next!(actor::IBQuoteAggregator, quotes::LastQuote) = begin
#     if quotes.tickerId == actor.tickerId
#         actor.last = quotes
#         next!(actor, CompleteMsg{quotes}())
#     end
# end

# Rocket.on_next!(actor::IBQuoteAggregator, quotes::OpenQuote) = begin
#     if quotes.tickerId == actor.tickerId
#         actor.open = quotes
#         next!(actor, CompleteMsg{quotes}())
#     end
# end

# Rocket.on_next!(actor::IBQuoteAggregator, quotes::HighQuote) = begin
#     if quotes.tickerId == actor.tickerId
#         actor.high = quotes
#         next!(actor, CompleteMsg{quotes}())
#     end
# end

# Rocket.on_next!(actor::IBQuoteAggregator, quotes::LowQuote) = begin
#     if quotes.tickerId == actor.tickerId
#         actor.low = quotes
#         next!(actor, CompleteMsg{quotes}())
#     end
# end

# Rocket.on_next!(actor::IBQuoteAggregator, quotes::VolumeQuote) = begin
#     if quotes.tickerId == actor.tickerId
#         actor.volume = quotes
#         next!(actor, CompleteMsg{quotes}())
#     end
# end

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


struct IBRequestManager{R, C} <: Actor{Any}
    conn::Jib.Connection
    reqId::Int
    completion_status::BitArray{1}
    timeout::Int
    requests::Vector{R}
    cancels::Vector{C}
end

struct IBRequestActor{L, I, A} <: Actor{I}
    main::A
end

struct RegisteredSymbols{A} <: Actor{Any}
    symbols::Set{Symbol}
    date::Date
    next::A
end

end