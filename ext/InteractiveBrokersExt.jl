module InteractiveBrokersExt

using InteractiveBrokers
using Lucky
using Rocket
using Dates
using Dictionaries
using DataFrames
import Lucky.Units as Units
using AutoHashEquals

import Base: close

@auto_hash_equals cache=true struct CallbackKey
    requestId::Int
    callbackSymbol::Symbol
    tickType::Union{InteractiveBrokers.TickTypes.TICK_TYPES, Nothing}
end

@auto_hash_equals cache=true struct CallbackValue
    callbackFunction::Function
    subject::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance, Nothing}
    instrument::Union{Lucky.Instrument,Nothing}
end

const CallbackMapping = Dictionary{CallbackKey,CallbackValue}

@auto_hash_equals cache=true struct CallbackPositionsKey
    callbackSymbol::Symbol
end

@auto_hash_equals cache=true struct CallbackPositionsValue
    callbackFunction::Function
    subject::Rocket.Subject
end

const CallbackPositionsMapping = Dict{CallbackPositionsKey,CallbackPositionsValue}

mutable struct InteractiveBrokersObservable <: Subscribable{Nothing}
    requestMappings::CallbackMapping
    mergedCallbacks::Dictionary{Pair{Union{Nothing,Instrument}, Symbol},Union{Rocket.Subscribable,Rocket.RecentSubjectInstance,TickQuoteFeed}}

    requestPositionsMappings::CallbackPositionsMapping
    fills::Union{Nothing, Rocket.Subject}

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

    function InteractiveBrokersObservable(fills=nothing, host=nothing, port::Union{Nothing,Int}=nothing, clientId::Union{Nothing,Int}=nothing, connectOptions::Union{Nothing,String}=nothing, optionalCapabilities::Union{Nothing,String}=nothing)
        ib = new(
            CallbackMapping(),
            Dictionary{Pair{Union{Nothing,Instrument}, Symbol},Union{Rocket.Subscribable,Rocket.RecentSubjectInstance,TickQuoteFeed}}(),
            CallbackPositionsMapping(),
            fills,
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
    sleep(1) # Wait for the connection to be established
    # Send pending commands
    while !isempty(obs.pendingCmds)
        cmd = pop!(obs.pendingCmds)
        cmd(obs.connection)
    end
    return InteractiveBrokersObservableSubscription(obs.connection)
end

Rocket.as_teardown(::Type{<:InteractiveBrokersObservableSubscription}) = UnsubscribableTeardownLogic()

function Rocket.on_unsubscribe!(subscription::InteractiveBrokersObservableSubscription)
    InteractiveBrokers.disconnect(subscription.connection)
end

include("InteractiveBrokers/Requests.jl")
include("InteractiveBrokers/Callbacks.jl")
include("InteractiveBrokers/Exchange.jl")

function Lucky.service(::Val{:interactivebrokers}; fills=nothing, host=nothing, port::Int=7497, clientId::Int=1, connectOptions::String="", optionalCapabilities::String="")
    return InteractiveBrokersObservable(fills, host, port, clientId, connectOptions, optionalCapabilities)
end

function nextRequestId(client::InteractiveBrokersObservable)
    client.requestId += 1
    return client.requestId
end

function nextValidId(ib::InteractiveBrokersObservable)
    isnothing(ib.connection) && return nothing

    InteractiveBrokers.reqIds(ib)
    return ib.nextValidId
end

function getRequests(dict::Dictionary, requestTypes::Vector{Symbol}, instr::Instrument)
    return filter(((k,v),) -> k.callbackSymbol in requestTypes && v.instrument==instr, pairs(dict))
end

function getRequests(dict::Dictionary, requestTypes::Vector{Symbol})
    return filter(((k,v),) -> k.callbackSymbol in requestTypes, pairs(dict))
end

function getRequestsById(dict::Dictionary, id::Int)
    return filter(((k,v),) -> k.requestId==id, pairs(dict))
end

function getCallbacksByInstrument(dict::Dictionary, instr::Union{Nothing, Instrument})
    return filter(((k,v),) -> first(k)==instr, pairs(dict))
end

struct IbKrPosition{I<:Instrument} <: Lucky.AbstractPosition
    account::String
    instrument::I
    size::Float64
    avgCost::Float64
    timestamp::DateTime
end

function Lucky.positions(client::InteractiveBrokersObservable)
    InteractiveBrokers.reqPositions(client)

    posSubject = Subject(IbKrPosition)
    client.requestPositionsMappings[CallbackPositionsKey(:position)] = CallbackPositionsValue(position, posSubject)
    return posSubject
end

function Lucky.feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:livedata}; timeout=30000) #, callback::Union{Nothing,Function}=nothing, outputType::Type=Any)    
    requestId = nextRequestId(client)
    # TODO callbacks depending on requested data

    lastPriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote))

    bidPriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote))
    askPriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote))
    markPriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote))

    highPriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote))
    lowPriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote))
    openPriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote))
    closePriceSubject = RecentSubject(Lucky.PriceQuote, Subject(Lucky.PriceQuote))

    volumeSubject = RecentSubject(Lucky.VolumeQuote, Subject(Lucky.VolumeQuote))
    askSizeSubject = RecentSubject(Lucky.VolumeQuote, Subject(Lucky.VolumeQuote))
    bidSizeSubject = RecentSubject(Lucky.VolumeQuote, Subject(Lucky.VolumeQuote))
    lastSizeSubject = RecentSubject(Lucky.VolumeQuote, Subject(Lucky.VolumeQuote))

    tickStringSubject = RecentSubject(DateTime, Subject(DateTime))

    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.LAST), CallbackValue(tickPrice, lastPriceSubject, instr))

    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.BID), CallbackValue(tickPrice, bidPriceSubject, instr))
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.ASK), CallbackValue(tickPrice, askPriceSubject, instr))
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.MARK_PRICE), CallbackValue(tickPrice, markPriceSubject, instr))

    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.HIGH), CallbackValue(tickPrice, highPriceSubject, instr))
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.LOW), CallbackValue(tickPrice, lowPriceSubject, instr))
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.OPEN), CallbackValue(tickPrice, openPriceSubject, instr))
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickPrice, InteractiveBrokers.TickTypes.CLOSE), CallbackValue(tickPrice, closePriceSubject, instr))

    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickSize, InteractiveBrokers.TickTypes.VOLUME), CallbackValue(tickSize, volumeSubject, instr))
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickSize, InteractiveBrokers.TickTypes.ASK_SIZE), CallbackValue(tickSize, askSizeSubject, instr))
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickSize, InteractiveBrokers.TickTypes.BID_SIZE), CallbackValue(tickSize, bidSizeSubject, instr))
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickSize, InteractiveBrokers.TickTypes.LAST_SIZE), CallbackValue(tickSize, lastSizeSubject, instr))
    
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickString, InteractiveBrokers.TickTypes.LAST_TIMESTAMP), CallbackValue(tickString, tickStringSubject, instr))
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickGeneric, InteractiveBrokers.TickTypes.LAST), CallbackValue(tickGeneric, nothing, instr))
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :marketDataType, InteractiveBrokers.TickTypes.LAST), CallbackValue(marketDataType, nothing, instr))
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :tickReqParams, InteractiveBrokers.TickTypes.LAST), CallbackValue(tickReqParams, nothing, instr))

    # TODO default subject type depending on callback    
    merge = (tup::Tuple{Lucky.PriceQuote, DateTime}) -> Quote(tup[1].instrument, tup[1].tick, tup[1].price, tup[1].size, tup[2])
    last = lastPriceSubject |> with_latest(tickStringSubject) |> Rocket.map(Lucky.PriceQuote, merge)

    merge_lastSize = (tup::Tuple{Lucky.VolumeQuote, DateTime}) -> Quote(tup[1].instrument, tup[1].tick, tup[1].volume, tup[2])
    lastSize = lastSizeSubject |> with_latest(tickStringSubject) |> Rocket.map(Lucky.VolumeQuote, merge_lastSize)

    output = TickQuoteFeed(
        instr,
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
    Dictionaries.set!(client.mergedCallbacks, Pair(instr, :livedata), output)

    # TODO options
    InteractiveBrokers.reqMktData(client, requestId, instr, "232", false)
    return output
end

function Lucky.end_feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:livedata})
    if haskey(client.mergedCallbacks, Pair(instr, :livedata))
        subject = client.mergedCallbacks[Pair(instr, :livedata)]
        if Rocket.isactive(subject)
            Rocket.complete!(subject)
        end
        Dictionaries.unset!(client.mergedCallbacks, Pair(instr, :livedata))
    end

    ongoingRequests = getRequests(client.requestMappings, [:tickSize,:tickPrice,:tickGeneric,:tickReqParams,:tickString,:marketDataType], instr)
    if !isempty(ongoingRequests)
        requestId = first(keys(ongoingRequests)).requestId
        Lucky.Utils.deletefrom!(client.requestMappings, keys(ongoingRequests))
        InteractiveBrokers.cancelMktData(client, requestId)
    end
    return nothing
