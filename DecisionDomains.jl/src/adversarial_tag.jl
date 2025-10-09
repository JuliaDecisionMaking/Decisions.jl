function TagAdversarial(; size=(10,7), n_obstacles=1, rng=MersenneTwister(20))
    sz = SVector(size...)
    blocked = falses(size...)
    obstacles = Set{Pos}()

    # obstacles
    while length(obstacles) < n_obstacles
        o = SVector(rand(rng, 1:sz[1]), rand(rng, 1:sz[2]))
        if !blocked[o...]
            push!(obstacles, o); blocked[o...] = true
        end
    end

    # initial robots (distinct, not blocked)
    r1 = SVector(rand(rng, 1:sz[1]), rand(rng, 1:sz[2]))
    while blocked[r1...] ; r1 = SVector(rand(rng, 1:sz[1]), rand(rng, 1:sz[2])) ; end
    r2 = SVector(rand(rng, 1:sz[1]), rand(rng, 1:sz[2]))
    while blocked[r2...] || r2 == r1
        r2 = SVector(rand(rng, 1:sz[1]), rand(rng, 1:sz[2]))
    end

    # initial target (not blocked, not on robots)
    t0 = SVector(rand(rng, 1:sz[1]), rand(rng, 1:sz[2]))
    while blocked[t0...] || t0 == r1 || t0 == r2
        t0 = SVector(rand(rng, 1:sz[1]), rand(rng, 1:sz[2]))
    end

    initial = @ConditionalDist @NamedTuple{s::TagState} begin
        # Deterministic:
        support(; ) = (; s = TagState(r1, r2, t0))
        pdf(x; )    = (x == (; s = TagState(r1, r2, t0)) ? 1.0 : 0.0)
        rand(rng; ) = (; s = TagState(r1, r2, t0))
        # In case we want uniform initial?
    end

    transition = @ConditionalDist TagState begin
        function support(; s, a)
            if isnothing(s) || isnothing(a)
                els = map(Iterators.product(1:size[1], 1:size[2], 
                                            1:size[1], 1:size[2], 
                                            1:size[1], 1:size[2])) do (x1, y1, x2, y2, xt, yt)
                    TagState(
                        SVector((x1, y1)),
                        SVector((x2, y2)),
                        SVector((xt, yt)),
                    )
                end
                return FiniteSpace(els)
            end

            # robot moves (deterministic)
            new_r1 = move_robot(sz, blocked, s.r1, a[1])
            new_r2 = move_robot(sz, blocked, s.r2, a[2])

            # capture right after robot move → only Terminal possible
            if (new_r1 == s.t) || (new_r2 == s.t)
                return (Terminal(),)
            end

            # otherwise target random-walks uniformly over candidates
            cands = target_candidates(sz, blocked, s.t)
            # Split candidate moves into those that cause capture and those that don't
            captured = [t′ for t′ in cands if (new_r1 == t′) || (new_r2 == t′)]
            safe     = [t′ for t′ in cands if (new_r1 != t′) && (new_r2 != t′)]

            # Support includes Terminal (if any captured moves) and all nonterminal next states
            outs = Any[]
            if !isempty(captured)
                push!(outs, Terminal())
            end
            append!(outs, [TagState(new_r1, new_r2, t′) for t′ in safe])
            Tuple(outs)
        end

        function pdf(sp; s, a)
            new_r1 = move_robot(sz, blocked, s.r1, a[1])
            new_r2 = move_robot(sz, blocked, s.r2, a[2])

            # Immediate capture after robot move
            if (new_r1 == s.t) || (new_r2 == s.t)
                return sp isa Terminal ? 1.0 : 0.0
            end

            cands = target_candidates(sz, blocked, s.t)
            n = length(cands)                        # uniform over candidates
            captured = count(t′ -> (new_r1==t′) || (new_r2==t′), cands)

            if sp isa Terminal
                return captured / n
            else
                # sp must be TagState(new_r1,new_r2,t′) for some t′ not captured
                (sp isa TagState) || return 0.0
                (sp.r1 == new_r1 && sp.r2 == new_r2 && sp.t ∈ cands && sp.t != new_r1 && sp.t != new_r2) || return 0.0
                return 1.0 / n
            end
        end

        function rand(rng; s, a)
            new_r1 = move_robot(sz, blocked, s.r1, a[1])
            new_r2 = move_robot(sz, blocked, s.r2, a[2])

            # Immediate capture after robot move
            if (new_r1 == s.t) || (new_r2 == s.t)
                return Terminal()
            end

            cands = target_candidates(sz, blocked, s.t)
            t′ = cands[Random.rand(rng, 1:length(cands))]  # uniform random-walk
            ((new_r1 == t′) || (new_r2 == t′)) ? Terminal() : TagState(new_r1, new_r2, t′)
        end
    end

    # Replace your cooperative `reward` with this
    reward = @ConditionalDist Float64 begin
        function rand(rng; s, a, sp, i)
            R = 100.0

            # Post-robot positions (deterministic given s,a)
            new_r1 = move_robot(sz, blocked, s.r1, a[1])
            new_r2 = move_robot(sz, blocked, s.r2, a[2])

            # Agent 1's expected payoff (agent 2 gets the negative)
            ev1 = if new_r1 == s.t && new_r2 == s.t
                # both landed on the target simultaneously -> symmetric tie
                0.0
            elseif new_r1 == s.t
                +R                       # immediate capture by agent 1
            elseif new_r2 == s.t
                -R                       # immediate capture by agent 2
            else
                ev1 = 0.0                     # no tag yet
            end

            return (i == 1 ? ev1 : -ev1)
        end
    end

    # ---- Per-agent action space (plated node a[i]) ----
    a_space = FiniteSpace((Left, Right, Up, Down, Stay))

    MG(DiscountedReward(0.99), initial, (; i = 2);
       a = a_space,
       sp = transition,
       r  = reward)
