export Option

mutable struct Greeks
    impliedVolatility::Float64
    delta::Float64
    gamma::Float64
    vega::Float64
    theta::Float64
    rho::Float64
end

setImpliedVolatility!(g::Greeks, impliedVolatility::Float64) = (g.impliedVolatility = impliedVolatility; g)
setDelta!(g::Greeks, delta::Float64) = (g.delta = delta; g)
setGamma!(g::Greeks, gamma::Float64) = (g.gamma = gamma; g)
setVega!(g::Greeks, vega::Float64) = (g.vega = vega; g)
setTheta!(g::Greeks, theta::Float64) = (g.theta = theta; g)
setRho!(g::Greeks, rho::Float64) = (g.rho = rho; g)


struct Option{S<:Stock,R,K,E} <: Instrument 
    underlying::S
    right::R
    strike::K
    expiry::E
    greeks::Greeks
end


Option(stock::Stock, right::OPTION_RIGHT, strike::Float64, expiry::Dates.Date) = Option(stock, right, strike, expiry, Greeks(NaN, NaN, NaN, NaN, NaN, NaN))

Units.symbol(option::Option) = Units.symbol(option.underlying)

Units.currency(option::Option) = Units.currency(option.underlying)
