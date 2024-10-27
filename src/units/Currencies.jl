export Currency
export symbol, currency
export CurrencyType

"""
    Currency

A Currency is type of Unit.
It should not be confused with Cash, which represents the amount of a certain Currency.

Currencies are implemented as a singelton.

# Examples

```jldoctest
c = Currency(:USD)

# output

USD()
```

See also: [`Unit`](@ref units)
"""
struct Currency{S} <: Unit end

Currency(s::Symbol) = Currency{s}()
Currency(s::AbstractString) = Currency(Symbol(s))

# Interfaces

Base.convert(::String, ::C) where {S,C<:Currency{S}} = String(S)

CurrencyType(C::Type{<:Currency}) = C
CurrencyType(s::Symbol) = CurrencyType(Currency{s})
CurrencyType(s::AbstractString) = CurrencyType(Symbol(s))

symbol(::Currency{S}) where {S} = S
symbol(::Type{Currency{S}}) where {S} = S 
currency(::Currency{S}) where {S} = String(S)

Base.show(io::IO, ::Type{Currency{S}}) where {S} = print(io, "$(S)")
Base.String(::Currency{S}) where {S} = String(S)

"""
    currency

    Returns the currency of the object.    
"""
currency(o::Any) = error("You probably forgot to implement currency(::$(o)")
currency(::Type{C}) where {C<:Currency} = C