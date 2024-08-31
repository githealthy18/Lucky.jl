export feed, end_feed

function feed end

feed(x::Any) = error("You probably forgot to implement feed($(x))")

function end_feed end

end_feed(x::Any) = error("You probably forgot to implement end_feed($(x))")