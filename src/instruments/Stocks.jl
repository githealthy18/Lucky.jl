export Stock

struct Stock{S,C} <: Instrument end

Stock(S::Symbol, C::Type{<:Units.Currency}) = Stock{S,C}()
Stock(S::Symbol, C::Union{Symbol, AbstractString}) = Stock{S,Units.CurrencyType(C)}()

symbol(::T) where {S,C,T<:Lucky.Stock{S,C}} = String(S)
symbol(::Type{<:Lucky.Stock{S,C}}) where {S,C} = String(S)

Units.currency(::Stock{S,C}) where {S,C} = Units.CurrencyType(C)