export Option

struct Option{S,C,R,E} <: Instrument end

Option(S::Stock, C::Type{<:Units.Currency}, R::ORDER_SIDE, E::Dates.Date) = Stock{S,C,R,E}()
Option(S::Stock, C::Union{Symbol, AbstractString}, R::ORDER_SIDE, E::Dates.Date) = Stock{S,Units.CurrencyType(C),R,E}()

Units.currency(::Option{S,C,R,E}) where {S,C,R,E} = Units.CurrencyType(C)