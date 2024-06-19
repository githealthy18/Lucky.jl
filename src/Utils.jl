module Utils

using Dates
using BusinessDays
using TimeZones
using Lucky.Quotes

NYTZ = tz"America/New_York"
# BusinessDays.initcache(:USNYSE)
future_trade_date(x::Int) = isbday(:USNYSE, Dates.today()) ? advancebdays(:USNYSE, Dates.today(), x) : tobday(:USNYSE, Dates.today())
after_hours() = !isbday(:USNYSE, Dates.today()) ? true : todayat(Time(9,30), NYTZ) < now(NYTZ) < todayat(Time(16,0), NYTZ) ? false : true

struct TradingHours
    after_hours::Bool
end

function assign_businessday(data)
	output = Vector{Float32}(undef, length(data))
	for i in eachindex(data)
		output[i] = isbday(BusinessDays.USNYSE(), Date(data[i]))
	end
	return output
end

function percentage(num::Number; rounded::Union{Nothing,Int}=nothing, humanreadable::Bool=false)
    if (humanreadable)
        isnothing(rounded) && return "$(num * 100)%"        
        return "$(round(num;digits=rounded) * 100)%"
    end

    isnothing(rounded) && return num    
    return round(num; digits=rounded)
end

import Base: haskey, get, delete!
function haskey(h::Dict, k::AbstractQuote)
    for key in keys(h)
        if eltype(key) <: typeof(k)
            return true
        end
    end
    false
end

function get(h::Dict, k::AbstractQuote)
    for key in keys(h)
        if eltype(key) <: typeof(k)
            return h[key]
        end
    end
end

function delete!(h::Dict, k::AbstractQuote)
    for key in keys(h)
        if eltype(key) <: typeof(k)
            delete!(h, key)
        end
    end
end


end