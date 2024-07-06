@testset "InteractiveBrokersExt" begin
    @testset "Interfaces" begin
        @testset "service()" begin
            client = Lucky.service(:interactivebrokers)
            @test client isa Rocket.Subscribable
                        
            InteractiveBrokers.reqMarketDataType(client, InteractiveBrokers.FROZEN)

            stock = Stock(:AAPL,:USD)
            stock2 = Stock(:JPM,:USD)

            qt, qt_vol = Lucky.feed(client, stock, Val(:livedata)) # reqMktData should return a Subscribable
            qt2, qt_vol2 = Lucky.feed(client, stock2, Val(:livedata)) # reqMktData should return a Subscribable
            @test Rocket.as_subscribable(qt) isa SimpleSubscribableTrait # or ScheduledSubscribableTrait
            subscribe!(qt, logger("live"))
            subscribe!(qt_vol, logger("live_vol"))
            subscribe!(qt2, logger("live2"))
            subscribe!(qt_vol2, logger("live_vol2"))

            hist = Lucky.feed(client, stock, Val(:historicaldata); timeout=30000)
            subscribe!(hist, logger("hist"))
            subscribe!(hist, lambda(DataFrame; on_next=(d)->println(d))) # reqHistoricalData should return a Subscribable
            connect(client)
            # TODO Test quote params InteractiveBrokers.reqMktData(ib, 1, contract, "100,101,104,106,165,221,225,236", false)
            # TODO Test if a subject            

            feeds = Lucky.feed(client, stock, Val(:livedata))
            subscribe!([(feeds.highPrice, actor), (feeds.lowPrice, actor), (feeds.openPrice, actor), (feeds.closePrice, actor)])
            subscribe!([(feeds.markPrice, logger("MARK")), (feeds.bidPrice, logger("BID"))])
            connect(client)
            subscribe!([(feeds.askPrice, logger("ASK")), (feeds.lastPrice, logger("LAST"))])

            hist = Lucky.feed(client, stock, Val(:historicaldata); timeout=30000)
            subscribe!(hist, logger("hist"))
            connect(client)
            
            # connect
            # connect(client)
            # disconnect(client.connection)
        end
        @testset "Contract" begin
            stock = Stock(:AAPL, :USD)
            @test_broken InteractiveBrokers.Contract(stock) == InteractiveBrokers.Contract(
                symbol="AAPL",
                secType="STK",
                exchange="SMART",
                currency="USD"
                );
        end
    end
end