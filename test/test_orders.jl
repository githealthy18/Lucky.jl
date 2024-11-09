
@testset "Orders" begin
    @testset "Market Orders" begin
        @testset "Constructors" begin
            instr = Cash(:USD)
            order = MarketOrder(instr, OPEN, BUY_SIDE, 100, now())
            @test order isa MarketOrder{InstrumentType(instr), ORDER_SIDE, Int, DateTime}
        end
        @testset "Interfaces" begin
            instr = Cash(:USD)
            order = MarketOrder(instr, OPEN, BUY_SIDE, 100, now())
            @test currency(order) == CurrencyType(currency(instr))
            @test currency(OrderType(order)) == CurrencyType(currency(instr))
        end
    end
    @testset "Limit Orders" begin
        @testset "Constructors" begin
            instr = Cash(:USD)
            order = LimitOrder(instr, CLOSE, SELL_SIDE, 100, 1.0889, now())
            @test order isa LimitOrder{InstrumentType(instr), ORDER_SIDE, Int, DateTime}
        end
        @testset "Interfaces" begin
            instr = Cash(:USD)
            order = LimitOrder(instr, CLOSE, SELL_SIDE, 100, 1.0889, now())
            @test currency(order) == CurrencyType(currency(instr))
            @test currency(OrderType(order)) == CurrencyType(currency(instr))
        end
    end
    @testset "Algorithmic Market Orders" begin
        @testset "Constructors" begin
            instr = Cash(:USD)
            order = AlgorithmicMarketOrder(instr, CLOSE, SELL_SIDE, 100, "algo", (adaptivePriority="Urgent",), now())
            @test order isa AlgorithmicMarketOrder{InstrumentType(instr), ORDER_SIDE, Int, DateTime}
        end
        @testset "Interfaces" begin
            instr = Cash(:USD)
            order = AlgorithmicMarketOrder(instr, CLOSE, SELL_SIDE, 100, "algo", (adaptivePriority="Urgent",), now())
            @test currency(order) == CurrencyType(currency(instr))
            @test currency(OrderType(order)) == CurrencyType(currency(instr))
        end
    end
    @testset "Algorithmic Limit Orders" begin
        @testset "Constructors" begin
            instr = Cash(:USD)
            order = AlgorithmicLimitOrder(instr, CLOSE, SELL_SIDE, 100, 1.0889, "algo", (adaptivePriority="Urgent",), now())
            @test order isa AlgorithmicLimitOrder{InstrumentType(instr), ORDER_SIDE, Int, DateTime}
        end
        @testset "Interfaces" begin
            instr = Cash(:USD)
            order = AlgorithmicLimitOrder(instr, CLOSE, SELL_SIDE, 100, 1.0889, "algo", (adaptivePriority="Urgent",), now())
            @test currency(order) == CurrencyType(currency(instr))
            @test currency(OrderType(order)) == CurrencyType(currency(instr))
        end
    end
end