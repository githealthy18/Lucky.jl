module Msg

abstract type ProcessMsg <: AbstractMsg end

struct RegisterRequest{A} <: ProcessMsg
    request::Pair{<:Function, <:Tuple}
    cancel::Pair{<:Function, <:Tuple}
    timeout::Int
    actor::A
end

registerRequestSubject = Subject(RegisterRequest)

struct RegisterResponse <: ProcessMsg
    reqId::Int
    queueId::Int
end

struct BootStrapSystem <: ProcessMsg end

bootStrapSubject = Subject(BootStrapSystem)

struct IncompleteDataRequest <: ProcessMsg end

struct CompleteQuoteMsg{B} <: ProcessMsg
    body::B
end

struct CompleteRequestMsg <: ProcessMsg
    reqId::Int
    queueId::Int
end

completedRequests = Subject(CompleteRequestMsg)

end