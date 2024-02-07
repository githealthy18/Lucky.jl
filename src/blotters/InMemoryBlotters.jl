module InMemoryBlotters

export InMemoryBlotter

using Lucky.Blotters
using Lucky.Fills

using Rocket

struct InMemoryBlotter <: AbstractBlotter
    fills::Vector{Fill} # TODO Optimize
    next::AbstractSubject
end
@inline InMemoryBlotter(subject::Subject) = InMemoryBlotter(Vector{Fill}(), subject)

function Rocket.on_next!(actor::InMemoryBlotter, fill::Fill)
    push!(actor.fills, fill)
    aggSize = mapreduce(x -> x.instrument == fill.instrument ? fill.size : zero(Float64), +, actor.fills)
    position = Position(fill.instrument, aggSize)
    next!(actor.next, position)
end

Rocket.on_error!(actor::InMemoryBlotter, error) = error!(actor.next, error)
Rocket.on_complete!(actor::InMemoryBlotter) = complete!(actor.next)

end