
@testset "Named problems are valid decision problems" begin
    T = (s, a) -> s + a
    Z = (s) -> s + rand()
    R = (s) -> s

    pomdp = POMDP_DN(; sp=T, o=Z, r=R)

    @test pomdp isa DecisionNetwork
end

@testset "Disambiguate based on reward conditioning" begin
    
    SA_POMDP_DN = POMDP_DN |> Recondition

    uses_sasp(m::POMDP) = false
    uses_sasp(m::typeof(p_sa)) = true


    @test ! uses_sa(p_s)
    @test uses_sa(p_sa)
end

# @testset "Disambiguate a problem "