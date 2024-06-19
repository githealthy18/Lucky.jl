module Connections

export Connection, ConnectionType

abstract type Connection end

ConnectionType(C::Type{<:Connection}, params...) = error("You probably forgot to implement InstrumentType($(C), $(params...))")
ConnectionType(::C) where {C<:Connection} = C

end