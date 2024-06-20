export RequestManager

using Lucky
using Rocket

mutable struct RequestManager <: AbstractManager
    conn::Union{Nothing, <:Connection}
    reqIdMaster::Int
    completion_status::BitArray{1}
    requests::Vector{Pair{<:Function, <:Tuple}}
    cancels::Vector{Pair{<:Function, <:Tuple}}
end

function Rocket.on_next!(manager::RequestManager, msg::RegisterRequest)
    push!(manager.requests, msg.request)
    push!(manager.cancels, msg.cancel)
    push!(manager.completion_status, false)

    reqId = manager.reqIdMaster
    queueId = length(manager.completion_status)
    next!(msg.actor, RegisterResponse(reqId, queueId))

    # Call Request
    msg.request.first(manager.conn, reqId, msg.request.second...)
    manager.reqIdMaster += 1
    setTimeout(msg.timeout) do 
        if !manager.completion_status[queueId]
            msg.cancel.first(manager.conn, reqId)
            manager.completion_status[queueId] = true
            next!(msg.actor, IncompleteDataRequest())
        end
    end
end

function Rocket.on_next!(manager::RequestManager, msg::CompleteRequestMsg)
    manager.completion_status[msg.queueId] = true
    manager.cancels[msg.queueId].first(manager.conn, msg.reqId)
end

function Rocket.on_next!(manager::RequestManager, msg::BootStrapSystem)
    empty!(manager.requests)
    empty!(manager.cancels)
    empty!(manager.completion_status)
    manager.reqIdMaster = 1
end

function Rocket.on_next!(manager::RequestManager, msg::ConnectionMsg)
    manager.conn = msg.conn
end
