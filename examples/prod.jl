using Dates
using Lucky
using Rocket
using DataFrames
using InteractiveBrokers
using BusinessDays
using Minio
using Lucky.Quotes: Last, Bid, Ask, Mark, High, Low, Close, Open, Volume, AskSize, BidSize, LastSize
using Lucky.Utils: after_hours

BusinessDays.initcache(:USNYSE)

const cfg = MinioConfig("http://localhost:9000")

mutable struct PreModelProcessor{A} <: AbstractStrategy
    data::DataFrame
    open::Union{Missing, Lucky.PriceQuote{I,Open,P,S,D} where {I,P,S,D}}
    high::Union{Missing,Lucky.PriceQuote{I,High,P,S,D} where {I,P,S,D}}
    low::Union{Missing, Lucky.PriceQuote{I,Low,P,S,D} where {I,P,S,D}}
    close::Union{Missing, Lucky.PriceQuote{I,Close,P,S,D} where {I,P,S,D}, Lucky.PriceQuote{I,Mark,P,S,D} where {I,P,S,D}}
    volume::Union{Missing, Lucky.VolumeQuote{I,Volume,P,D} where {I,P,D}}
    next::A
end

mutable struct PreModel{A} <: AbstractStrategy
    data::DataFrame
    open::Union{Missing, Lucky.PriceQuote{I,Open,P,S,D} where {I,P,S,D}}
    high::Union{Missing,Lucky.PriceQuote{I,High,P,S,D} where {I,P,S,D}}
    low::Union{Missing, Lucky.PriceQuote{I,Low,P,S,D} where {I,P,S,D}}
    close::Union{Missing, Lucky.PriceQuote{I,Close,P,S,D} where {I,P,S,D}, Lucky.PriceQuote{I,Mark,P,S,D} where {I,P,S,D}}
    volume::Union{Missing, Lucky.VolumeQuote{I,Volume,P,D} where {I,P,D}}
    next::A
end

PreModel(next::A) where {A} = PreModel(DataFrame(), missing, missing, missing, missing, missing, next)

function Rocket.on_next!(strat::PreModel, data::DataFrame)
    strat.data = data
end

function Rocket.on_next!(strat::PreModel, data::Lucky.PriceQuote{I,T,P,S,D}) where {I,T<:Mark,P,S,D}
    strat.close = data
end

function Rocket.on_next!(strat::PreModel, data::Lucky.PriceQuote{I,T,P,S,D}) where {I,T,P,S,D}
    setproperty!(strat, Symbol(lowercase(String(Symbol(T)))), data)
end

function Rocket.on_next!(strat::PreModel, data::Lucky.VolumeQuote{I,T,S,D}) where {I,T,S,D}
    setproperty!(strat, Symbol(lowercase(String(Symbol(T)))), data)
end

function Rocket.on_complete!(strat::PreModel)
    if !after_hours()
        strat.data.high[end] = strat.high.price
        strat.data.low[end] = strat.low.price
        strat.data.close[end] = strat.close.price
        strat.data.open[end] = strat.open.price
        strat.data.volume[end] = strat.volume.volume
    end
    complete!(strat.next)
end

client = Lucky.service(:interactivebrokers)
connect(client)
stock = Stock(:AAPL,:USD)
actor = PreModel(lambda(DataFrame; on_complete = ()->println("Done!")))
hist = Lucky.feed(client, stock, Val(:historicaldata))
feeds = Lucky.feed(client, stock, Val(:livedata))
source = merged((hist |> first(), feeds.openPrice |> first(), feeds.highPrice |> first(), feeds.lowPrice |> first(), feeds.markPrice |> first(), feeds.volume |> first()))
subscribe!(source, actor)
InteractiveBrokers.reqMarketDataType(client, InteractiveBrokers.FROZEN)

mutable struct GoldenCross{A} <: AbstractStrategy
    cashPosition::Union{Nothing,CashPositionType}
    aaplPosition::Union{Nothing,StockPositionType}
    prevSlowSMA::SlowIndicatorType
    prevFastSMA::FastIndicatorType
    slowSMA::SlowIndicatorType
    fastSMA::FastIndicatorType
    next::A
end