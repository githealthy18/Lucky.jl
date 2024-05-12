module Utils

using Dates
using BusinessDays
using TimeZones

NYTZ = tz"America/New_York"
# BusinessDays.initcache(:USNYSE)
future_trade_date(x::Int) = isbday(:USNYSE, Dates.today()) ? advancebdays(:USNYSE, Dates.today(), x) : tobday(:USNYSE, Dates.today())
after_hours() = !isbday(:USNYSE, Dates.today()) ? true : todayat(Time(9,30), NYTZ) < now(NYTZ) < todayat(Time(16,0), NYTZ) ? false : true

struct TradingHours
    after_hours::Bool
end


function percentage(num::Number; rounded::Union{Nothing,Int}=nothing, humanreadable::Bool=false)
    if (humanreadable)
        isnothing(rounded) && return "$(num * 100)%"        
        return "$(round(num;digits=rounded) * 100)%"
    end

    isnothing(rounded) && return num    
    return round(num; digits=rounded)
end

end