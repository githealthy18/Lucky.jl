export Option

struct Option{S,R,E} <: Instrument end

Option(S::Stock, R::OPTION_RIGHT, E::Dates.DateTime) = Option{InstrumentType(S),R,Int(floor(datetime2unix(E)))}()
Option(S::Stock, R::OPTION_RIGHT, E::Dates.Date) = Option{S,R,E}()

Units.currency(::Option{I,R,E}) where {S,C,R,E,I<:Stock{S,C}} = Units.CurrencyType(C)