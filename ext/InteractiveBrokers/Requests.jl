
@inline function delayedReq(fn::Function, ib::InteractiveBrokersObservable)
    if isnothing(ib.connection)
        pushfirst!(ib.pendingCmds, fn)
        return nothing
    end
    fn(ib.connection)
    return nothing
end

function InteractiveBrokers.reqMktData(ib::InteractiveBrokersObservable, reqId::Int, instr::Instrument, genericTicks::String, snapshot::Bool, regulatorySnaphsot::Bool=false, mktDataOptions::NamedTuple=(;))
    f = (connection) -> begin
        InteractiveBrokers.reqMktData(connection, reqId, InteractiveBrokers.Contract(instr), genericTicks, snapshot, regulatorySnaphsot, mktDataOptions)
        setTimeout(5000) do 
            @info "Timeout: Ending feed for $(instr)"
            Lucky.end_feed(ib, instr, Val(:livedata))
            @info "Timeout: Feed Over"
        end
    end
    delayedReq(f, ib)
end

function InteractiveBrokers.cancelMktData(ib::InteractiveBrokersObservable, reqId::Int)
    f = (connection) -> InteractiveBrokers.cancelMktData(connection, reqId)
    delayedReq(f, ib)
end

function InteractiveBrokers.reqHistoricalData(ib::InteractiveBrokersObservable, reqId::Int, instr::Instrument, endDateTime::String, durationStr::String, barSizeSetting::String, whatToShow::String, useRTH::Bool, formatDate::Int, keepUpToDate::Bool, chartOptions::NamedTuple=(;))
    f = (connection) -> InteractiveBrokers.reqHistoricalData(connection, reqId, InteractiveBrokers.Contract(instr), endDateTime, durationStr, barSizeSetting, whatToShow, useRTH, formatDate, keepUpToDate, chartOptions)
    delayedReq(f, ib)
end

function InteractiveBrokers.cancelHistoricalData(ib::InteractiveBrokersObservable, reqId::Int)
    f = (connection) -> InteractiveBrokers.cancelHistoricalData(connection, reqId)
    delayedReq(f, ib)
end

function InteractiveBrokers.reqMarketDataType(ib::InteractiveBrokersObservable, t::InteractiveBrokers.MarketDataType)
    f = (connection) -> InteractiveBrokers.reqMarketDataType(connection, t)
    delayedReq(f, ib)
end

function InteractiveBrokers.reqAccountSummary(ib::InteractiveBrokersObservable, reqId::Int, group::String, tags::String)
    f = (connection) -> InteractiveBrokers.reqAccountSummary(connection, reqId, group, tags)
    delayedReq(f, ib)
end

function InteractiveBrokers.cancelAccountSummary(ib::InteractiveBrokersObservable, reqId::Int)
    f = (connection) -> InteractiveBrokers.cancelAccountSummary(connection, reqId)
    delayedReq(f, ib)
end

function InteractiveBrokers.reqSecDefOptParams(ib::InteractiveBrokersObservable, reqId::Int, instr::Instrument, futFopExchange::String, conId::Int)
    f = (connection) -> InteractiveBrokers.reqSecDefOptParams(connection, reqId, symbol(instr), futFopExchange, secType(instr), conId)
    delayedReq(f, ib)
end

function InteractiveBrokers.reqContractDetails(ib::InteractiveBrokersObservable, reqId::Int, instr::Instrument)
    f = (connection) -> InteractiveBrokers.reqContractDetails(connection, reqId, InteractiveBrokers.Contract(instr))
    delayedReq(f, ib)
end

function InteractiveBrokers.reqIds(ib::InteractiveBrokersObservable)
    f = (connection) -> InteractiveBrokers.reqIds(connection)
    delayedReq(f, ib)
end