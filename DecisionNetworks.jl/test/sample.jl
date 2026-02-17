

@testset "Sample from an MDP" begin
    action_dist = @ADist

    Policy = @ADist
    Base.rand(::Policy; s, rest...) = s + randn()

    Transition = @ADist
    function Base.rand(::Transition; s, a, rest...) 
        if s <= 1
            s + a
        else
            terminal
        end
    end

    Reward = @ADist
    Base.rand(::Reward; s, a, sp, rest...) = sp

    mdp = MDP_DN(; a=Policy(), sp = Transition(), r = Reward())
    r = Base.rand(mdp; s=1)[:r]
    @test r > 0
end