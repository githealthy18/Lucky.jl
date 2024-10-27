@testset "Fills" begin
    instr = Cash(:USD)
    stamp = now()
    order = MarketOrder(1, instr, OPEN, BUY_SIDE, 2.0, stamp)
    @testset "Constructors" begin                
        fill = Fill(1, order, 12.45, 1.0, 0.0, Dates.now(Dates.UTC))
        @test fill isa Fill{OrderType(order), Float64, DateTime}
    end
    @testset "Interfaces" begin
        fill = Fill(1, order, 12.45, 1.0, 0.0, Date(2021,1,1))
        @test FillType(fill) == Fill{OrderType(order), Float64, Date}
        @test currency(fill) == Currency{:USD}
    end
    @testset "Operators" begin
        fill1 = Fill(1, order, 12.45, 1.0, 0.0, Date(2021,1,1))
        fill2 = Fill(2, order, 12.45, 1.0, 0.0, Date(2021,1,1))
        @test order - fill1 == MarketOrder(1, instr, OPEN, BUY_SIDE, 1.0, stamp)
        @test fill1 + fill2 == Fill(1, order, 12.45, 2.0, 0.0, Date(2021,1,1))
    end
end