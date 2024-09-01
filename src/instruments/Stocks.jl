export Stock

using AutoHashEquals

@auto_hash_equals cache=true struct Stock{S,C<:Currency} <: Instrument 
    symbol::S
    currency::C
end

Stock(symbol::Symbol, currency::Union{AbstractString, Symbol}) = Stock(symbol, Currency(currency))

symbol(stock::T) where {S,C,T<:Stock{S,C}} = String(stock.symbol)
currency(stock::Stock{S,C}) where {S,C} = String(stock.currency)