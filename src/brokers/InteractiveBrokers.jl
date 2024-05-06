module InteractiveBrokers

export IBAccount, IB, connectSubject, disconnectSubject, ConnectMsg, DisconnectMsg

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
end

IB() = IB(nothing, false)

struct ConnectMsg
    port::Int
end

ConnectMsg() = ConnectMsg(7497)

struct DisconnectMsg end

connectSubject = Subject(ConnectMsg)
disconnectSubject = Subject(DisconnectMsg)

function Rocket.on_next!(actor::IB, msg::ConnectMsg)
    if !actor.isactive
        try
            ib = Jib.connect(msg.port, 1)
        catch e
            println(e)
        else
            actor.conn = ib
            actor.isactive = true
        end
    end
end

function Rocket.on_next!(actor::IB, msg::DisconnectMsg)
    if actor.isactive
        try
            Jib.disconnect(actor.conn)
        catch e
            println(e)
        else
            actor.conn = nothing
            actor.isactive = false
        end
    end
end
end