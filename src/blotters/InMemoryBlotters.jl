export InMemoryBlotter

struct InMemoryBlotter <: AbstractBlotter
    fills::Dictionary{Instrument, Vector{Fill}} # TODO Optimize
    next::AbstractSubject
end
@inline InMemoryBlotter(subject::Subject) = InMemoryBlotter(Dict{Instrument, Vector{Fill}}(), subject)

blotter(::Val{:inmemory}, subject::Subject) = InMemoryBlotter(subject)

function Rocket.on_next!(actor::InMemoryBlotter, fill::Fill)
    key = fill.order.instrument
    if !haskey(actor.fills, key)
        insert!(actor.fills, key, Vector{Fill}())
    end
    push!(actor.fills[key], fill)
    aggSize = sum(f -> Int(f.order.side)*f.size, actor.fills[key])
    position = Position(fill.order.instrument, aggSize, fill.timestamp)
    next!(actor.next, position)
end

Rocket.on_error!(actor::InMemoryBlotter, error) = error!(actor.next, error)
Rocket.on_complete!(actor::InMemoryBlotter) = complete!(actor.next)