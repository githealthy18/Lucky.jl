export Option

struct Option{S,R,E} <: Instrument end


Option(S::Stock, R::OPTION_RIGHT, E::Dates.Date) = Option{InstrumentType(S),R,E}()

Units.currency(::Option{I,R,E}) where {S,C,R,E,I<:Stock{S,C}} = Units.CurrencyType(C)