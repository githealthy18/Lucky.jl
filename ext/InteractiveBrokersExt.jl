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

function Rocket.on_subscribe!(obs::InteractiveBrokersObservable, actor)
    ib = InteractiveBrokers.connect(;port=obs.port, clientId=obs.clientId, obs.connectOptions, obs.optionalCapabilities)
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

mutable struct IBPriceActor <: Actor{TickPriceMsg} end

struct TickSizeMsg <: IBBaseMsg
    tickerId::Int
    field::String
    size::Union{Float64,Nothing}
end

mutable struct IBSizeActor <: Actor{TickSizeMsg} end

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

struct RegisterRequest{A} <: IBBaseMsg
    request::Pair{<:Function, <:Tuple}
    cancel::Pair{<:Function, <:Tuple}
    timeout::Int
    actor::A
end

registerRequestSubject = Subject(RegisterRequest)

struct RegisterResponse <: IBBaseMsg
    reqId::Int
    queueId::Int
end

struct BootStrapSystem <: IBBaseMsg end

bootStrapSubject = Subject(BootStrapSystem)

struct IncompleteDataRequest <: IBBaseMsg end

struct CompleteQuoteMsg{B} <: IBBaseMsg
    body::B
end

struct CompleteRequestMsg <: IBBaseMsg
    reqId::Int
    queueId::Int
end

completedRequests = Subject(CompleteRequestMsg)



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

function Lucky.feed(client::InteractiveBrokersObservable, event::Symbol, applyFunction::Function, outputType::Type{<:TickPriceMsg})
    subject = Subject(outputType)

    price_actor = IBPriceActor()
    subscribe!(subject, price_actor)

    push!(client.events, event)
    push!(client.targets, subject)
    push!(client.applys, applyFunction)

    return subject
end

function Lucky.feed(client::InteractiveBrokersObservable, event::Symbol, applyFunction::Function, outputType::Type{<:TickSizeMsg})
    subject = Subject(outputType)

    size_actor = IBSizeActor()
    subscribe!(subject, size_actor)

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

DefaultIBService = Lucky.service(Val(:interactivebrokers))

mutable struct ServiceManager{A} <: AbstractManager
    service::A
    subscription::Union{Nothing, InteractiveBrokersObservableSubscription}
end

struct ConnectionMsg <: IBBaseMsg
    conn::InteractiveBrokers.Connection
end

ConnectionSub = Subject(ConnectionMsg)

function Rocket.on_next!(manager::ServiceManager, msg::BootStrapSystem)
    subscription = subscribe!(manager.service, logger("ServiceManager"))
    manager.subscription = subscription
    next!(ConnectionSub, ConnectionMsg(subscription.connection))
end

AccountSub = Lucky.feed(DefaultIBService, :accountSummary)
ErrorSub = Lucky.feed(DefaultIBService, :error)
NextValidIdSub = Lucky.feed(DefaultIBService, :nextValidId)
TickPriceSub = Lucky.feed(DefaultIBService, :tickPrice)
TickSizeSub = Lucky.feed(DefaultIBService, :tickSize)
TickOptionComputationSub = Lucky.feed(DefaultIBService, :tickOptionComputation)
HistoricalDataSub = Lucky.feed(DefaultIBService, :historicalData)
SecurityDefinitionOptionalParameterSub = Lucky.feed(DefaultIBService, :securityDefinitionOptionalParameter)

DefaultIBServiceManager = ServiceManager(DefaultIBService, nothing)

subscribe!(bootStrapSubject, DefaultIBServiceManager)

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

Rocket.on_next!(actor::IBSizeActor, msg::TickSizeMsg) = begin
    if msg.field == "BID_SIZE"
        next!(bidSizes, BidSize(msg.tickerId, msg.size))
    elseif msg.field == "ASK_SIZE"
        next!(askSizes, AskSize(msg.tickerId, msg.size))
    elseif msg.field == "LAST_SIZE"
        next!(lastSizes, LastSize(msg.tickerId, msg.size))
    elseif msg.field == "VOLUME"
        next!(volumeQuotes, VolumeQuote(msg.tickerId, 100*msg.size))
    end
end

mutable struct IBQuoteAggregator{S, R, A} <: Actor{Union{RegisterResponse, AbstractQuote, <:CompleteQuoteMsg, IncompleteDataRequest}}
    tickerId::Union{Nothing, Int}
    queueId::Union{Nothing, Int}
    subjects::Dict{Rocket.Subject, Union{Nothing, Rocket.SubjectSubscription}}
    bundle::Dict{DataType, Union{Nothing, AbstractQuote}}
    strategy::S
    requestManager::R
    next::A
end

IBQuoteAggregator(subjects::Dict{Rocket.Subject, Union{Nothing, Rocket.SubjectSubscription}}, strategy::S, requestManager::R, next::A) where {S, R, A} = IBQuoteAggregator(
    nothing, 
    nothing,
    subjects,
    Dict{DataType, Union{Nothing,AbstractQuote}}(),
    strategy,
    requestManager,
    next
)

Rocket.on_next!(actor::IBQuoteAggregator, quotes::AbstractQuote) = begin
    if quotes.tickerId == actor.tickerId
        actor.bundle[typeof(quotes)] = quotes
        next!(actor, CompleteQuoteMsg(quotes))
    end
end

