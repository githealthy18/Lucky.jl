module InteractiveBrokersExt

using InteractiveBrokers
using Lucky
using Rocket
using Dates

mutable struct InteractiveBrokersObservable <: Subscribable{Nothing}
    requestMappings::Dict{Pair{Int,Symbol},Tuple{Function,Rocket.Subject,Any}}
    mergedCallbacks::Dict{Symbol,Rocket.Subscribable}

    host::Union{Nothing,Any} # IPAddr (not typed to avoid having to add Sockets to Project.toml 1.10)
    port::Union{Nothing,Int}

    clientId::Union{Nothing,Int}

    connectOptions::Union{Nothing,String}
    optionalCapabilities::Union{Nothing,String}

    connectable::Union{Nothing,Rocket.ConnectableObservable}
    obs::Union{Nothing,Rocket.Subscribable}

    connection::Union{Nothing,InteractiveBrokers.Connection}
    pendingCmds::Vector{Function}

    function InteractiveBrokersObservable(host=nothing, port::Union{Nothing,Int}=nothing, clientId::Union{Nothing,Int}=nothing, connectOptions::Union{Nothing,String}=nothing, optionalCapabilities::Union{Nothing,String}=nothing)
        ib = new(
            Dict{Pair{Int,Symbol},Tuple{Function,Rocket.Subject,Any}}(),
            Dict{Symbol,Rocket.Subscribable}(),
            host,
            port,
            clientId,
            connectOptions,
            optionalCapabilities,
            nothing,
            nothing,
            nothing,
            Vector{Function}()
        )
        ib.connectable = ib |> publish()
        ib.obs = ib.connectable |> ref_count()
        return ib
    end
end

Rocket.connect(ibObservable::InteractiveBrokersObservable) = Rocket.connect(ibObservable.connectable)

struct InteractiveBrokersObservableSubscription <: Teardown
    connection::InteractiveBrokers.Connection
end

function Rocket.on_subscribe!(obs::InteractiveBrokersObservable, actor)
    fields = [:host, :port, :clientId, :connectOptions, :optionalCapabilities]
    # reduce the list to non nothing
    filter!(x -> !isnothing(getfield(obs, x)), fields)
    # map the list to their data
    values = map(x -> getfield(obs, x), fields)
    # build the NamedTuple
    params = (; zip(fields, values)...)

    obs.connection = InteractiveBrokers.connect(; params...)
    InteractiveBrokers.start_reader(obs.connection, wrapper(obs))
    # Send pending commands
    while !isempty(obs.pendingCmds)
        cmd = pop!(obs.pendingCmds)
        cmd(obs.connection)
    end

    return InteractiveBrokersObservableSubscription(obs.connection)
end

Rocket.as_teardown(::Type{<:InteractiveBrokersObservableSubscription}) = UnsubscribableTeardownLogic()

function Rocket.on_unsubscribe!(subscription::InteractiveBrokersObservableSubscription)
    disconnect(subscription.connection)
end

include("InteractiveBrokers/Requests.jl")
include("InteractiveBrokers/Callbacks.jl")

function Lucky.service(::Val{:interactivebrokers}; host=nothing, port::Int=4001, clientId::Int=1, connectOptions::String="", optionalCapabilities::String="")
    return InteractiveBrokersObservable(host, port, clientId, connectOptions, optionalCapabilities)
end

function Lucky.feed(client::InteractiveBrokersObservable, instr::Instrument) #, callback::Union{Nothing,Function}=nothing, outputType::Type=Any)    
    #TODO Next Valid Id
    requestId = 1
    # TODO options
    InteractiveBrokers.reqMktData(client, requestId, instr, "", false)

    # TODO callbacks depending on requested data

    tickPriceSubject = Subject(Lucky.PriceQuote)
    tickSizeSubject = Subject(Pair)
    tickStringSubject = Subject(DateTime)
    client.requestMappings[Pair(requestId, :tickPrice)] = (tickPrice, tickPriceSubject, instr)
    client.requestMappings[Pair(requestId, :tickSize)] = (tickSize, tickSizeSubject, instr)
    client.requestMappings[Pair(requestId, :tickString)] = (tickString, tickStringSubject, instr)

    # TODO default subject type depending on callback    
    merge = (tup::Tuple{Lucky.PriceQuote, DateTime}) -> Quote(tup[1].instrument, tup[1].price, tup[2])
    merged = Rocket.zipped(tickPriceSubject, tickStringSubject) |> Rocket.map(Lucky.PriceQuote, merge)

    # Output callback
    client.mergedCallbacks[:tick] = merged

    # subscribe!(client.obs, tickPriceSubject)
    # subscribe!(client.obs, tickStringSubject)

    return merged
