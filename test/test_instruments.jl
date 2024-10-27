@testset "Instruments" begin
    struct DummyInstrument <: Instrument
    end
    @testset "Interfaces" begin
        @test_throws ErrorException currency(DummyInstrument)
        @test_throws ErrorException currency(DummyInstrument())
    end
end

include("instruments/test_cash.jl")
include("instruments/test_stocks.jl")
include("instruments/test_bonds.jl")
include("instruments/test_futures.jl")
include("instruments/test_options.jl")