function Rocket.on_next!(actor::IBQuoteAggregator, msg::RegisterResponse) 
    actor.tickerId = msg.reqId
    actor.queueId = msg.queueId

    for (subject, _) in actor.subjects
        actor.subjects[subject] = subscribe!(subject, actor)
        actor.bundle[eltype(subject)] = nothing
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

Rocket.on_next!(actor::IBQuoteAggregator, msg::CompleteQuoteMsg) = begin
    if haskey(actor.subjects, msg.body) 
        unsubscribe!(get(actor.subjects, msg.body))
        delete!(actor.subjects, msg.body)
        if isempty(actor.subjects)
            complete!(actor)
        end
    end
end

function Rocket.on_next!(actor::IBQuoteAggregator, msg::IncompleteDataRequest)
    for (_, subscription) in actor.subjects
        unsubscribe!(subscription)
    end
    next!(actor.strategy, false)
end

Rocket.on_complete!(actor::IBQuoteAggregator) = begin
    next!(actor.next, actor.bundle)
    next!(actor.requestManager, CompleteRequestMsg(actor.tickerId, actor.queueId))
end

struct RequestManagerChildActorFactory{I, A} <: Rocket.AbstractActorFactory
    main :: A
end

__make_request_manager_child_actor_factory(index::Int, main::A) where A = RequestManagerChildActorFactory{index, A}(main)

Rocket.create_actor(::Type{L}, factory::RequestManagerChildActorFactory{I, A}) where { L, I, A } = IBRequestActor{L, I, A}(factory.main)


mutable struct IBRequestManager <: AbstractManager
    conn::Union{Nothing, InteractiveBrokers.Connection}
    reqIdMaster::Int
    completion_status::BitArray{1}
    requests::Vector{Pair{<:Function, <:Tuple}}
    cancels::Vector{Pair{<:Function, <:Tuple}}
end

function Rocket.on_next!(manager::IBRequestManager, msg::RegisterRequest)
    push!(manager.requests, msg.request)
    push!(manager.cancels, msg.cancel)
    push!(manager.completion_status, false)

    reqId = manager.reqIdMaster
    queueId = length(manager.completion_status)
    next!(msg.actor, RegisterResponse(reqId, queueId))

    # Call Request
    msg.request.first(manager.conn, reqId, msg.request.second...)
    manager.reqIdMaster += 1
    setTimeout(msg.timeout) do 
        if !manager.completion_status[queueId]
            msg.cancel.first(manager.conn, reqId)
            manager.completion_status[queueId] = true
            next!(msg.actor, IncompleteDataRequest())
        end
    end
end

function Rocket.on_next!(manager::IBRequestManager, msg::CompleteRequestMsg)
    manager.completion_status[msg.queueId] = true
    manager.cancels[msg.queueId].first(manager.conn, msg.reqId)
end

function Rocket.on_next!(manager::IBRequestManager, msg::BootStrapSystem)
    empty!(manager.requests)
    empty!(manager.cancels)
    empty!(manager.completion_status)
    manager.reqIdMaster = 1
end

function Rocket.on_next!(manager::IBRequestManager, msg::ConnectionMsg)
    manager.conn = msg.conn
end

DefaultIBRequestManager = IBRequestManager(nothing, 1, BitArray{1}(), Vector{Pair{<:Function, <:Tuple}}(), Vector{Pair{<:Function, <:Tuple}}())
subscribe!(registerRequestSubject, DefaultIBRequestManager)
subscribe!(bootStrapSubject, DefaultIBRequestManager)
subscribe!(ConnectionSub, DefaultIBRequestManager)
subscribe!(completedRequests, DefaultIBRequestManager)

struct IBRequestActor{L, I, A} <: Actor{I}
    main::A
end

struct RegisteredSymbols{A} <: Actor{Any}
    symbols::Set{Symbol}
    date::Date
    next::A
end

import Base: haskey, get, delete!
function haskey(h::Dict, k::AbstractQuote)
    for key in keys(h)
        if eltype(key) <: typeof(k)
            return true
        end
    end
    false
end

function get(h::Dict, k::AbstractQuote)
    for key in keys(h)
        if eltype(key) <: typeof(k)
            return h[key]
        end
    end
end

function delete!(h::Dict, k::AbstractQuote)
    for key in keys(h)
        if eltype(key) <: typeof(k)
            delete!(h, key)
        end
    end
end

end

defaultAgg = IBQuoteAggregator(Dict{Rocket.Subject, Union{Nothing, Rocket.SubjectSubscription}}(openQuotes => nothing, highQuotes => nothing, lowQuotes => nothing, lastQuotes => nothing, volumeQuotes => nothing), lambda(Bool; on_next = (d) -> println("IncompleteDataRequest")), DefaultIBRequestManager, lambda(Dict{DataType, Union{Nothing,AbstractQuote}}; on_next = (x) -> println(x)))

next!(bootStrapSubject, BootStrapSystem())
next!(registerRequestSubject, RegisterRequest(
    Pair(
        InteractiveBrokers.reqMktData, 
        (InteractiveBrokers.Contract(symbol="AAPL",secType="STK",exchange="SMART",currency="USD"),"",true,false)
    ), 
    Pair(
        InteractiveBrokers.cancelMktData, 
        ()
    ), 
    20000, 
    defaultAgg
    )
)

defaultAgg.bundle
DefaultIBRequestManager