end


#=

######################################################
# Use case 3: Fictitious play via problem transformations
######################################################

using Decisions 

# Average (uniform) over a vector of ConditionalDist policies, state-wise.
function empirical_policy(policies::Vector{ConditionalDist})
    @ConditionalDist Decisions.DecisionDomains.TagAct begin
        rand(rng; s) = begin
            j = rand(rng, 1:length(policies))          # sample a past policy uniformly
            rand(rng, policies[j]; s=s)                 # then sample its action at state s
        end
        pdf(x; s) = mean(π -> pdf(π, x; s=s), policies) # state-conditioned average density
        support(; s) = support(policies[1]; s=s)        # assume identical supports
    end
end

mg = Decisions.DecisionDomains.TagAdversarial(size=(5,5))
mg_exploded = mg |> IndexExplode(:i)

# Uniform random policy (per state)
π_rand = @ConditionalDist Decisions.DecisionDomains.TagAct begin
    rand(rng; s) = rand(rng, collect(support(mg[:a]; s=s)))
    pdf(x; s) = 1 / length(collect(support(mg[:a]; s=s)))
    support(; s) = support(mg[:a]; s=s)
end

π1_hist = ConditionalDist[]            # past BRs for P1
π2_hist = ConditionalDist[]            # past BRs for P2
π1_avg  = π_rand
π2_avg  = π_rand

solver = Decisions.DecisionAlgorithms.ValueIteration(0.99)

K = 100
for k in 1:K
    # --- Best response for Player 1 against Player 2's *average* ---
    mdp1 = mg_exploded               |>
           Implement(; a_2 = π2_avg) |>
           MergeForward(:r_2, :a_2)  |>
           Rename(; a_1=:a, r_1=:r)

    println("FSP Iteration $k")
    sol1 = solve(solver, mdp1)
    π1_br = sol1.a                         # <-- the BR policy
    push!(π1_hist, π1_br)
    π1_avg = empirical_policy(π1_hist)     # update average

    # --- Best response for Player 2 against Player 1's *average* ---
    mdp2 = mg_exploded               |>
           Implement(; a_1 = π1_avg) |>
           MergeForward(:r_1, :a_1)  |>
           Rename(; a_2=:a, r_2=:r)

    sol2 = solve(solver, mdp2)
    π2_br = sol2.a
    push!(π2_hist, π2_br)
    π2_avg = empirical_policy(π2_hist)
end

# Final FSP policies to *play/evaluate* are π1_avg, π2_avg.


=#