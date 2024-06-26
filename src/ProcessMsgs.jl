module ProcessMsgs

export ProcessMsg, RegisterRequest, RegisterResponse, BootStrapSystem, IncompleteDataRequest, CompleteQuoteMsg, CompleteRequestMsg, ConnectionMsg
export BuildPipelineMsg

using Lucky.Connections
using Lucky.Constants

abstract type ProcessMsg end

struct RegisterRequest{A} <: ProcessMsg
    request::Pair{<:Function, <:Tuple}
    cancel::Pair{<:Function, <:Tuple}
    timeout::Int
    actor::A
end

struct RegisterResponse <: ProcessMsg
    reqId::Int
    queueId::Int
end

struct BootStrapSystem <: ProcessMsg end

struct IncompleteDataRequest <: ProcessMsg end

struct CompleteQuoteMsg{B} <: ProcessMsg
    body::B
end

struct CompleteRequestMsg <: ProcessMsg
    reqId::Int
    queueId::Int
end

struct ConnectionMsg{C<:Connection} <: ProcessMsg
    wrapper::C
end

struct BuildPipelineMsg <: ProcessMsg
    stage::ENVIRONMENT
end

end