end

function Lucky.feed(client, instr::Instrument, ::Val{:historicaldata}; timeout=60000)
    requestId = nextRequestId(client)

    historicalDataSubject = RecentSubject(DataFrame, Subject(DataFrame))
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :historicalData, nothing), CallbackValue(historicalData, historicalDataSubject, instr))
    Dictionaries.set!(client.mergedCallbacks, Pair(instr, :historicaldata), historicalDataSubject)

    setTimeout(timeout) do 
        Lucky.end_feed(client, instr, Val(:historicaldata))
    end

    InteractiveBrokers.reqHistoricalData(client, requestId, instr, "", "3 Y", "1 day", "TRADES" ,false, 1, false)
    return historicalDataSubject
end

function Lucky.end_feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:historicaldata})
    if haskey(client.mergedCallbacks, Pair(instr, :historicaldata))
        subject = client.mergedCallbacks[Pair(instr, :historicaldata)]
        if Rocket.isactive(subject)
            Rocket.complete!(subject)
        end
        Dictionaries.unset!(client.mergedCallbacks, Pair(instr, :historicaldata))
    end
    ongoingRequests = getRequests(client.requestMappings, [:historicalData], instr)
    if !isempty(ongoingRequests)
        requestId = first(keys(ongoingRequests)).requestId
        Lucky.Utils.deletefrom!(client.requestMappings, keys(ongoingRequests))
        InteractiveBrokers.cancelHistoricalData(client, requestId)
    end
