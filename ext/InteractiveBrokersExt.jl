module InteractiveBrokersExt

using InteractiveBrokers
using Lucky
using Rocket
using Dates
using Dictionaries
using DataFrames

mutable struct InteractiveBrokersObservable <: Subscribable{Nothing}
    requestMappings::Dictionary{Pair{Int,Symbol},Tuple{Function,Rocket.Subject,Any,Bool}}
    mergedCallbacks::Dictionary{Pair{Instrument,Symbol},Union{Rocket.Subject, Rocket.Subscribable}}

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
            Dictionary{Pair{Int,Symbol},Tuple{Function,Rocket.Subject,Any}}(),
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
    return filter(((k,v),) -> last(k) in requestTypes && last(v)==instr, pairs(dict))
end

function getCallbacks(dict::Dictionary, instr::Instrument)
    return filter(((k,v),) -> first(k)==instr, pairs(dict))
end

function Lucky.feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:livedata}; timeout=30000) #, callback::Union{Nothing,Function}=nothing, outputType::Type=Any)    
    requestId = nextRequestId(client)
    # TODO options
    InteractiveBrokers.reqMktData(client, requestId, instr, "", false)

    # TODO callbacks depending on requested data

    tickPriceSubject = Subject(Lucky.PriceQuote)
    tickSizeSubject = Subject(Lucky.VolumeQuote)
    tickStringSubject = Subject(DateTime)
    insert!(client.requestMappings, Pair(requestId, :tickPrice), (tickPrice, tickPriceSubject, instr, false))
    insert!(client.requestMappings, Pair(requestId, :tickSize), (tickSize, tickSizeSubject, instr, false))
    insert!(client.requestMappings, Pair(requestId, :tickString), (tickString, tickStringSubject, instr, false))
    insert!(client.requestMappings, Pair(requestId, :tickGeneric), (tickGeneric, Subject(Pair), instr, false))
    insert!(client.requestMappings, Pair(requestId, :marketDataType), (marketDataType, Subject(Pair), instr, false))
    insert!(client.requestMappings, Pair(requestId, :tickReqParams), (tickReqParams, Subject(Pair), instr, false))

    # TODO default subject type depending on callback    
    merge = (tup::Tuple{Lucky.PriceQuote, DateTime}) -> Quote(tup[1].instrument, tup[1].tick, tup[1].price, tup[1].size, tup[2])
    merged = tickPriceSubject |> with_latest(tickStringSubject) |> Rocket.map(Lucky.PriceQuote, merge)

    merge_vol = (tup::Tuple{Lucky.VolumeQuote, DateTime}) -> Quote(tup[1].instrument, tup[1].volume, tup[2])
    merged_vol = tickSizeSubject |> with_latest(tickStringSubject) |> Rocket.map(Lucky.VolumeQuote, merge_vol)

    # Output callback
    insert!(client.mergedCallbacks, Pair(instr, :tick), merged)
    insert!(client.mergedCallbacks, Pair(instr, :volume), merged_vol)

    setTimeout(timeout) do 
        if !client.requestMappings[Pair(requestId, :tickPrice)][4]
            Lucky.end_feed(client, instr, Val(:livedata))
        end
    end

    # subscribe!(client.obs, tickPriceSubject)
    # subscribe!(client.obs, tickStringSubject)

    return merged, merged_vol
end

function Lucky.end_feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:livedata})
    ongoingRequests = getRequests(client.requestMappings, [:tickSize,:tickPrice,:tickGeneric,:tickReqParams,:tickString,:marketDataType], instr)
    requestId = first(first(keys(ongoingRequests)))

    ongoingCallbacks = getCallbacks(client.mergedCallbacks, instr)

    Lucky.Utils.deletefrom!(client.requestMappings, keys(ongoingRequests))
    Lucky.Utils.deletefrom!(client.mergedCallbacks, keys(ongoingCallbacks))

    InteractiveBrokers.cancelMktData(client, requestId)
end

function Lucky.feed(client, instr::Instrument, ::Val{:historicaldata}; timeout=60000)
    requestId = nextRequestId(client)

    InteractiveBrokers.reqHistoricalData(client, requestId, instr, "", "3 Y", "1 day", "TRADES" ,false, 1, false)

    historicalDataSubject = Subject(DataFrame)
    insert!(client.requestMappings, Pair(requestId, :historicalData), (historicalData, historicalDataSubject, instr, false))
    insert!(client.mergedCallbacks, Pair(instr, :history), historicalDataSubject)

    setTimeout(timeout) do 
        if !client.requestMappings[Pair(requestId, :historicalData)][4]
            Lucky.end_feed(client, instr, Val(:historicaldata))
        end
    end

    return historicalDataSubject
end

function Lucky.end_feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:historicaldata})
    ongoingRequests = getRequests(client.requestMappings, [:historicalData], instr)
    requestId = first(first(keys(ongoingRequests)))

    ongoingCallbacks = getCallbacks(client.mergedCallbacks, instr)

    Lucky.Utils.deletefrom!(client.requestMappings, keys(ongoingRequests))
    Lucky.Utils.deletefrom!(client.mergedCallbacks, keys(ongoingCallbacks))

    InteractiveBrokers.cancelHistoricalData(client, requestId)
end

function Lucky.feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:securityDefinitionOptionalParameter}; timeout=60000)
    requestId = nextRequestId(client)

    InteractiveBrokers.secDefOptParams(client, requestId, instr, "")

    expirationSubject = Subject(Date)
    strikeSubject = Subject(Float64)
    insert!(client.requestMappings, Pair(requestId, :expirations), (securityDefinitionOptionalParameter, expirationSubject, instr, false))
    insert!(client.requestMappings, Pair(requestId, :strikes), (securityDefinitionOptionalParameter, strikeSubject, instr, false))
    insert!(client.mergedCallbacks, Pair(instr, :expirations), expirationSubject)
    insert!(client.mergedCallbacks, Pair(instr, :strikes), strikeSubject)

    source = combineLatest(expirationSubject |> take(4), strikeSubject) |> merge_map(Tuple, d -> from([CALL, PUT]) |> map(Tuple, r -> (d..., r))) |> map(Option, d -> Option(instr, d[3], d[2], d[1]))

    setTimeout(timeout) do 
        if !client.requestMappings[Pair(requestId, :secDefOptParams)][4]
            Lucky.end_feed(client, instr, Val(:securityDefinitionOptionalParameter))
        end
    end

    return source
end

function Lucky.end_feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:securityDefinitionOptionalParameter})
    ongoingRequests = getRequests(client.requestMappings, [:expirations,:strikes], instr)
    requestId = first(first(keys(ongoingRequests)))

    ongoingCallbacks = getCallbacks(client.mergedCallbacks, instr)

    Lucky.Utils.deletefrom!(client.requestMappings, keys(ongoingRequests))
    Lucky.Utils.deletefrom!(client.mergedCallbacks, keys(ongoingCallbacks))

    InteractiveBrokers.cancelSecDefOptParams(client, requestId)
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
    setproperty!(wrap, :secDefOptParams, secDefOptParams)
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