export Currency, CurrencyType
export symbol, currency

using Lucky.Units

struct Currency{S} <: Unit end

# Constructors
Currency(s::Symbol) = Currency{s}()
Currency(s::AbstractString) = Currency(Symbol(s))

# Interface
CurrencyType(::C) where {C<:Currency} = C
CurrencyType(C::Type{<:Currency}) = C
CurrencyType(s::Symbol) = CurrencyType(Currency{s})
CurrencyType(s::AbstractString) = CurrencyType(Symbol(s))

symbol(::Currency{S}) where {S} = S
currency(::Currency{S}) where {S} = String(S)

Base.show(io::IO, ::Type{Currency{S}}) where {S} = print(io, "$(S)")
Base.String(::Currency{S}) where {S} = String(S)
Base.convert(String, ::C) where {S,C<:Currency{S}} = String(S)