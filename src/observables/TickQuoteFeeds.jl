export TickQuoteFeed

using Rocket
using AutoHashEquals

@auto_hash_equals cache=true struct TickQuoteFeed{I} <: CompletionActor{Any}
    instrument::I
    lastPrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    bidPrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    askPrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    markPrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    highPrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    lowPrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    openPrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    closePrice::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    volume::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    askSize::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    bidSize::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    lastSize::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    tickString::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    openInterest::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
    averageOptVolume::Union{Rocket.Subscribable, Rocket.RecentSubjectInstance}
end

function Rocket.complete!(pwithproxy::ProxyObservable)
    Rocket.complete!(pwithproxy.proxied_source.main)
end

function Rocket.on_complete!(feeds::T) where {T<:TickQuoteFeed}
    completions = [
        Rocket.complete!(getproperty(feeds, name)) for name in filter(!in((:instrument, :_cached_hash)), fieldnames(typeof(feeds)))
    ]
end

function Rocket.isactive(subject::Rocket.RecentSubjectInstance)
    return subject.subject.isactive
end

function Rocket.isactive(withproxy::ProxyObservable)
    return Rocket.isactive(withproxy.proxied_source.main)
end

function Rocket.isactive(feeds::T) where {T<:TickQuoteFeed}
    isactive = [ 
        Rocket.isactive(getproperty(feeds, name)) for name in filter(!in((:instrument, :_cached_hash)), fieldnames(typeof(feeds)))
        ]
    return any(isactive)
end