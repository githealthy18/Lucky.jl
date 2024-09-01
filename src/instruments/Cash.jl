export Cash

# TODO Improvement: have Cash made a singleton
struct Cash{C} <: Instrument end

@inline Cash(C::Symbol) = Cash{Units.Currency{C}}()
@inline Cash(s::String) = Cash(Symbol(s))

currency(::Cash{C}) where {C<:Units.Currency} = C
currency(::Type{Cash{C}}) where {C<:Units.Currency} = C

symbol(::T) where {C,T<:Cash{C}} = String(C)