module Requesters

export RequestActor

mutable struct RequestActor{R, A} <: Actor{Any}
    tickerId::Int
    queueId::Int
    subscription::Union{Nothing, Rocket.SubjectSubscription}
    requestManager::R
    main::A
end

function Rocket.on_next!(actor::RequestActor, msg::RegisterResponse)
    actor.tickerId = msg.reqId
    actor.queueId = msg.queueId
end

end