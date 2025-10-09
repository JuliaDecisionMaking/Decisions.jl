
function RockSampleDecisionsPOMDP(;pomdp = RockSample.RockSamplePOMDP())
    up = POMDPTools.DiscreteUpdater(pomdp)
    m0 = POMDPs.initialize_belief(up,POMDPs.initialstate(pomdp))
    rstransition = @ConditionalDist RockSample.RSState begin
        function support(;s,a)
            if isnothing(s) || isnothing(a)
                POMDPTools.ordered_states(pomdp)
            else
                Distributions.support(POMDPs.transition(pomdp,s,a))
            end
        end

        function rand(rng;s,a) #rand! (?)
            if POMDPs.isterminal(pomdp,s)
                Terminal()
            else
                rand(rng,POMDPs.transition(pomdp,s,a))
            end
        end

        function pdf(sp;s,a)
            Distributions.pdf(POMDPs.transition(pomdp,s,a),sp)
        end
    end

    rsreward = @ConditionalDist Float64 begin
        function rand(rng; s, a, sp)
            POMDPs.reward(pomdp,s,a,sp)
        end
    end

    rsobservation = @ConditionalDist Int begin
        function support(;s,a,sp)
            if isnothing(s) || isnothing(a)
                POMDPTools.ordered_observations(pomdp)
            else
                Distributions.support(POMDPs.observation(pomdp,s,a,sp))
            end
        end

        function rand(rng;s,a,sp)
            rand(rng,POMDPs.observation(pomdp,s,a,sp))
        end

        function pdf(o;s,a,sp)
            Distributions.pdf(POMDPs.observation(pomdp,s,a,sp),o)
        end
    end

    rsmemory = @ConditionalDist typeof(m0) begin
        function support(;a,m,o)
            POMDPs.update(up,m,a,o)
        end
        
        function rand(rng;a,m,o)
            POMDPs.update(up,m,a,o)
        end

        function pdf(mp;a,m,o)
            true_mp = POMDPs.update(up,m,a,o) #Bad? - Handle mp not in support?
            if mp == true_mp
                return 1.0
            else
                return 0.0
            end
        end
    end
    
    # rsinitialbel = @ConditionalDist Tuple{RockSample.RSState,Int} begin
    rsinitialbel = @ConditionalDist @NamedTuple{s::RockSample.RSState,m::typeof(m0)} begin
        support(;) = [ (;s = s, m = m0) for s in POMDPTools.ordered_states(pomdp) ]
        rand(rng;) = (;s = rand(rng,m0), m = m0)
    end

    rsa = @ConditionalDist Int64 begin
        function support(;m)
            POMDPTools.ordered_actions(pomdp)
        end
        function rand(;m)
            rand(POMDPTools.ordered_actions(pomdp))
        end
    end

    return DecisionProblems.POMDP(DiscountedReward(POMDPs.discount(pomdp)),rsinitialbel;
    sp = rstransition,
    r = rsreward,
    o = rsobservation,
    mp = rsmemory,
    a = rsa
    )
end


#=

using DecisionNetworks
using DecisionProblems
using POMDPTools
using POMDPs
using RockSample

include("DecisionDomains.jl/src/rocksample.jl")

struct RandomSolver <: DecisionAlgorithm end

function DecisionProblems.solve(::RandomSolver, dp::DecisionProblem)
    # sample uniformly from the declared action space of the problem
    pol = @ConditionalDist Int begin
        rand(rng; m) = rand(rng, DecisionNetworks.support(dp[:a];m=m))   
    end
    (; a = pol)   # MUST be a NamedTuple keyed by action node names
end

function episode_rocksample_decisions(; steps=10, rng = MersenneTwister(0), 
                                pomdp = RockSample.RockSamplePOMDP())

    rs_prob = RockSampleDecisionsPOMDP(; pomdp)
    rs_random_solver = RandomSolver()
    
    traj = NamedTuple[]
    G = 0.0
    γ = POMDPs.discount(pomdp)
    t = 0
    println("Starting Episode...")
    simulate!(rs_random_solver, rs_prob) do vals
        t += 1
        println("Step $t: a=$(vals[:a]), r=$(vals[:r]), o=$(vals[:o])")
        push!(traj, (; t, a = vals[:a], r = vals[:r], o = vals[:o]))
        G += (γ^(t-1)) * vals[:r]
        t >= steps
    end
    return (; traj, G)
end


rs_prob = RockSampleDecisionsPOMDP()
rs_solver = RandomSolver()

episode_rocksample_decisions(steps=10);

=#