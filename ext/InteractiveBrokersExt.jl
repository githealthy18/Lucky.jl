module InteractiveBrokersExt

using InteractiveBrokers
using Lucky
using Rocket
using Dates
using Dictionaries
using DataFrames

struct CallbackKey
    requestId::Int
    callbackSymbol::Symbol
    tickType::Union{InteractiveBrokers.TickTypes.TICK_TYPES, Nothing}
end

struct CallbackValue
    callbackFunction::Function
    subject::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance, Nothing}
    instrument::Lucky.Instrument
end

const CallbackMapping = Dictionary{CallbackKey,CallbackValue}

struct TickQuoteFeeds <: CompletionActor{Any}
    lastPrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    bidPrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    askPrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    markPrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    highPrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    lowPrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    openPrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    closePrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    volume::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    askSize::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    bidSize::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    lastSize::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    tickString::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
end

function Rocket.complete!(pwithproxy::ProxyObservable)
    Rocket.complete!(pwithproxy.proxied_source.main)
end

function Rocket.on_complete!(feeds::T) where {T<:TickQuoteFeeds}
    completions = [
        Rocket.complete!(getproperty(feeds,name)) for name in fieldnames(T)
    ]
end

function Rocket.isactive(subject::Rocket.RecentSubjectInstance)
    return subject.subject.isactive
end

function Rocket.isactive(withproxy::ProxyObservable)
    return Rocket.isactive(withproxy.proxied_source.main)
end

function Rocket.isactive(feeds::T) where {T<:TickQuoteFeeds}
    isactive = [ Rocket.isactive(getproperty(feeds, name)) for name in fieldnames(T) ]
    return any(isactive)
end

