export Option

struct Option{S,R,K,E} <: Instrument end


Option(S::Stock, R::OPTION_RIGHT, K::Float64, E::Dates.Date) = Option{InstrumentType(S),R,K,E}()

Units.currency(::Option{I,R,K,E}) where {S,C,R,K,E,I<:Stock{S,C}} = Units.CurrencyType(C)