export Option

struct Greeks
    impliedVolatility::Float64
    delta::Float64
    gamma::Float64
    vega::Float64
    theta::Float64
    rho::Float64
end


struct Option{S<:Stock,R,K,E} <: Instrument 
    underlying::S
    right::R
    strike::K
    expiry::E
    greeks::Greeks
end


Option(stock::Stock, right::OPTION_RIGHT, strike::Float64, expiry::Dates.Date) = Option(stock, right, strike, expiry, Greeks(NaN, NaN, NaN, NaN, NaN, NaN))

Units.symbol(option::Option) = symbol(option.underlying)

Units.currency(option::Option) = Units.currency(option.underlying)