mutable struct InteractiveBrokersObservable <: Subscribable{Nothing}
    requestMappings::CallbackMapping
    mergedCallbacks::Dictionary{Pair{Instrument, Symbol},Union{Rocket.Subscribable,Rocket.RecentSubjectInstance,TickQuoteFeeds}}

    host::Union{Nothing,Any} # IPAddr (not typed to avoid having to add Sockets to Project.toml 1.10)
    port::Union{Nothing,Int}

    clientId::Union{Nothing,Int}
    requestId::Int
    nextValidId::Union{Missing,Int} #

    connectOptions::Union{Nothing,String}
    optionalCapabilities::Union{Nothing,String}

    connectable::Union{Nothing,Rocket.ConnectableObservable}
    obs::Union{Nothing,Rocket.Subscribable}

    connection::Union{Nothing,InteractiveBrokers.Connection}
    pendingCmds::Vector{Function}

    function InteractiveBrokersObservable(host=nothing, port::Union{Nothing,Int}=nothing, clientId::Union{Nothing,Int}=nothing, connectOptions::Union{Nothing,String}=nothing, optionalCapabilities::Union{Nothing,String}=nothing)
        ib = new(
            CallbackMapping(),
            Dictionary{Symbol,Rocket.Subscribable}(),
            host,
            port,
            clientId,
            0,
            missing,
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
    InteractiveBrokers.start_reader(obs.connection, wrapper(obs), DataFrame)
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

function Lucky.service(::Val{:interactivebrokers}; host=nothing, port::Int=7497, clientId::Int=1, connectOptions::String="", optionalCapabilities::String="")
    return InteractiveBrokersObservable(host, port, clientId, connectOptions, optionalCapabilities)
end

function nextRequestId(client::InteractiveBrokersObservable)
    client.requestId += 1
    return client.requestId
end

function nextValidId(ib::InteractiveBrokersObservable)
    isnothing(ib.connection) && return nothing

    if ismissing(ib.nextValidId)
        InteractiveBrokers.reqIds(ib)
    end

    return ib.nextValidId
end

function getRequests(dict::Dictionary, requestTypes::Vector{Symbol}, instr::Instrument)
    return filter(((k,v),) -> k.callbackSymbol in requestTypes && v.instrument==instr, pairs(dict))
end

function Lucky.feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:livedata}; timeout=30000) #, callback::Union{Nothing,Function}=nothing, outputType::Type=Any)    
    requestId = nextRequestId(client)
    # TODO options
    InteractiveBrokers.reqMktData(client, requestId, instr, "232", false)

    # TODO callbacks depending on requested data

    lastPriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote; scheduler=AsyncScheduler()))

    bidPriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote; scheduler=AsyncScheduler()))
    askPriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote; scheduler=AsyncScheduler()))
    markPriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote; scheduler=AsyncScheduler()))

    highPriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote; scheduler=AsyncScheduler()))
    lowPriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote; scheduler=AsyncScheduler()))
    openPriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote; scheduler=AsyncScheduler()))
    closePriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote; scheduler=AsyncScheduler()))

    volumeSubject = RecentSubject(Lucky.VolumeQuote, Subject(Lucky.VolumeQuote, scheduler=AsyncScheduler()))
    askSizeSubject = RecentSubject(Lucky.VolumeQuote, Subject(Lucky.VolumeQuote, scheduler=AsyncScheduler()))
    bidSizeSubject = RecentSubject(Lucky.VolumeQuote, Subject(Lucky.VolumeQuote, scheduler=AsyncScheduler()))
    lastSizeSubject = RecentSubject(Lucky.VolumeQuote, Subject(Lucky.VolumeQuote, scheduler=AsyncScheduler()))

    tickStringSubject = RecentSubject(DateTime, Subject(DateTime; scheduler=AsyncScheduler()))

    insert!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.LAST), CallbackValue(tickPrice, lastPriceSubject, instr))

    insert!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.BID), CallbackValue(tickPrice, bidPriceSubject, instr))
    insert!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.ASK), CallbackValue(tickPrice, askPriceSubject, instr))
    insert!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.MARK_PRICE), CallbackValue(tickPrice, markPriceSubject, instr))

    insert!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.HIGH), CallbackValue(tickPrice, highPriceSubject, instr))
    insert!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.LOW), CallbackValue(tickPrice, lowPriceSubject, instr))
    insert!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.OPEN), CallbackValue(tickPrice, openPriceSubject, instr))
    insert!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.CLOSE), CallbackValue(tickPrice, closePriceSubject, instr))

    insert!(client.requestMappings, CallbackKey(requestId, :tickSize, InteractiveBrokers.TickTypes.VOLUME), CallbackValue(tickSize, volumeSubject, instr))
    insert!(client.requestMappings, CallbackKey(requestId, :tickSize, InteractiveBrokers.TickTypes.ASK_SIZE), CallbackValue(tickSize, askSizeSubject, instr))
    insert!(client.requestMappings, CallbackKey(requestId, :tickSize, InteractiveBrokers.TickTypes.BID_SIZE), CallbackValue(tickSize, bidSizeSubject, instr))
    insert!(client.requestMappings, CallbackKey(requestId, :tickSize, InteractiveBrokers.TickTypes.LAST_SIZE), CallbackValue(tickSize, lastSizeSubject, instr))
    
    insert!(client.requestMappings, CallbackKey(requestId, :tickString, InteractiveBrokers.TickTypes.LAST_TIMESTAMP), CallbackValue(tickString, tickStringSubject, instr))
    insert!(client.requestMappings, CallbackKey(requestId, :tickGeneric, InteractiveBrokers.TickTypes.LAST), CallbackValue(tickGeneric, nothing, instr))
    insert!(client.requestMappings, CallbackKey(requestId, :marketDataType, InteractiveBrokers.TickTypes.LAST), CallbackValue(marketDataType, nothing, instr))
    insert!(client.requestMappings, CallbackKey(requestId, :tickReqParams, InteractiveBrokers.TickTypes.LAST), CallbackValue(tickReqParams, nothing, instr))

    # TODO default subject type depending on callback    
    merge = (tup::Tuple{Lucky.PriceQuote, DateTime}) -> Quote(tup[1].instrument, tup[1].tick, tup[1].price, tup[1].size, tup[2])
    last = lastPriceSubject |> with_latest(tickStringSubject) |> Rocket.map(Lucky.PriceQuote, merge)

    merge_lastSize = (tup::Tuple{Lucky.VolumeQuote, DateTime}) -> Quote(tup[1].instrument, tup[1].tick, tup[1].volume, tup[2])
    lastSize = lastSizeSubject |> with_latest(tickStringSubject) |> Rocket.map(Lucky.VolumeQuote, merge_lastSize)

    output = TickQuoteFeeds(
        last,
        bidPriceSubject,
        askPriceSubject,
        markPriceSubject,
        highPriceSubject,
        lowPriceSubject,
        openPriceSubject,
        closePriceSubject,
        volumeSubject,
        askSizeSubject,
        bidSizeSubject,
        lastSize,
        tickStringSubject
    )

    # Output callback
    insert!(client.mergedCallbacks, Pair(instr, :livedata), output)

    setTimeout(timeout) do 
        if Rocket.isactive(output)
            Lucky.end_feed(client, instr, Val(:livedata))
        end
    end

    return output
