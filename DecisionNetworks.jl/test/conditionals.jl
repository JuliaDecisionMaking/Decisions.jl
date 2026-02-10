
@testset "Conditional distributions" begin
    @testset "Use PDF or generative form interchangeably" begin
        unif(; l, u) = rand()*(u-l) + l 
        unif(x; l, u) = 1/(u-l)

        U = ConditionalDist(unif)

        μ = 42
        σ = 0.001

        @test inputs(U) == (:l, :u)
        @test U(0 ; l=0, u=1) ≈ 1
        @test U(;l=42, u=42) == 42
    end
end