end

function Lucky.feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:securityDefinitionOptionalParameter})
    requestId = nextRequestId(client)

    expirationSubject = RecentSubject(Date)
    strikeSubject = RecentSubject(Float64)
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :expirations, nothing), CallbackValue(securityDefinitionOptionalParameter, expirationSubject, instr))
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :strikes, nothing), CallbackValue(securityDefinitionOptionalParameter, strikeSubject, instr))
    Dictionaries.set!(client.mergedCallbacks, Pair(instr, :expirations), expirationSubject)
    Dictionaries.set!(client.mergedCallbacks, Pair(instr, :strikes), strikeSubject)

    setTimeout(30000) do 
        Lucky.end_feed(client, instr, Val(:securityDefinitionOptionalParameter))
    end

    conId = Lucky.feed(client, instr, Val(:contractDetails)) |> Rocket.first()

    subscribe!(conId, lambda(InteractiveBrokers.ContractDetails; on_next=(d)-> InteractiveBrokers.reqSecDefOptParams(client, requestId, instr, "", d.contract.conId)))

    return expirationSubject, strikeSubject
end

function Lucky.end_feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:securityDefinitionOptionalParameter})
    if haskey(client.mergedCallbacks, Pair(instr, :expirations))
        expirationSubject = client.mergedCallbacks[Pair(instr, :expirations)]
        if Rocket.isactive(expirationSubject)
            Rocket.complete!(expirationSubject)
        end
        Dictionaries.unset!(client.mergedCallbacks, Pair(instr, :expirations))
    end

    if haskey(client.mergedCallbacks, Pair(instr, :strikes))
        strikeSubject = client.mergedCallbacks[Pair(instr, :strikes)]
        if Rocket.isactive(strikeSubject)
            Rocket.complete!(strikeSubject)
        end
        Dictionaries.unset!(client.mergedCallbacks, Pair(instr, :strikes))
    end

    ongoingRequests = getRequests(client.requestMappings, [:expirations,:strikes], instr)
    if !isempty(ongoingRequests)
        Lucky.Utils.deletefrom!(client.requestMappings, keys(ongoingRequests))
    end
end

function Lucky.feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:contractDetails})
    requestId = nextRequestId(client)

    contractDetailsSubject = RecentSubject(InteractiveBrokers.ContractDetails, Subject(InteractiveBrokers.ContractDetails))
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :contractDetails, nothing), CallbackValue(contractDetails, contractDetailsSubject, instr))
    Dictionaries.set!(client.mergedCallbacks, Pair(instr, :contractDetails), contractDetailsSubject)

    setTimeout(30000) do 
        Lucky.end_feed(client, instr, Val(:contractDetails))
    end
    InteractiveBrokers.reqContractDetails(client, requestId, instr)
    return contractDetailsSubject
