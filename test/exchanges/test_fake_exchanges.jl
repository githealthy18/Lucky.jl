@testset "FakeExchange" begin
    stamp = now()
    @testset "matching with MarketOrder" begin
        quotesSubject = Subject(AbstractQuote)
        ordersSubject = Subject(AbstractOrder)

        instr = Cash(:USD)
        ohlc = rand(Ohlc{DateTime})
        qte = Quote(instr, Ask(), ohlc)
        qtes = Rocket.of(qte) |> multicast(quotesSubject)

        order = MarketOrder(instr, OPEN, BUY_SIDE, rand(-10:0.1:10), stamp)
        orders = Rocket.of(order) |> multicast(ordersSubject)

        fills = Subject(Lucky.Fill)
        ex = exchange(:fake, fills)

        subscribe!(quotesSubject, ex)
        subscribe!(ordersSubject, ex)

        function testNextMarketOrder(pos::Fill)
            @test (pos.id isa Number) && length(pos.id) > 0
            @test pos.order == order
            @test pos.size == order.size
            @test pos.price == ohlc.open
            @test pos.timestamp == ohlc.timestamp
            @test length(exchange.pendingOrders) == 0
        end

        function testCompleteMarketOrder()
        end
        testActor = lambda(on_next=testNextMarketOrder, on_complete=testCompleteMarketOrder)
        subscribe!(fills, testActor)

        connect(orders)
        connect(qtes)
    end

    @testset "matching with LimitOrder" begin
        ohlc = rand(Ohlc{DateTime})

        instr = Cash(:USD)
        above = LimitOrder(instr, OPEN, BUY_SIDE, 1.0, ohlc.high + 1, stamp)
        below = LimitOrder(instr, OPEN, BUY_SIDE, 1.0, ohlc.low - 1, stamp)
        inside = LimitOrder(999, instr, OPEN, BUY_SIDE, 1.0, ohlc.open, stamp)

        @test Lucky.match(above, Quote(instr, Bid(), ohlc)) === nothing
        @test Lucky.match(below, Quote(instr, Bid(), ohlc)) === nothing

        pos = Lucky.match(inside, Quote(instr, Bid(), ohlc))
                                
        @test pos isa Fill
        @test (pos.id isa Number) && length(pos.id) > 0
        @test pos.order == inside
        @test pos.size == inside.size
        @test pos.price == ohlc.open
        @test pos.fee == 0
        @test pos.timestamp == ohlc.timestamp
    end

    # TODO Test LimitOrder signs
    # TODO Test instrument matching
end