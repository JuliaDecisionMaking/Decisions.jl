function TagCooperative(; size=(2,2), n_obstacles=1, rng=MersenneTwister(20))
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

    reward = @ConditionalDist Float64 begin
        function rand(rng; s, a, sp, i)
            captured = (sp isa Terminal)
            step_cost(ai::TagAct) = (ai == Stay ? -2.0 : -1.0)
            base = step_cost(a[1]) + step_cost(a[2])
            captured ? (100.0 + base) : base
        end
        # `support` and `pdf` are optional for rewards; omitted for brevity.
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

function empirical_policy(π_v)
    @ConditionalDist Decisions.DecisionDomains.TagAct begin
        rand(rng; s) = rand(rng, rand(rng, π_v))
        pdf(x; s) = sum(π_v) do πi
            pdf(πi, x)
        end / length(π_v)
        support(; s) = support(mg[:a])
    end
end

mg = Decisions.DecisionDomains.TagCooperative()

π_rand = @ConditionalDist Decisions.DecisionDomains.TagAct begin
    rand(rng; s) = rand(rng, [support(mg[:a])...])  # uniform π₂(a₂ | s)
    pdf(x; s) = 1 / length([support(mg[:a])...])
    support(; s) = support(mg[:a])
end

π1 = π_rand
π2 = π_rand
mg_exploded = mg |> IndexExplode(:i)

π1_v = ConditionalDist[]
π2_v = ConditionalDist[]

solver = Decisions.DecisionAlgorithms.ValueIteration(1)

for i ∈ 1:10

    println("Iteration $i")
    # Player 1
    mdp = mg_exploded               |> 
            Implement(;a_2=π2)      |> 
            MergeForward(:r_2,:a_2) |> 
            Rename(;a_1=:a,r_1=:r)

    (; a) = solve(solver, mdp)
    π1_v = [π1_v; π1]
    π1 = empirical_policy(π1_v)


    # Player 2
    mdp = mg_exploded               |> 
            Implement(;a_1=π1)      |> 
            MergeForward(:r_1,:a_1) |> 
            Rename(;a_2=:a,r_2=:r)

    (; a) = solve(solver, mdp)
    π2_v = [π2_v; π2]
    π2 = empirical_policy(π2_v)
end

=#