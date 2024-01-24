using Lucky.Ohlcs

using Dates

ohlcbase = Ohlc(14.2, 14.4, 14.1, 14.3, Date(2021, 1, 15))

@testset "Ohlc Parts" begin
    @test ohlcpart(ohlcbase, top) == [14.3, 14.4]
    @test ohlcpart(ohlcbase, bottom) == [14.1, 14.2]
    @test ohlcpart(ohlcbase, body) == [14.2, 14.3]
end

@testset "Gap" begin
    gapup = Ohlc(15.5, 17.5, 15.3, 15.6, Date(2021, 1, 16))
    @test gap(gapup, ohlcbase) == (up, [14.4, 15.3])

    gapdown = Ohlc(10.5, 13.5, 9.5, 11.6, Date(2021, 1, 16))
    @test gap(gapdown, ohlcbase) == (down, [13.5, 14.1])
end

@testset "Timetypes" begin
    @test Lucky.timetype(ohlcbase) == Dates.Date
    vector = Vector{Lucky.Ohlc}()
    push!(vector, ohlcbase)
    @test_broken Lucky.timetype(vector) == Dates.Date
end