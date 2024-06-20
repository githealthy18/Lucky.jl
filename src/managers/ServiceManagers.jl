export ServiceManager

using Rocket
using Lucky.ProcessMsgs: BootStrapSystem
using Lucky.Constants: CONNECTION_SUB

mutable struct ServiceManager{A, S} <: AbstractManager
    service::A
    subscription::S
end

function Rocket.on_next!(manager::ServiceManager, msg::BootStrapSystem)
    subscription = subscribe!(manager.service, logger("ServiceManager"))
    manager.subscription = subscription
    next!(CONNECTION_SUB, ConnectionMsg(subscription.connection))
end

