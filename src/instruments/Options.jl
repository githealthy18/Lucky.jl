export Option
export setImpliedVolatility!, setDelta!, setGamma!, setVega!, setTheta!, setRho!
using AutoHashEquals

@auto_hash_equals fields=(impliedVolatility, delta, gamma, vega, theta, rho) mutable struct Greeks
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

@auto_hash_equals cache=true fields=(underlying,right,strike,expiry) struct Option{S<:Stock,R,K,E} <: Instrument 
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

currency(option::Option) = currency(option.underlying)

import Base: Symbol
Symbol(option::O) where {O<:Option} = Symbol(option.underlying)