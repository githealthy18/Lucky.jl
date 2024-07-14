export Stock

struct Stock{S,C<:Units.Currency} <: Instrument 
    symbol::S
    currency::C
end

Stock(symbol::Symbol, currency::Union{AbstractString, Symbol}) = Stock(symbol, Units.Currency(currency))

Units.symbol(stock::T) where {S,C,T<:Stock{S,C}} = String(stock.symbol)
Units.currency(stock::Stock{S,C}) where {S,C} = String(stock.currency)