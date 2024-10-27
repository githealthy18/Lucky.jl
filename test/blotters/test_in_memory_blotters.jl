@testset "In Memory Blotters" begin
    fills = Subject(Fill)
    instr = Cash(:USD)
    order = MarketOrder(instr, OPEN, BUY_SIDE, 1.0, Dates.now(Dates.UTC))
    fill = Fill(9999, order, 12.45, 1.0, 0.0, Dates.now(Dates.UTC))

    lastPosition = nothing
    function testNextPosition(position::Position)
        lastPosition = position
    end

    function testComplete()
        @test lastPosition.instrument isa Cash{Currency{:USD}}
        @test lastPosition.size == 3
    end

    positions = Subject(Position)
    blotter = InMemoryBlotter(positions)
    subscribe!(fills, blotter)

    testActor = lambda(on_next=testNextPosition, on_complete=testComplete)
    subscribe!(positions, testActor)
    next!(fills, fill)
    next!(fills, fill)
    next!(fills, fill)
    complete!(fills)
end