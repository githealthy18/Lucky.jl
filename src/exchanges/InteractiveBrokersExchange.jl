module InteractiveBrokersExchange

export QuoteAggregator

using Lucky.Constants
using Lucky.ProcessMsgs: RegisterResponse, CompleteQuoteMsg, IncompleteDataRequest, CompleteRequestMsg
using Lucky.Exchanges
using Lucky.Fills
using Lucky.Instruments
using Lucky.Orders
using Lucky.Quotes
using Lucky.Ohlcs

using Rocket
using Dates

# Rocket Subjects

const PRICE_QUOTES = Subject(PriceQuote)

mutable struct QuoteAggregator{S, R, A} <: Actor{Union{RegisterResponse, PriceQuote, <:CompleteQuoteMsg, IncompleteDataRequest}}
    tickerId::Union{Nothing, Int}
    queueId::Union{Nothing, Int}
    bundle::Dict{DataType, Union{Nothing, PriceQuote}}
    subscription::Union{Nothing, Rocket.SubjectSubscription}
    strategy::S
    requestManager::R
    next::A
end

QuoteAggregator(bundle::Dict{DataType, Union{Nothing,PriceQuote}}, strategy::S, requestManager::R, next::A) where {S, R, A} = QuoteAggregator(
    nothing, 
    nothing,
    bundle,
    nothing,
    strategy,
    requestManager,
    next
)

Rocket.on_next!(actor::QuoteAggregator, quotes::PriceQuote) = begin
    if eltype(quotes.instrument) == actor.tickerId
        actor.bundle[typeof(quotes.tick)] = quotes
        next!(actor, CompleteQuoteMsg(quotes))
    end
end

function Rocket.on_next!(actor::QuoteAggregator, msg::RegisterResponse) 
    actor.tickerId = msg.reqId
    actor.queueId = msg.queueId

    actor.subscription = subscribe!(PRICE_QUOTES, actor)
end

Rocket.on_next!(actor::QuoteAggregator, msg::CompleteQuoteMsg) = begin
    if all(!isnothing(v) for v in values(actor.bundle))
        unsubscribe!(actor.subscription)
        complete!(actor)
    end
end

function Rocket.on_next!(actor::QuoteAggregator, msg::IncompleteDataRequest)
    unsubscribe!(subscription)
    next!(actor.strategy, false)
end

Rocket.on_complete!(actor::QuoteAggregator) = begin
    next!(actor.next, actor.bundle)
    next!(actor.requestManager, CompleteRequestMsg(actor.tickerId, actor.queueId))
end

end