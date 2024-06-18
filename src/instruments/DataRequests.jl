export DataRequest

struct DataRequest{I} <: Instrument end

DataRequest(S::Int) = DataRequest{S}()

import Base: eltype

Base.eltype(::DataRequest{I}) where I = I



