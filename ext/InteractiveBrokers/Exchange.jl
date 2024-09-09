struct InteractiveBrokersExchange <: AbstractExchange
    client::InteractiveBrokersObservable
    orderbook::Lucky.InMemoryOrderBook
    fills::AbstractSubject
    positions::AbstractSubject
end

@inline InteractiveBrokersExchange(client::InteractiveBrokersObservable, fills::Subject, positions::Subject) = InteractiveBrokersExchange(client, orderbook(:inmemory), fills, positions)

Lucky.exchange(::Val{:ib}, client::InteractiveBrokersObservable, fills::Subject, positions::Subject) = InteractiveBrokersExchange(client, fills, positions)

function Lucky.placeorder(exchange::InteractiveBrokersExchange, order::MarketOrder)
    instr = order.instrument
    iborder = InteractiveBrokers.Order()
    iborder.orderId = Lucky.nextValidId(exchange)
    iborder.action = order.action == BUY_SIDE ? "BUY" : "SELL"
    iborder.totalQuantity = order.size
    iborder.orderType = "MKT"
    order.id = iborder.orderId
    push!(exchange.orderbook.pendingOrders[instr], order)
    InteractiveBrokers.placeOrder(exchange.client, iborder.orderId, instr, iborder)
end

function Lucky.placeorder(exchange::InteractiveBrokersExchange, order::LimitOrder)
    instr = order.instrument
    iborder = InteractiveBrokers.Order()
    iborder.orderId = Lucky.nextValidId(exchange)
    iborder.action = order.action == BUY_SIDE ? "BUY" : "SELL"
    iborder.totalQuantity = order.size
    iborder.orderType = "LMT"
    iborder.lmtPrice = order.limit
    order.id = iborder.orderId
    push!(exchange.orderbook.pendingOrders[instr], order)
    InteractiveBrokers.placeOrder(exchange.client, iborder.orderId, instr, iborder)
end

function Lucky.placeorder(exchange::InteractiveBrokersExchange, order::AlgorithmicMarketOrder)
    instr = order.instrument
    iborder = InteractiveBrokers.Order()
    iborder.orderId = Lucky.nextValidId(exchange)
    iborder.action = order.action == BUY_SIDE ? "BUY" : "SELL"
    iborder.totalQuantity = order.size
    iborder.orderType = "MKT"
    iborder.algoStrategy = order.algorithm
    order.id = iborder.orderId
    push!(exchange.orderbook.pendingOrders[instr], order)
    InteractiveBrokers.placeOrder(exchange.client, iborder.orderId, instr, iborder)
end

function Lucky.placeorder(exchange::InteractiveBrokersExchange, order::AlgorithmicLimitOrder)
    instr = order.instrument
    iborder = InteractiveBrokers.Order()
    iborder.orderId = Lucky.nextValidId(exchange)
    iborder.action = order.action == BUY_SIDE ? "BUY" : "SELL"
    iborder.totalQuantity = order.size
    iborder.orderType = "LMT"
    iborder.lmtPrice = order.limit
    iborder.algoStrategy = order.algorithm
    order.id = iborder.orderId
    push!(exchange.orderbook.pendingOrders[instr], order)
    InteractiveBrokers.placeOrder(exchange.client, iborder.orderId, instr, iborder)
end

Rocket.on_error!(actor::InteractiveBrokersExchange, error) = error!(actor.next, error)
Rocket.on_complete!(actor::InteractiveBrokersExchange) = complete!(actor.next)

function Rocket.on_next!(exchange::InteractiveBrokersExchange, order::O) where {O<:AbstractOrder}
    instr = order.instrument
    if !haskey(exchange.orderbook.pendingOrders, instr)
        insert!(exchange.orderbook.pendingOrders, instr, Vector{AbstractOrder}())
    end
    Lucky.placeorder(exchange, order)
end

function Rocket.on_next!(exchange::InteractiveBrokersExchange, orders::Vector{O}) where {O<:AbstractOrder}
    foreach(order -> on_next!(exchange, order), orders)
end

function Rocket.on_next!(exchange::InteractiveBrokersExchange, fill::F) where {F<:IbKrFill}
    instr = typeof(fill.order.instrument)
    todel = nothing
    for (idx, order) in enumerate(exchange.orderbook.pendingOrders[instr])
        if isnothing(todel)
            todel = Vector{Int}()
        end
        if order.id == fill.id
            luckyFill = Fill(fill.id, order, fill.price, fill.size, fill.fee, fill.timestamp)
            next!(exchange.fills, luckyFill)
            resultingOrder = order - luckyFill
            if resultingOrder.size == 0
                push!(todel, idx)
            else
                exchange.orderbook.pendingOrders[instr][idx] = resultingOrder
            end
        end
    end
    isnothing(todel) || deleteat!(exchange.orderbook.pendingOrders[instr], todel)
end
