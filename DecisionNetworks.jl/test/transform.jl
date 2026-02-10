
@testset "Named DPs can be produced by transformations" begin

    # This first one is an odd case: :m is an input, so removing it makes the
    #   action unconditioned. This is intentional behavior.
    @test POMDP_DN |> MergeForward(:o, :mp, :m) != MDP_DN
    @test POMDP_DN |> MergeForward(:o, :mp, :m) |> Recondition(; a=(Dense(:s),)) == MDP_DN
end

@testset "Multi-agent scenarios can be exploded and merged into single-agent ones" begin
    my_mg = MG_DN{(; i=2)}(;
        sp = (rng; a, s) -> "sp for actions $a",
        r = (rng; a, s, sp, i) -> "r$i"
    )

    exploded_mg = my_mg |> IndexExplode(:i) |> Implement(;
        a_2 = (rng; kwargs...) -> "a2"
    )

    my_mdp = exploded_mg |> MergeForward(:r_2, :a_2) |> Rename(; a_1=:a, r_1=:r)
    @test my_mdp isa MDP_DN
end