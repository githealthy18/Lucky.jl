export Cash, symbol

# TODO Improvement: have Cash made a singleton
struct Cash{C} <: Instrument end

@inline Cash(C::Symbol) = Cash{Units.Currency{C}}()
@inline Cash(s::String) = Cash(Symbol(s))

symbol(::T) where {C,T<:Cash{C}} = String(C)

import Lucky.Units as Units
Units.currency(::Cash{C}) where {C<:Units.Currency} = C
Units.currency(::Type{Cash{C}}) where {C<:Units.Currency} = C