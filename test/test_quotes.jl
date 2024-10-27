@testset "Quotes" begin
    @testset "Abstract Interfaces" begin        
        struct TestQuote <: AbstractQuote end
        @test QuoteType(TestQuote) === TestQuote
        @test_throws ErrorException TimestampType(TestQuote)
    end
    stock = Stock(:AAPL, :USD)
    @testset "Number" begin
        price = 51.7
        size = 100
        stamp = Date(2021, 1, 1)
        q1 = Quote(stock, Ask(), price, size, stamp)
        @testset "Constructors" begin
            @test q1 isa PriceQuote
            @test q1.instrument == stock
            @test q1.price == price
        end
        @testset "Interfaces" begin
            @test QuoteType(stock, Ask, Float64, Int, Date) === PriceQuote{InstrumentType(stock),Ask,Float64,Int,Date}
            @test currency(q1) == "USD"
            @test timestamp(q1) == stamp
        end
        @testset "Operators" begin
            p2 = 8.3
            s2 = 200
            t2 = Date(2021, 2, 1)
            q2 = Quote(stock, Ask(), p2, s2, t2)

            # Valid ops
            @test q1 + q2 == Quote(stock, Ask(), price + p2, Int(mean((size, s2))), t2)
            @test q2 - q1 == Quote(stock, Ask(), p2 - price, Int(mean((size, s2))), t2)
            @test q2 * 2 == Quote(stock, Ask(), p2 * 2, s2, t2)
            @test q2 / 2 == Quote(stock, Ask(), p2 / 2, s2, t2)
            @test q2 < q1

            # Ops with missing
            @test q1 + missing === missing
            @test missing - q1 === missing

            # Different instruments
            cash = Cash(:USD)
            q3 = Quote(cash, Bid(), p2, s2, t2)
            @test_throws MethodError q1 + q3
            @test_throws MethodError q3 - q1

            # Convert
            @test convert(Float64, q3) == Float64(p2)
        end
    end
    @testset "Ohlc" begin
        ohlc1 = rand(Ohlc{Date})
        q1 = Quote(stock, Last(), ohlc1)
        @testset "Constructors" begin
            @test q1 isa OhlcQuote
            @test q1.instrument == stock
            @test q1.ohlc == ohlc1
        end
        @testset "Interface" begin
            QuoteType(stock, Last, Ohlc{Date}) === PriceQuote{InstrumentType(stock),Last, Ohlc{Date}, Float64}
            currency(q1) == Currency{:USD}
            timestamp(q1) == ohlc1.timestamp
        end
        @testset "Operators" begin
            ohlc2 = rand(Ohlc{Date})
            #println("1: $(ohlc1)")
            #println("2: $(ohlc2)")
            q2 = Quote(stock, Last(), ohlc2)

            # Valid ops
            @test q1 + q2 == Quote(stock, Last(), ohlc1 + ohlc2)
            @test_throws MethodError q2 - q1
            @test q2 * 2 == Quote(stock, Last(), ohlc2 * 2)
            @test q2 / 2 == Quote(stock, Last(), ohlc2 / 2)
            @test_broken q2 < q1 == ohlc2.close < ohlc1.close

            # Ops with missing
            @test q1 + missing === missing
            @test missing - q1 === missing

            # Different instruments
            cash = Cash(:USD)
            q3 = Quote(cash, Bid(), ohlc2)
            @test_throws MethodError q1 + q3
            @test_throws MethodError q3 - q1

            # Convert
            @test convert(Float64, q3) == Float64(ohlc2.close)
        end
    end
    @testset "VolumeQuote" begin
        volume = 1000
        stamp = Date(2021, 1, 1)
        q1 = Quote(stock, Ask(), volume, stamp)
        @testset "Constructors" begin
            @test q1 isa VolumeQuote
            @test q1.instrument == stock
            @test q1.volume == volume
        end
        @testset "Interfaces" begin
            @test QuoteType(stock, Ask, Int, Date) === VolumeQuote{InstrumentType(stock),Ask,Int,Date}
            @test currency(q1) == "USD"
            @test timestamp(q1) == stamp
        end
        @testset "Operators" begin
            volume2 = 2000
            t2 = Date(2021, 2, 1)
            q2 = Quote(stock, Ask(), volume2, t2)

            # Valid ops
            @test q1 + q2 == Quote(stock, Ask(), volume + volume2, t2)
            @test q2 * 2 == Quote(stock, Ask(), volume2 * 2, t2)
            @test q2 / 2 == Quote(stock, Ask(), Int(volume2 / 2), t2)
            @test q1 < q2

            # Ops with missing
            @test q1 + missing === missing
            @test missing - q1 === missing

            # Different instruments
            cash = Cash(:USD)
            q3 = Quote(cash, Bid(), volume2, t2)
            @test_throws MethodError q1 + q3
            @test_throws MethodError q3 - q1

            # Convert
            @test convert(Int, q3) == volume2
        end
    end
end