export Option

struct Option{S,C} <: Instrument end

Option(S::Symbol, C::Type{<:Units.Currency}) = Option{S,C}()
Option(S::Symbol, C::Union{Symbol, AbstractString}) = Option{S,Units.CurrencyType(C)}()

Units.currency(s::Option{S,C}) where {S,C} = Units.CurrencyType(C)