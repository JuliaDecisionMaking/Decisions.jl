

@testset "Sample from a POMDP" begin
    Z = (s) -> s + randn()
    T = (s, a) -> s + a
    R = (s, a, sp) -> sp

    pomdp = POMDP(T, Z, R)

    r = sample(pomdp, (; a = (o, m) -> 10), (; s=0, m=0), (:r,))[:r]
    @test r > 0
end