module Services

export service

using Lucky.Managers
using Lucky.ProcessMsgs: BootStrapSystem
using Lucky.Constants: CONNECTION_SUB

@inline service(s::Symbol) = service(Val(s))
service(::Val{T}) where {T} = error("You probably forgot to implement service(::Val{$(T)})")

mutable struct ServiceManager{A, S} <: AbstractManager
    service::A
    subscription::S
end

function Rocket.on_next!(manager::ServiceManager, msg::BootStrapSystem)
    subscription = subscribe!(manager.service, logger("ServiceManager"))
    manager.subscription = subscription
    next!(CONNECTION_SUB, ConnectionMsg(subscription.connection))
end


end