struct ASK <: AbstractTick end
struct BID <: AbstractTick end
struct LAST <: AbstractTick end
struct HIGH <: AbstractTick end
struct LOW <: AbstractTick end
struct OPEN <: AbstractTick end
struct CLOSE <: AbstractTick end
struct VOLUME <: AbstractTick end

function dispatch(tag)
    return Dict("ASK" => ASK, "BID" => BID, "LAST" => LAST, "HIGH" => HIGH, "LOW" => LOW, "OPEN" => OPEN, "CLOSE" => CLOSE, "VOLUME" => VOLUME)[tag]()
end

function error(ib::InteractiveBrokersObservable, err::InteractiveBrokers.IbkrErrorMessage)
    if (err.id == -1)
        @info "Skipped Message: $(err)"
        return
    end

    println("error! $(err)")
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

function tickGeneric(ib::InteractiveBrokersObservable, tickerId::Int, tickType::String, value::Float64)
    # ex data: 1 DELAYED_LAST 1.0
    mapping = ib.requestMappings[Pair(tickerId, :tickGeneric)]
    println("tickGeneric: $(mapping[3]) $tickType $value")
end

function marketDataType(ib::InteractiveBrokersObservable, reqId::Int, marketDataType::InteractiveBrokers.MarketDataType)
    mapping = ib.requestMappings[Pair(reqId, :marketDataType)]
    println("MarketDataType: $(mapping[3]) $marketDataType")
end

function tickReqParams(ib::InteractiveBrokersObservable, tickerId::Int, minTick::Float64, bboExchange::String, snapshotPermissions::Int)
    mapping = ib.requestMappings[Pair(tickerId, :tickReqParams)]
    println("tickReqParams: $(mapping[3]) $minTick $bboExchange $snapshotPermissions")
end

function tickPrice(ib::InteractiveBrokersObservable, tickerId::Int, field::String, price::Union{Float64,Nothing}, size::Union{Float64,Nothing}, attrib::InteractiveBrokers.TickAttrib)
    # TODO use attrib
    # ex data: 1 DELAYED_BID -1.0
    mapping = ib.requestMappings[Pair(tickerId, :tickPrice)]
    qte = Lucky.PriceQuote(mapping[3], dispatch(field), price, size, nothing)
    next!(mapping[2], qte)
end

function tickSize(ib::InteractiveBrokersObservable, tickerId::Int, field::String, size::Float64)
    #TODO Use & dispatch
    if occursin("VOLUME", field)
        mapping = ib.requestMappings[Pair(tickerId, :tickSize)]
        qte = Lucky.VolumeQuote(mapping[3], size*100, nothing)
        next!(mapping[2], qte)
        return
    end
end

function tickString(ib::InteractiveBrokersObservable, tickerId::Int, tickType::String, value::String)
    # ex data: 1 DELAYED_LAST_TIMESTAMP 1718409598
    mapping = ib.requestMappings[Pair(tickerId, :tickString)]
    if occursin("LAST_TIMESTAMP", tickType)
        next!(mapping[2], unix2datetime(parse(Int64,value))) # TODO Handle timezones
    end
end

function historicalData(ib::InteractiveBrokersObservable, reqId::Int, bar::DataFrame)
    mapping = ib.requestMappings[Pair(reqId, :historicalData)]
    next!(mapping[2], bar)
end

function accountSummary(ib::InteractiveBrokersObservable, reqId::Int, account::String, tag::String, value::String, currency::String)
    if tag == "TotalCashValue"
        value = parse(Float64, value)
        mapping = ib.requestMappings[Pair(reqId, :accountSummary)]
        next!(mapping[2], value)
    end
end

function tickOptionComputation end

function securityDefinitionOptionalParameter(ib::InteractiveBrokersObservable, reqId::Int, exchange::String, underlyingConId::Int, tradingClass::String, multiplier::String, expirations::Vector{String}, strikes::Vector{Float64})
    exp_mapping = ib.requestMappings[Pair(reqId, :expirations)]
    strike_mapping = ib.requestMappings[Pair(reqId, :strikes)]
    for exp in sort!(Date.(expirations, "yyyymmdd"))
        next!(exp_mapping[2], exp)
        for str in strikes
            next!(strike_mapping[2], str)
        end
    end
end

function contractDetails(ib::InteractiveBrokersObservable, reqId::Int, contractDetails::InteractiveBrokers.ContractDetails)
    println("contractDetails: $(contractDetails)")
end
# function secDefOptParams(ib::InteractiveBrokersObservable, reqId::Int,  end