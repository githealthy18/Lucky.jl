module Instruments

export Instrument, InstrumentType
import Lucky.Units as Units

using Lucky.Constants

using Dates

abstract type Instrument end

# InstrumentType(I::Type{<:Instrument}, params...) = error("You probably forgot to implement InstrumentType($(I), $(params...))")
InstrumentType(::I) where {I<:Instrument} = I

Units.currency(I::Type{<:Instrument}) = error("You probably forgot to implement currency(::$(I)")
Units.currency(i::I) where {I<:Instrument} = error("You probably forgot to implement currency(::$(I)")

symbol(::T) where {T<:Instrument} = Base.error("You probably forgot to implement symbol(::$(T))")

include("instruments/Cash.jl")
include("instruments/Stocks.jl")
include("instruments/Options.jl")

end