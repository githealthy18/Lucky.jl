module InteractiveBrokersExt

using Lucky
using Rocket
using DataFrames
using Dates
using InteractiveBrokers

import Lucky: QuoteType, AbstractQuote, Quote, AbstractManager, PriceQuote

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

struct IBConnection{C<:InteractiveBrokers.Connection} <: Connection 
    connection::C
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
    wrapper::IBConnection
end

function Rocket.on_subscribe!(obs::InteractiveBrokersObservable, actor)
    ib = InteractiveBrokers.connect(;port=obs.port, clientId=obs.clientId, obs.connectOptions, obs.optionalCapabilities)
    InteractiveBrokers.start_reader(ib, wrapper(obs))
    return InteractiveBrokersObservableSubscription(IBConnection(ib))
end

Rocket.as_teardown(::Type{<:InteractiveBrokersObservableSubscription}) = UnsubscribableTeardownLogic()

function Rocket.on_unsubscribe!(subscription::InteractiveBrokersObservableSubscription)
    InteractiveBrokers.disconnect(subscription.wrapper.connection)
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
# # import Lucky: IB, IBAccount

const PRICE_QUOTES = Subject(PriceQuote)

Rocket.on_next!(actor::IBPriceActor, msg::TickPriceMsg) = begin
    if msg.field == "BID"
        next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.price, Dates.today(), BidTick()))
    elseif msg.field == "ASK"
        next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.price, Dates.today(), AskTick()))
    elseif msg.field == "LAST"
        next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.price, Dates.today(), LastTick()))
    elseif msg.field == "OPEN"
        next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.price, Dates.today(), OpenTick()))
    elseif msg.field == "HIGH"
        next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.price, Dates.today(), HighTick()))
    elseif msg.field == "LOW"
        next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.price, Dates.today(), LowTick()))
    end
end

Rocket.on_next!(actor::IBSizeActor, msg::TickSizeMsg) = begin
    if msg.field == "BID_SIZE"
        next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.size, Dates.today(), BidSizeTick()))
    elseif msg.field == "ASK_SIZE"
        next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.size, Dates.today(), AskSizeTick()))
    elseif msg.field == "LAST_SIZE"
        next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.size, Dates.today(), LastSizeTick()))
    elseif msg.field == "VOLUME"
        next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), 100*msg.size, Dates.today(), VolumeTick()))
    end
end

function Rocket.on_next!(actor::RequestActor, msg::IBBaseMsg)
    if actor.tickerId == msg.tickerId
        next!(actor.main, msg)
        unsubscribe!(actor.subscription)
        next!(actor.requestManager, CompleteRequestMsg(actor.tickerId, actor.queueId))
    end
end


struct RegisteredSymbols{A} <: Actor{Any}
    symbols::Set{Symbol}
    date::Date
    next::A
end

end

# subscribe!(lastQuotes, logger("last"))

# subscribe!(volumeQuotes, logger("vol"))

# subscribe!(highQuotes, logger("high"))

# defaultAgg = IBQuoteAggregator(Dict{Rocket.Subject, Union{Nothing, Rocket.SubjectSubscription}}(openQuotes => nothing, highQuotes => nothing, lowQuotes => nothing, lastQuotes => nothing, volumeQuotes => nothing), Rocket.lambda(Bool; on_next = (d) -> println("IncompleteDataRequest")), DefaultIBRequestManager, Rocket.lambda(Dict{DataType, Union{Nothing, AbstractQuote}};on_next = (x) -> println(x)))

# next!(bootStrapSubject, BootStrapSystem())
# next!(registerRequestSubject, RegisterRequest(
#     Pair(
#         InteractiveBrokers.reqMktData, 
#         (InteractiveBrokers.Contract(symbol="AAPL",secType="STK",exchange="SMART",currency="USD"),"",false,false)
#     ), 
#     Pair(
#         InteractiveBrokers.cancelMktData, 
#         ()
#     ), 
#     60000, 
#     defaultAgg
#     )
# )

# InteractiveBrokers.reqMarketDataType(DefaultIBServiceManager.subscription.connection, InteractiveBrokers.MarketDataType(2))
# defaultAgg.bundle
# DefaultIBRequestManager