end

function Lucky.end_feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:livedata})
    ongoingRequests = getRequests(client.requestMappings, [:tickSize,:tickPrice,:tickGeneric,:tickReqParams,:tickString,:marketDataType], instr)
    requestId = first(keys(ongoingRequests)).requestId

    complete!(client.mergedCallbacks[Pair(instr, :livedata)])

    Lucky.Utils.deletefrom!(client.requestMappings, keys(ongoingRequests))
    Lucky.Utils.delete!(client.mergedCallbacks, Pair(instr, :livedata))

    InteractiveBrokers.cancelMktData(client, requestId)
end

function Lucky.feed(client, instr::Instrument, ::Val{:historicaldata}; timeout=60000)
    requestId = nextRequestId(client)

    InteractiveBrokers.reqHistoricalData(client, requestId, instr, "", "3 Y", "1 day", "TRADES" ,false, 1, false)

    historicalDataSubject = RecentSubject(DataFrame, Subject(DataFrame; scheduler=AsyncScheduler()))
    insert!(client.requestMappings, CallbackKey(requestId, :historicalData, nothing), CallbackValue(historicalData, historicalDataSubject, instr))
    insert!(client.mergedCallbacks, Pair(instr, :historicaldata), historicalDataSubject)

    setTimeout(timeout) do 
        if Rocket.isactive(historicalDataSubject)
            Lucky.end_feed(client, instr, Val(:historicaldata))
        end
    end

    return historicalDataSubject
end

function Lucky.end_feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:historicaldata})
    ongoingRequests = getRequests(client.requestMappings, [:historicalData], instr)
    requestId = first(keys(ongoingRequests)).requestId

    complete!(client.mergedCallbacks[Pair(instr, :historicaldata)])

    Lucky.Utils.deletefrom!(client.requestMappings, keys(ongoingRequests))
    Lucky.Utils.delete!(client.mergedCallbacks, Pair(instr, :historicaldata))

    InteractiveBrokers.cancelHistoricalData(client, requestId)
end

function Lucky.feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:securityDefinitionOptionalParameter})
    requestId = nextRequestId(client)

    conId = Lucky.feed(client, instr, Val(:contractDetails)) |> Rocket.first()

    subscribe!(conId, lambda(InteractiveBrokers.ContractDetails; on_next=(d)-> InteractiveBrokers.reqSecDefOptParams(client, requestId, instr, "", d.contract.conId)))

    expirationSubject = RecentSubject(Date)
    strikeSubject = RecentSubject(Float64)
    insert!(client.requestMappings, CallbackKey(requestId, :expirations, nothing), CallbackValue(securityDefinitionOptionalParameter, expirationSubject, instr))
    insert!(client.requestMappings, CallbackKey(requestId, :strikes, nothing), CallbackValue(securityDefinitionOptionalParameter, strikeSubject, instr))
    insert!(client.mergedCallbacks, Pair(instr, :expirations), expirationSubject)
    insert!(client.mergedCallbacks, Pair(instr, :strikes), strikeSubject)

    setTimeout(30000) do 
        if Rocket.isactive(expirationSubject) || Rocket.isactive(strikeSubject)
            Lucky.end_feed(client, instr, Val(:securityDefinitionOptionalParameter))
        end
    end
    return expirationSubject, strikeSubject
end

function Lucky.end_feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:securityDefinitionOptionalParameter})
    ongoingRequests = getRequests(client.requestMappings, [:expirations,:strikes], instr)
    Lucky.Utils.deletefrom!(client.requestMappings, keys(ongoingRequests))

    complete!(client.mergedCallbacks[Pair(instr, :expirations)])
    complete!(client.mergedCallbacks[Pair(instr, :strikes)])
    Lucky.Utils.delete!(client.mergedCallbacks, Pair(instr, :expirations))
    Lucky.Utils.delete!(client.mergedCallbacks, Pair(instr, :strikes))
end

