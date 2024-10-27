@testset "Stocks" begin
    ticker = :AAPL
    USD = Currency(:USD)
    @testset "Constructors" begin
        @test Stock(ticker, :USD) isa Stock{Symbol, Currency{:USD}}
    end
    @testset "Interfaces" begin
        stock = Stock(ticker, :USD)
        @test InstrumentType(stock) === Stock{Symbol, Currency{:USD}}
        @test currency(stock) == "USD"
    end
end
