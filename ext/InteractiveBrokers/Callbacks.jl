using Lucky.Quotes: Last, Bid, Ask, Mark, High, Low, Close, Open, Volume, AskSize, BidSize, LastSize
const MAPPED_TICKS = Dictionary(
    [
        InteractiveBrokers.TickTypes.LAST,
        InteractiveBrokers.TickTypes.BID,
        InteractiveBrokers.TickTypes.ASK,
        InteractiveBrokers.TickTypes.MARK_PRICE,
        InteractiveBrokers.TickTypes.HIGH,
        InteractiveBrokers.TickTypes.LOW,
        InteractiveBrokers.TickTypes.CLOSE,
        InteractiveBrokers.TickTypes.OPEN,
        InteractiveBrokers.TickTypes.VOLUME,
        InteractiveBrokers.TickTypes.ASK_SIZE,
        InteractiveBrokers.TickTypes.BID_SIZE,
        InteractiveBrokers.TickTypes.LAST_SIZE
    ],
    [
        Last,
        Bid,
        Ask,
        Mark,
        High,
        Low,
        Close,
        Open,
        Volume,
        AskSize,
        BidSize,
        LastSize
    ]
)

function dispatch(field::InteractiveBrokers.TickTypes.TICK_TYPES)
    MAPPED_TICKS[field]()
end

function error(ib::InteractiveBrokersObservable, err::InteractiveBrokers.IbkrErrorMessage)
    if (err.id == -1)
        @info "Skipped Message: $(err)"
        return
    end

    if (err.errorCode == 200) # No security definition has been found for the request
        try
            requestMappings = getRequestsById(ib.requestMappings, err.id)
            if !isempty(requestMappings)
                instr = last(first(requestMappings)).instrument
                callbacks = getCallbacksByInstrument(ib.mergedCallbacks, instr)
                for (k,_) in pairs(callbacks)
                    Lucky.end_feed(ib, instr, Val(k.second))
                end
            end
        catch e
            @warn e
        end
    end
    #Rocket.error!(ib, err)
end

function managedAccounts(ib::InteractiveBrokersObservable, accountsList::String)
    accounts = split(accountsList, ",")
    filter!(x -> !isempty(x), accounts)
    # TODO Dispatch
    println("Accounts: $(accounts)")
end

function nextValidId(ib::InteractiveBrokersObservable, orderId::Int)
    ib.nextValidId = orderId 
end

function tickGeneric(ib::InteractiveBrokersObservable, tickerId::Int, tickType::InteractiveBrokers.TickTypes.TICK_TYPES, value::Float64)
    # ex data: 1 DELAYED_LAST 1.0
    key = CallbackKey(tickerId, :tickGeneric, tickType)
    if haskey(ib.requestMappings, key)
        val = ib.requestMappings[key]
    end
end

function marketDataType(ib::InteractiveBrokersObservable, reqId::Int, marketDataType::InteractiveBrokers.MarketDataType)
    key = CallbackKey(reqId, :marketDataType, InteractiveBrokers.TickTypes.LAST)
    if haskey(ib.requestMappings, key)
        val = ib.requestMappings[key]
    end
end

function tickReqParams(ib::InteractiveBrokersObservable, tickerId::Int, minTick::Union{Nothing, Float64}, bboExchange::String, snapshotPermissions::Int)
    key = CallbackKey(tickerId, :tickReqParams, InteractiveBrokers.TickTypes.LAST)
    if haskey(ib.requestMappings, key)
        val = ib.requestMappings[key]
    end
end

function tickPrice(ib::InteractiveBrokersObservable, tickerId::Int, field::InteractiveBrokers.TickTypes.TICK_TYPES, price::Union{Float64,Nothing}, size::Union{Float64,Nothing}, attrib::InteractiveBrokers.TickAttrib)
    # TODO use attrib
    # ex data: 1 DELAYED_BID -1.0
    key = CallbackKey(tickerId, :tickPrice, field)
    if haskey(ib.requestMappings, key)
        val = ib.requestMappings[key]
        qte = Lucky.Quote(val.instrument, dispatch(field), price, size, Dates.now())
        try
            next!(val.subject, qte)
        catch E
        end
    end
end

function tickSize(ib::InteractiveBrokersObservable, tickerId::Int, field::InteractiveBrokers.TickTypes.TICK_TYPES, size::Float64)
    #TODO Use & dispatch
    key = CallbackKey(tickerId, :tickSize, field)
    if haskey(ib.requestMappings, key)
        val = ib.requestMappings[key]
        mult = field == InteractiveBrokers.TickTypes.VOLUME ? 100 : 1
        qte = Lucky.VolumeQuote(val.instrument, dispatch(field), size*mult, Dates.now())
        next!(val.subject, qte)
    end
end

function tickString(ib::InteractiveBrokersObservable, tickerId::Int, tickType::InteractiveBrokers.TickTypes.TICK_TYPES, value::String)
    # ex data: 1 DELAYED_LAST_TIMESTAMP 1718409598
    key = CallbackKey(tickerId, :tickString, tickType)
    if haskey(ib.requestMappings, key)
        val = ib.requestMappings[key]
        # TODO Handle timezones
        next!(val.subject, unix2datetime(parse(Int64, value)))
    end
end

function historicalData(ib::InteractiveBrokersObservable, reqId::Int, bar::DataFrame)
    key = CallbackKey(reqId, :historicalData, nothing)
    if haskey(ib.requestMappings, key)
        val = ib.requestMappings[key]
        next!(val.subject, bar)
    end
end

function accountSummary(ib::InteractiveBrokersObservable, reqId::Int, account::String, tag::String, value::String, currency::String)
    key = CallbackKey(reqId, :accountSummary, nothing)
    @info haskey(ib.requestMappings, key)
    @info ib.requestMappings
    if haskey(ib.requestMappings, key)
        @info "Account Summary"
        val = ib.requestMappings[key]
        if tag == "TotalCashValue"
            next!(val.subject, parse(Float64, value))
        end
    end
end

function tickOptionComputation(ib::InteractiveBrokersObservable, reqId::Int, tickType::InteractiveBrokers.TickTypes.TICK_TYPES, tickAttrib::Int, impliedVol::Union{Float64,Nothing}, delta::Union{Float64,Nothing}, optPrice::Union{Float64,Nothing}, pvDividend::Union{Float64,Nothing}, gamma::Union{Float64,Nothing}, vega::Union{Float64,Nothing}, theta::Union{Float64,Nothing}, undPrice::Union{Float64,Nothing}) end

function securityDefinitionOptionalParameter(ib::InteractiveBrokersObservable, reqId::Int, exchange::String, underlyingConId::Int, tradingClass::String, multiplier::String, expirations::Vector{String}, strikes::Vector{Float64})
    exp_key = CallbackKey(reqId, :expirations, nothing)
    strike_key = CallbackKey(reqId, :strikes, nothing)
    if (haskey(ib.requestMappings, exp_key) && haskey(ib.requestMappings, strike_key))
        exp_val = ib.requestMappings[exp_key]
        strike_val = ib.requestMappings[strike_key]
        for exp in sort!(Date.(expirations, "yyyymmdd"))
            next!(exp_val.subject, exp)
            for str in strikes
                next!(strike_val.subject, str)
            end
        end
    end
end

function contractDetails(ib::InteractiveBrokersObservable, reqId::Int, contractDetails::InteractiveBrokers.ContractDetails)
    key = CallbackKey(reqId, :contractDetails, nothing)
    if haskey(ib.requestMappings, key)
        val = ib.requestMappings[key]
        next!(val.subject, contractDetails)
    end
end