end

function Lucky.end_feed(client::InteractiveBrokersObservable, instr::Instrument, ::Val{:contractDetails})
    if haskey(client.mergedCallbacks, Pair(instr, :contractDetails))
        subject = client.mergedCallbacks[Pair(instr, :contractDetails)]
        if Rocket.isactive(subject)
            Rocket.complete!(subject)
        end
        Dictionaries.unset!(client.mergedCallbacks, Pair(instr, :contractDetails))  
    end
    ongoingRequests = getRequests(client.requestMappings, [:contractDetails], instr)
    if !isempty(ongoingRequests)
        Lucky.Utils.deletefrom!(client.requestMappings, keys(ongoingRequests))
    end
end

function Lucky.feed(client::InteractiveBrokersObservable, ::Val{:accountSummary})
    requestId = nextRequestId(client)

    accountSummarySubject = RecentSubject(Float64)
    Dictionaries.set!(client.requestMappings, CallbackKey(requestId, :accountSummary, nothing), CallbackValue(accountSummary, accountSummarySubject, nothing))
    Dictionaries.set!(client.mergedCallbacks, Pair(nothing, :accountSummary), accountSummarySubject)

    setTimeout(30000) do 
        Lucky.end_feed(client, Val(:accountSummary))
    end

    InteractiveBrokers.reqAccountSummary(client, requestId, "All", "TotalCashValue")
    return accountSummarySubject
end

function Lucky.end_feed(client::InteractiveBrokersObservable, ::Val{:accountSummary})
    if haskey(client.mergedCallbacks, Pair(nothing, :accountSummary))
        subject = client.mergedCallbacks[Pair(nothing, :accountSummary)]
        if Rocket.isactive(subject)
            Rocket.complete!(subject)
        end
        Dictionaries.unset!(client.mergedCallbacks, Pair(nothing, :accountSummary))  
    end
    ongoingRequests = getRequests(client.requestMappings, [:accountSummary])
    if !isempty(ongoingRequests)
        Lucky.Utils.deletefrom!(client.requestMappings, keys(ongoingRequests))
    end
end

function wrapper(client::InteractiveBrokersObservable)
    wrap = InteractiveBrokers.Wrapper(client)

    # Mandatory callbacks
    setproperty!(wrap, :error, error)
    setproperty!(wrap, :managedAccounts, managedAccounts)
    setproperty!(wrap, :nextValidId, nextValidId)
    setproperty!(wrap, :positionEnd, positionEnd)

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
    setproperty!(wrap, :position, position)

    return wrap
end

secType(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement secType(::$(T))")
secType(::T) where {T<:Lucky.Cash} = "CASH"
secType(::T) where {T<:Lucky.Stock} = "STK"
secType(::T) where {T<:Lucky.Option} = "OPT"

conId(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement conId(::$(T))")
conId(::T) where {C,T<:Lucky.Cash{C}} = nothing

exchange(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement exchange(::$(T))")
exchange(::T) where {C,T<:Lucky.Cash{C}} = "IDEALPRO" # TODO: Support Virtual Forex
exchange(::T) where {S,C,T<:Lucky.Stock{S,C}} = "SMART"
exchange(::T) where {S,R,K,E,T<:Lucky.Option{S,R,K,E}} = "SMART"

right(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement right(::$(T))")
right(option::Option) = String(option.right)

strike(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement strike(::$(T))")
strike(option::Option) = option.strike

expiry(::T) where {T<:Lucky.Instrument} = Base.error("You probably forgot to implement expiry(::$(T))")
expiry(option::Option) = Dates.format(option.expiry, "yyyymmdd")

function InteractiveBrokers.Contract(i::Lucky.Instrument)
    return InteractiveBrokers.Contract(
        symbol=symbol(i),
        secType=secType(i),
        exchange=exchange(i),
        currency=Lucky.Units.currency(i)
    )
end

function InteractiveBrokers.Contract(i::Lucky.Option)
    contract = InteractiveBrokers.Contract(
        symbol=symbol(i),
        secType=secType(i),
        exchange=exchange(i),
        currency=Lucky.Units.currency(i)
    )
    contract.right = right(i)
    contract.lastTradeDateOrContractMonth = expiry(i)
    contract.strike = strike(i)
    contract.multiplier = "100"
    return contract
end

end