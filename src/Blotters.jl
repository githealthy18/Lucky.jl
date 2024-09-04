export blotter, positions, fills

function blotter end

@inline blotter(s::Symbol, params...) = blotter(Val(s), params...)

abstract type AbstractBlotter <: Actor{Any} end

function positions end

function fills end