@testset "Options" begin
    ticker = :AAPL
    USD = Currency(:USD)
    @testset "Constructors" begin
        @test Option(Stock(ticker, :USD), CALL, 100.0, today()) isa Option{Stock{Symbol, Currency{:USD}}, OPTION_RIGHT, Float64, Date}
    end
    @testset "Interfaces" begin
        stock = Stock(ticker, :USD)
        option = Option(stock, CALL, 100.0, today())
        @test InstrumentType(option) === Option{Stock{Symbol, Currency{:USD}}, OPTION_RIGHT, Float64, Date}
        @test currency(option) == "USD"
    end
    @testset "Greeks" begin
        stock = Stock(ticker, :USD)
        option = Option(stock, CALL, 100.0, today())
        @test isequal(option.greeks,Lucky.Greeks(NaN, NaN, NaN, NaN, NaN, NaN))
        setImpliedVolatility!(option, 0.2)
        @test isequal(option.greeks,Lucky.Greeks(0.2, NaN, NaN, NaN, NaN, NaN))
        setDelta!(option, 0.5)
        @test isequal(option.greeks,Lucky.Greeks(0.2, 0.5, NaN, NaN, NaN, NaN))
        setGamma!(option, 0.3)
        @test isequal(option.greeks,Lucky.Greeks(0.2, 0.5, 0.3, NaN, NaN, NaN))
        setVega!(option, 0.4)
        @test isequal(option.greeks,Lucky.Greeks(0.2, 0.5, 0.3, 0.4, NaN, NaN))
        setTheta!(option, 0.6)
        @test isequal(option.greeks,Lucky.Greeks(0.2, 0.5, 0.3, 0.4, 0.6, NaN))
        setRho!(option, 0.7)
        @test isequal(option.greeks,Lucky.Greeks(0.2, 0.5, 0.3, 0.4, 0.6, 0.7))
    end
end