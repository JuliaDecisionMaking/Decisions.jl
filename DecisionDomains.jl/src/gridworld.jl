struct GridPointSpace <: Space{Tuple{Int, Int}}
    nrows::Int
    ncols::Int
end

Base.in(p::Tuple{Int, Int}, g::GridPointSpace) =
    (p[1] <= g.nrows) && (p[2] <= g.ncols) && (p[1] > 0) && (p[2] > 0)

Base.length(g::GridPointSpace) = g.nrows * g.ncols
Base.iterate(g::GridPointSpace) = iterate(Iterators.product(1:g.nrows, 1:g.ncols))
Base.iterate(g::GridPointSpace, state) = iterate(Iterators.product(1:g.nrows, 1:g.ncols), state)

@enum Cardinal NORTH EAST SOUTH WEST

function is_in_bounds(p, nrows, ncols)
    (p[1] <= nrows) && (p[2] <= ncols) && (p[1] > 0) && (p[2] > 0)
end

function rel_dirs(s, a)
    (forward, left, right) = if a == NORTH
        (s[1]-1, s[2]), (s[1], s[2]-1), (s[1], s[2]+1)
    elseif a == EAST
        (s[1], s[2]+1), (s[1]-1, s[2]), (s[1]+1, s[2])
    elseif a == SOUTH
        (s[1]+1, s[2]), (s[1], s[2]+1), (s[1], s[2]-1)
    elseif a == WEST
        (s[1], s[2]-1), (s[1]+1, s[2]), (s[1]-1, s[2])
    end
    (forward, left, right, s)
end

function Iceworld(; p_slip=0.1, nrows=5, ncols=5, holes=[], target=(5,5))
    transition = @ConditionalDist Tuple{Int, Int} begin
        function support(; s, a)
            if isnothing(s) && isnothing(a)
                GridPointSpace(nrows, ncols)
            else
                if s == target
                    FiniteSpace([terminal]) # TODO: Could productively specialize
                else
                FiniteSpace(
                    [d for d in rel_dirs(s, a) if is_in_bounds(d, nrows, ncols)]
                )
                end
            end
        end

        function rand(rng; s, a)
            if s == target
                return Terminal()
            end

            forward, left, right, stay = rel_dirs(s, a)
            p_f = is_in_bounds(forward, nrows, ncols) ? (1-p_slip) : 0.0
            p_l = is_in_bounds(left,    nrows, ncols) ? (p_slip/2) : 0.0
            p_r = is_in_bounds(right,   nrows, ncols) ? (p_slip/2) : 0.0

            r = rand(rng)
            r > p_f             || return forward
            r > p_f + p_r       || return right
            r > p_f + p_r + p_l || return left
            stay
        end

        function logpdf(sp; s, a)
            is_in_bounds(sp, nrows, ncols) || return -Inf
            s == target && return -Inf
            
            forward, left, right, stay = rel_dirs(s, a)
            p_f = is_in_bounds(forward, nrows, ncols) ? (1-p_slip) : 0.0
            p_l = is_in_bounds(left,    nrows, ncols) ? (p_slip/2) : 0.0
            p_r = is_in_bounds(right,   nrows, ncols) ? (p_slip/2) : 0.0
            p_s = 1 - (p_f + p_l + p_r)
            sp == forward && return log(p_f)
            sp == left    && return log(p_l)
            sp == right   && return log(p_r)
            log(p_s)
        end
    end

    reward = @ConditionalDist Float64 begin
        function rand(rng; s, a, sp)
            if s == target
               10
            elseif s ∈ holes
                -20
            else 
                -0.001
            end
        end
    end

    initial_state = @ConditionalDist @NamedTuple{s::Tuple{Int, Int}} begin
        function rand(rng)
            (;s=(1, 1))
        end
    end

    DecisionProblems.MDP(DiscountedReward(0.99), initial_state;
        sp=transition,
        r=reward,
        a=FiniteSpace([NORTH, SOUTH, EAST, WEST])
    )
end


#=

policy = @ConditionalDist Cardinal begin
    rand(rng; s) = rand(rng, support(prob[:a]))   # uniform random
end

struct RandomSolver <: DecisionAlgorithm
end

function DecisionProblems.solve(alg::RandomSolver, prob::DecisionProblem)
    action_type = eltype(prob[:a])
    pol = @ConditionalDist action_type begin
        function rand(rng; s)
            rand([DecisionNetworks.support(prob[:a])...])
        end
    end
    (; a = pol)
end

function run_episode(;max_steps=10)
    prob = Iceworld()
    steps = 0
    simulate!(RandomSolver(), prob) do vals
        println(vals)
        steps +=1
        steps >= max_steps
    end
end


run_episode()

=#