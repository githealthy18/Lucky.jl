export Option

mutable struct Greeks
    impliedVolatility::Float64
    delta::Float64
    gamma::Float64
    vega::Float64
    theta::Float64
    rho::Float64
end

setImpliedVolatility!(g::Greeks, impliedVolatility::Float64) = g.impliedVolatility = impliedVolatility
setDelta!(g::Greeks, delta::Float64) = g.delta = delta
setGamma!(g::Greeks, gamma::Float64) = g.gamma = gamma
setVega!(g::Greeks, vega::Float64) = g.vega = vega
setTheta!(g::Greeks, theta::Float64) = g.theta = theta
setRho!(g::Greeks, rho::Float64) = g.rho = rho

struct Option{S<:Stock,R,K,E} <: Instrument 
    underlying::S
    right::R
    strike::K
    expiry::E
    greeks::Greeks
end

setImpliedVolatility!(o::Option, impliedVolatility::Float64) = setImpliedVolatility!(o.greeks, impliedVolatility)
setDelta!(o::Option, delta::Float64) = setDelta!(o.greeks, delta)
setGamma!(o::Option, gamma::Float64) = setGamma!(o.greeks, gamma)
setVega!(o::Option, vega::Float64) = setVega!(o.greeks, vega)
setTheta!(o::Option, theta::Float64) = setTheta!(o.greeks, theta)
setRho!(o::Option, rho::Float64) = setRho!(o.greeks, rho)


Option(stock::Stock, right::OPTION_RIGHT, strike::Float64, expiry::Dates.Date) = Option(stock, right, strike, expiry, Greeks(NaN, NaN, NaN, NaN, NaN, NaN))

Units.symbol(option::Option) = Units.symbol(option.underlying)

Units.currency(option::Option) = Units.currency(option.underlying)

Base.:(==)(a::Option, b::Option) = a.underlying == b.underlying && a.right == b.right && a.strike == b.strike && a.expiry == b.expiry
Base.hash(a::Option) = UInt(1)
