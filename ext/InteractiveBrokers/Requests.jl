mutable struct ReqIdMaster
    id::Int
    ReqIdMaster() = new(0)
end

(r::ReqIdMaster)() = (r.id += 1)

@inline function delayedReq(fn::Function, ib::InteractiveBrokersObservable)
    if isnothing(ib.connection)
        pushfirst!(ib.pendingCmds, fn)
        return nothing
    end
    fn(ib.connection)
    return nothing
end

function InteractiveBrokers.reqMktData(ib::InteractiveBrokersObservable, reqId::Int, instr::Instrument, genericTicks::String, snapshot::Bool, regulatorySnaphsot::Bool=false, mktDataOptions::NamedTuple=(;))
    f = (connection) -> InteractiveBrokers.reqMktData(connection, reqId, InteractiveBrokers.Contract(instr), genericTicks, snapshot, regulatorySnaphsot, mktDataOptions)
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

function InteractiveBrokers.reqIds(ib::InteractiveBrokersObservable)
    f = (connection) -> InteractiveBrokers.reqIds(connection)
    delayedReq(f, ib)
end