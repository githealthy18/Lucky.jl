struct InteractiveBrokersExchange <: AbstractExchange
    client::InteractiveBrokersObservable
    orderbook::Lucky.InMemoryOrderBook
    fills::AbstractSubject
end

@inline InteractiveBrokersExchange(client::InteractiveBrokersObservable, fills::Subject) = InteractiveBrokersExchange(client, orderbook(:inmemory), fills)

Lucky.exchange(::Val{:ib}, client::InteractiveBrokersObservable, fills::Subject) = InteractiveBrokersExchange(client, fills)

function Lucky.placeorder(exchange::InteractiveBrokersExchange, order::MarketOrder)
    instr = order.instrument
    iborder = InteractiveBrokers.Order()
    iborder.orderId = Lucky.nextValidId(exchange.client)
    iborder.action = order.side == BUY_SIDE ? "BUY" : "SELL"
    iborder.totalQuantity = order.size
    iborder.orderType = "MKT"
    order.id = iborder.orderId
    push!(exchange.orderbook.pendingOrders[instr], order)
    InteractiveBrokers.placeOrder(exchange.client, iborder.orderId, instr, iborder)
end

function Lucky.placeorder(exchange::InteractiveBrokersExchange, order::LimitOrder)
    instr = order.instrument
    iborder = InteractiveBrokers.Order()
    iborder.orderId = Lucky.nextValidId(exchange.client)
    iborder.action = order.side == BUY_SIDE ? "BUY" : "SELL"
    iborder.totalQuantity = order.size
    iborder.orderType = "LMT"
    iborder.lmtPrice = round(order.limit)
    order.id = iborder.orderId
    push!(exchange.orderbook.pendingOrders[instr], order)
    InteractiveBrokers.placeOrder(exchange.client, iborder.orderId, instr, iborder)
end

function Lucky.placeorder(exchange::InteractiveBrokersExchange, order::AlgorithmicMarketOrder)
    instr = order.instrument
    iborder = InteractiveBrokers.Order()
    iborder.orderId = Lucky.nextValidId(exchange.client)
    iborder.action = order.side == BUY_SIDE ? "BUY" : "SELL"
    iborder.totalQuantity = order.size
    iborder.orderType = "MKT"
    iborder.algoStrategy = order.algorithm
    iborder.algoParams = order.algorithmParams
    order.id = iborder.orderId
    push!(exchange.orderbook.pendingOrders[instr], order)
    InteractiveBrokers.placeOrder(exchange.client, iborder.orderId, instr, iborder)
end

function Lucky.placeorder(exchange::InteractiveBrokersExchange, order::AlgorithmicLimitOrder)
    instr = order.instrument
    iborder = InteractiveBrokers.Order()
    iborder.orderId = Lucky.nextValidId(exchange.client)
    iborder.action = order.side == BUY_SIDE ? "BUY" : "SELL"
    iborder.totalQuantity = order.size
    iborder.orderType = "LMT"
    iborder.lmtPrice = round(order.limit)
    iborder.algoStrategy = order.algorithm
    iborder.algoParams = order.algorithmParams
    order.id = iborder.orderId
    push!(exchange.orderbook.pendingOrders[instr], order)
    InteractiveBrokers.placeOrder(exchange.client, iborder.orderId, instr, iborder)
end

function Lucky.placeorder(exchange::InteractiveBrokersExchange, order::PegMidOrder{I}) where {I<:Option}
    instr = order.instrument
    iborder = InteractiveBrokers.Order()
    iborder.orderId = Lucky.nextValidId(exchange.client)
    iborder.action = order.side == BUY_SIDE ? "BUY" : "SELL"
    iborder.totalQuantity = order.size
    iborder.orderType = "PEG MID"
    iborder.designatedLocation = "IBUSOPT"
    
    if order.limit != 0.0
        iborder.lmtPrice = round(order.limit)
    end
    iborder.midOffsetAtWhole = order.midOffsetAtWhole
    iborder.midOffsetAtHalf = order.midOffsetAtHalf
    order.id = iborder.orderId
    push!(exchange.orderbook.pendingOrders[instr], order)
    InteractiveBrokers.placeOrder(exchange.client, iborder.orderId, instr, iborder)
end

function Lucky.placeorder(exchange::InteractiveBrokersExchange, order::PegMidOrder{I}) where {I<:Stock}
    instr = order.instrument
    iborder = InteractiveBrokers.Order()
    iborder.orderId = Lucky.nextValidId(exchange.client)
    iborder.action = order.side == BUY_SIDE ? "BUY" : "SELL"
    iborder.totalQuantity = order.size
    iborder.orderType = "PEG MID"
    iborder.designatedLocation = "IBKRATS"
    
    if order.limit != 0.0
        iborder.lmtPrice = round(order.limit)
    end
    iborder.primaryOffset = order.primaryOffset
    iborder.secondaryOffset = order.secondaryOffset
    order.id = iborder.orderId
    push!(exchange.orderbook.pendingOrders[instr], order)
    InteractiveBrokers.placeOrder(exchange.client, iborder.orderId, instr, iborder)
end

Rocket.on_error!(actor::InteractiveBrokersExchange, error) = @warn error
Rocket.on_complete!(actor::InteractiveBrokersExchange) = @info "Orders Placed"

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
    instr = fill.instrument
    todel = nothing
    if !haskey(exchange.orderbook.pendingOrders, instr)
        @warn "No pending orders for instrument $(instr) to match fill $(fill.id)"
        return
    end
    for (idx, order) in enumerate(exchange.orderbook.pendingOrders[instr])
        if isnothing(todel)
            todel = Vector{Int}()
        end
        if order.id == fill.id
            luckyFill = Fill(fill.id, order, fill.avgPrice, fill.size, fill.fee, fill.timestamp)
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

function Rocket.on_next!(exchange::InteractiveBrokersExchange, msg::CancelAllOrders)
    InteractiveBrokers.reqGlobalCancel(exchange.client)
    for orders in exchange.orderbook.pendingOrders
        empty!(orders)
    end
end
