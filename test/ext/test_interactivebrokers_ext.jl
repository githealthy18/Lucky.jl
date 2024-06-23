@testset "InteractiveBrokersExt" begin
    @testset "Interfaces" begin
        @testset "service()" begin
            client = Lucky.service(:interactivebrokers)
            @test client isa Rocket.Subscribable
                        
            InteractiveBrokers.reqMarketDataType(client, InteractiveBrokers.FROZEN)

            stock = Stock(:AAPL,:USD)

            qt, qt_vol = Lucky.feed(client, stock, Val(:livedata)) # reqMktData should return a Subscribable
            @test Rocket.as_subscribable(qt) isa SimpleSubscribableTrait # or ScheduledSubscribableTrait
            subscribe!(qt, logger("live"))
            subscribe!(qt_vol, logger("live_vol"))
            # TODO Test quote params InteractiveBrokers.reqMktData(ib, 1, contract, "100,101,104,106,165,221,225,236", false)
            # TODO Test if a subject            

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