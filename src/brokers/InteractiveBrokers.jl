module InteractiveBrokers

export IBAccount, IB

using Lucky.Brokers
using Rocket
using Dates
using UUIDs
using Jib

struct IBAccount <: AbstractAccount
    id::String
    account::String
    tag::String
    value::String
    currency::String
end

struct IB <: AbstractBroker
    conn::Union{Jib.Connection, Nothing}
    isactive::Bool
    req_id::Int
    next::AbstractSubject
end

ConnectMsg() = ConnectMsg(7497)

IB() = IB(nothing, false, 0, connections)

function Rocket.on_next!(broker::IB, msg::ConnectMsg)
    if !broker.isactive
        try
            ib = Jib.connect(msg.port, 1)
        catch e
            println(e)
        else
            broker.conn = ib
            broker.isactive = true
            next!(broker.next, Connection(broker.conn))
        end
    end
end

function Rocket.on_next!(broker::IB, msg::DisconnectMsg)
    if broker.isactive
        try
            Jib.disconnect(broker.conn)
        catch e
            println(e)
        else
            broker.conn = nothing
            broker.isactive = false
        end
    end
end
end