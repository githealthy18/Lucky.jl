@testset "Utils" begin
    @testset "percentage()" begin
        val = 0.375
        @test percentage(val) ≈ val
        
        # Not rounded        
        @test percentage(val;rounded=nothing, humanreadable=true) == "37.5%"

        # # Human readable
        @test percentage(val;rounded=2) ≈ 0.38
        @test percentage(val;rounded=2, humanreadable=true) == "38.0%"
    end

    @testset "deletefrom!()" begin
        dict = Dictionary([1,2,3], [1,2,3])
        deletefrom!(dict, Indices([1, 2]))
        @test dict == Dictionary([3],[3])
    end
end