end

function wrapper(client::InteractiveBrokersObservable)
    wrap = InteractiveBrokers.Wrapper(client)

    # Mandatory callbacks
    setproperty!(wrap, :error, error)
    setproperty!(wrap, :managedAccounts, managedAccounts)
    setproperty!(wrap, :nextValidId, nextValidId)

    for (pair, tuple) in client.requestMappings
        setproperty!(wrap, pair.second, tuple[1])
    end
    return wrap
end

secType(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement secType(::$(T))")
secType(::T) where {T<:Lucky.Cash} = "CASH"
secType(::T) where {T<:Lucky.Stock} = "STK"

symbol(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement symbol(::$(T))")
symbol(::T) where {C,T<:Lucky.Cash{C}} = String(C)
symbol(::T) where {S,C,T<:Lucky.Stock{S,C}} = String(S)

exchange(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement exchange(::$(T))")
exchange(::T) where {C,T<:Lucky.Cash{C}} = "IDEALPRO" # TODO: Support Virtual Forex
exchange(::T) where {S,C,T<:Lucky.Stock{S,C}} = "SMART"

function InteractiveBrokers.Contract(i::Lucky.Instrument)
    return InteractiveBrokers.Contract(
        symbol=symbol(i),
        secType=secType(i),
        exchange=exchange(i),
        currency=Lucky.Units.currency(i)
    )
end

# abstract type IBBaseMsg <: AbstractMsg end

# struct TickPriceMsg <: IBBaseMsg
#     tickerId::Int
#     field::String
#     price::Union{Float64,Nothing}
#     size::Union{Float64,Nothing}
#     attrib::InteractiveBrokers.TickAttrib
# end

# mutable struct IBPriceActor <: Actor{TickPriceMsg} end

# struct TickSizeMsg <: IBBaseMsg
#     tickerId::Int
#     field::String
#     size::Union{Float64,Nothing}
# end

# mutable struct IBSizeActor <: Actor{TickSizeMsg} end

# struct TickOptionMsg <: IBBaseMsg
#     tickerId::Int
#     tickType::String
#     tickAttrib::Int
#     impliedVol::Union{Float64,Nothing}
#     delta::Union{Float64,Nothing}
#     optPrice::Union{Float64,Nothing}
#     pvDividend::Union{Float64,Nothing}
#     gamma::Union{Float64,Nothing}
#     vega::Union{Float64,Nothing}
#     theta::Union{Float64,Nothing}
#     undPrice::Union{Float64,Nothing}
# end

# struct HistoricalDataMsg <: IBBaseMsg
#     tickerId::Int
#     dataframe::DataFrame
# end
  
# struct SecDefOptParamsMsg <: IBBaseMsg
#     reqId::Int
#     exchange::String
#     underlyingConId::Int
#     tradingClass::String
#     multiplier::String
#     expirations::Vector{String}
#     strikes::Vector{Float64}
# end
  
# struct ErrorMsg <: IBBaseMsg
#     id::Union{Int,Nothing}
#     errorCode::Union{Int,Nothing}
#     errorString::String
#     advancedOrderRejectJson::String
# end
  
# struct AccountSummaryMsg <: IBBaseMsg
#     id::Int
#     account::String
#     tag::String
#     value::String
#     currency::String
# end

# struct OrderIdMsg <: IBBaseMsg
#     id::Int
# end

# defaultMapper = Dict{Symbol,Pair{Function,Type}}()
# defaultMapper[:tickPrice] = Pair((x...) -> TickPriceMsg(x...), TickPriceMsg)
# defaultMapper[:tickSize] = Pair((x...) -> TickSizeMsg(x...), TickSizeMsg)
# defaultMapper[:tickOptionComputation] = Pair((x...) -> TickOptionMsg(x...), TickOptionMsg)
# defaultMapper[:historicalData] = Pair((x...) -> HistoricalDataMsg(x...), HistoricalDataMsg)
# defaultMapper[:securityDefinitionOptionalParameter,] = Pair((x...) -> SecDefOptParamsMsg(x...), SecDefOptParamsMsg)
# defaultMapper[:error] = Pair((x...) -> ErrorMsg(x...), ErrorMsg)
# defaultMapper[:nextValidId] = Pair((x...) -> OrderIdMsg(x...), OrderIdMsg)
# defaultMapper[:accountSummary] = Pair((x...) -> AccountSummaryMsg(x...), AccountSummaryMsg)

# refCounts = Dict{InteractiveBrokersObservable, Rocket.Subscribable}()

# function Lucky.feed(client::InteractiveBrokersObservable, event::Symbol, applyFunction::Function, outputType::Type)
#     subject = Subject(outputType)

#     push!(client.events, event)
#     push!(client.targets, subject)
#     push!(client.applys, applyFunction)

#     return subject
# end

# function Lucky.feed(client::InteractiveBrokersObservable, event::Symbol, applyFunction::Function, outputType::Type{<:TickPriceMsg})
#     subject = Subject(outputType)

#     price_actor = IBPriceActor()
#     subscribe!(subject, price_actor)

#     push!(client.events, event)
#     push!(client.targets, subject)
#     push!(client.applys, applyFunction)

#     return subject
# end

# function Lucky.feed(client::InteractiveBrokersObservable, event::Symbol, applyFunction::Function, outputType::Type{<:TickSizeMsg})
#     subject = Subject(outputType)

#     size_actor = IBSizeActor()
#     subscribe!(subject, size_actor)

#     push!(client.events, event)
#     push!(client.targets, subject)
#     push!(client.applys, applyFunction)

#     return subject
# end

# function Lucky.feed(client::InteractiveBrokersObservable, event::Symbol)
#     haskey(defaultMapper, event) && return Lucky.feed(client, event, defaultMapper[event][1], defaultMapper[event][2])
#     return faulted("No default mapping function for $(event). Provide one or contribute a default implementation.")
# end

# function wrapper(client::InteractiveBrokersObservable)
#     wrap = InteractiveBrokers.Wrapper()
#     for (idx, _) in enumerate(client.events)
#         setproperty!(wrap, client.events[idx], (x...) -> next!(client.targets[idx], client.applys[idx](x...)))
#     end
#     return wrap
# end
# # # import Lucky: IB, IBAccount

# Rocket.on_next!(actor::IBPriceActor, msg::TickPriceMsg) = begin
#     if msg.field == "BID"
#         next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.price, Dates.today(), BidTick()))
#     elseif msg.field == "ASK"
#         next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.price, Dates.today(), AskTick()))
#     elseif msg.field == "LAST"
#         next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.price, Dates.today(), LastTick()))
#     elseif msg.field == "OPEN"
#         next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.price, Dates.today(), OpenTick()))
#     elseif msg.field == "HIGH"
#         next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.price, Dates.today(), HighTick()))
#     elseif msg.field == "LOW"
#         next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.price, Dates.today(), LowTick()))
#     end
# end

# Rocket.on_next!(actor::IBSizeActor, msg::TickSizeMsg) = begin
#     if msg.field == "BID_SIZE"
#         next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.size, Dates.today(), BidSizeTick()))
#     elseif msg.field == "ASK_SIZE"
#         next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.size, Dates.today(), AskSizeTick()))
#     elseif msg.field == "LAST_SIZE"
#         next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), msg.size, Dates.today(), LastSizeTick()))
#     elseif msg.field == "VOLUME"
#         next!(PRICE_QUOTES, Quote(DataRequest(msg.tickerId), 100*msg.size, Dates.today(), VolumeTick()))
#     end
# end

# function Rocket.on_next!(actor::RequestActor, msg::IBBaseMsg)
#     if actor.tickerId == msg.tickerId
#         next!(actor.main, msg)
#         unsubscribe!(actor.subscription)
#         next!(actor.requestManager, CompleteRequestMsg(actor.tickerId, actor.queueId))
#     end
# end


# struct RegisteredSymbols{A} <: Actor{Any}
#     symbols::Set{Symbol}
#     date::Date
#     next::A
# end

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