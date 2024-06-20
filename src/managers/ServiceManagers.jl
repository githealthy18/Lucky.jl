export ServiceManager

using Rocket
using Lucky.ProcessMsgs: BootStrapSystem
using Lucky.Constants: CONNECTION_SUB

mutable struct ServiceManager{A, S} <: AbstractManager
    service::A
    subscription::S
    connection_sub::Union{Nothing, <:Rocket.Subject}
end

function Rocket.on_next!(manager::ServiceManager, msg::BootStrapSystem)
    subscription = subscribe!(manager.service, logger("ServiceManager"))
    manager.subscription = subscription
    next!(manager.connection_sub, ConnectionMsg(subscription.connection))
end