function Lucky.feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:contractDetails})
    requestId = nextRequestId(client)

    InteractiveBrokers.reqContractDetails(client, requestId, instr)

    contractDetailsSubject = RecentSubject(InteractiveBrokers.ContractDetails, Subject(InteractiveBrokers.ContractDetails; scheduler=AsyncScheduler()))
    insert!(client.requestMappings, CallbackKey(requestId, :contractDetails, nothing), CallbackValue(contractDetails, contractDetailsSubject, instr))
    insert!(client.mergedCallbacks, Pair(instr, :contractDetails), contractDetailsSubject)

    setTimeout(30000) do 
        if Rocket.isactive(contractDetailsSubject)
            Lucky.end_feed(client, instr, Val(:contractDetails))
        end
    end

    return contractDetailsSubject
end

function Lucky.end_feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:contractDetails})
    ongoingRequests = getRequests(client.requestMappings, [:contractDetails], instr)
    complete!(client.mergedCallbacks[Pair(instr, :contractDetails)])
    Lucky.Utils.deletefrom!(client.requestMappings, keys(ongoingRequests))
    Lucky.Utils.delete!(client.mergedCallbacks, Pair(instr, :contractDetails))
end

function wrapper(client::InteractiveBrokersObservable)
    wrap = InteractiveBrokers.Wrapper(client)

    # Mandatory callbacks
    setproperty!(wrap, :error, error)
    setproperty!(wrap, :managedAccounts, managedAccounts)
    setproperty!(wrap, :nextValidId, nextValidId)

    # Optional callbacks
    setproperty!(wrap, :accountSummary, accountSummary)
    setproperty!(wrap, :contractDetails, contractDetails)
    setproperty!(wrap, :tickPrice, tickPrice)
    setproperty!(wrap, :tickSize, tickSize)
    setproperty!(wrap, :tickString, tickString)
    setproperty!(wrap, :tickGeneric, tickGeneric)
    setproperty!(wrap, :marketDataType, marketDataType)
    setproperty!(wrap, :tickReqParams, tickReqParams)
    setproperty!(wrap, :historicalData, historicalData)
    setproperty!(wrap, :securityDefinitionOptionalParameter, securityDefinitionOptionalParameter)
    setproperty!(wrap, :tickOptionComputation, tickOptionComputation)

    return wrap
end

secType(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement secType(::$(T))")
secType(::T) where {T<:Lucky.Cash} = "CASH"
secType(::T) where {T<:Lucky.Stock} = "STK"
secType(::T) where {T<:Lucky.Option} = "OPT"

symbol(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement symbol(::$(T))")
symbol(::T) where {C,T<:Lucky.Cash{C}} = String(C)
symbol(::T) where {S,C,T<:Lucky.Stock{S,C}} = String(S)
symbol(::Type{<:Lucky.Stock{S,C}}) where {S,C} = String(S)
symbol(::T) where {S,R,K,E,T<:Lucky.Option{S,R,K,E}} = symbol(S)

conId(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement conId(::$(T))")
conId(::T) where {C,T<:Lucky.Cash{C}} = nothing

exchange(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement exchange(::$(T))")
exchange(::T) where {C,T<:Lucky.Cash{C}} = "IDEALPRO" # TODO: Support Virtual Forex
exchange(::T) where {S,C,T<:Lucky.Stock{S,C}} = "SMART"
exchange(::T) where {S,R,K,E,T<:Lucky.Option{S,R,K,E}} = "SMART"

right(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement right(::$(T))")
right(::T) where {S,R,K,E,T<:Lucky.Option{S,R,K,E}} = String(R)

expiry(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement expiry(::$(T))")
expiry(::T) where {S,R,K,E,T<:Lucky.Option{S,R,K,E}} = Dates.format(E, "yyyymmdd")

function InteractiveBrokers.Contract(i::Lucky.Instrument)
    return InteractiveBrokers.Contract(
        symbol=symbol(i),
        secType=secType(i),
        exchange=exchange(i),
        currency=Lucky.Units.currency(i)
    )
end

function InteractiveBrokers.Contract(i::Lucky.Option)
    return InteractiveBrokers.Contract(
        symbol=symbol(i),
        secType=secType(i),
        exchange=exchange(i),
        currency=Lucky.Units.currency(i),
        right=right(i),
        lastTradeDateOrMonth=expiry(i)
    )
end

end