
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

    rsmemory = @ConditionalDist POMDPTools.BeliefUpdaters.DiscreteBelief{RockSample.RockSamplePOMDP{3}, RockSample.RSState{3}} begin
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
    
    rsinitialbel = @ConditionalDist Tuple{RockSample.RSState,Int} begin
        function support(;)
            m0
        end
        function pdf(m;)
            if m == m0
                1.0
            else
                0.0
            end
        end
        function rand(;)
            m0
        end
    end

    rsa = @ConditionalDist Int64 begin
        function support(;m)
            POMDPTools.ordered_actions(pomdp)
        end
        function rand(;m)
            rand(POMDPTools.ordered_actions(pomdp))
        end
    end

    return Decisions.POMDP(DiscountedReward(POMDPs.discount(pomdp)),rsinitialbel;
    sp = rstransition,
    r = rsreward,
    o = rsobservation,
    mp = rsmemory,
    a = rsa
    )
end
