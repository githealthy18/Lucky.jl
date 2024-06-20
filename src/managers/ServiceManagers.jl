export ServiceManager

using Rocket
using Lucky.ProcessMsgs: BootStrapSystem

mutable struct ServiceManager{A} <: AbstractManager
    service::A
    subscription::Union{Nothing, <:Rocket.Teardown}
    connection_sub::Union{Nothing, <:Rocket.Subject}
end

function Rocket.on_next!(manager::ServiceManager, msg::BootStrapSystem)
    subscription = subscribe!(manager.service, logger("ServiceManager"))
    manager.subscription = subscription
    next!(manager.connection_sub, ConnectionMsg(subscription.wrapper.connection))
end

