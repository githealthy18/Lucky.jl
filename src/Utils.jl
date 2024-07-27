module Utils

using Dictionaries

function percentage(num::Number; rounded::Union{Nothing,Int}=nothing, humanreadable::Bool=false)
    if (humanreadable)
        isnothing(rounded) && return "$(num * 100)%"        
        return "$(round(num;digits=rounded) * 100)%"
    end

    isnothing(rounded) && return num    
    return round(num; digits=rounded)
end

function deletefrom!(dict::Dictionary, inds::Indices)
    for i in inds
        unset!(dict, i)
    end
end


end