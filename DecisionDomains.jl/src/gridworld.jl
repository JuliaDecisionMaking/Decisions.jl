const GWPos = SVector{2, Int}

struct GridPointSpace <: Space{GWPos}
    nrows::Int
    ncols::Int
end

Base.in(p::GWPos, g::GridPointSpace) = (0 < p[1] ≤ g.nrows) && (0 < p[2] ≤ g.ncols)
Base.length(g::GridPointSpace) = g.nrows * g.ncols
Base.iterate(g::GridPointSpace) = iterate(
    Iterators.map(GWPos, Iterators.product(1:g.nrows, 1:g.ncols))
)
Base.iterate(g::GridPointSpace, state) = iterate(
    Iterators.map(GWPos, Iterators.product(1:g.nrows, 1:g.ncols)), state
)

@enum Cardinal NORTH EAST SOUTH WEST

is_in_bounds(p, nrows, ncols) = (0 < p[1] ≤ nrows) && (0 < p[2] ≤ ncols)

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

function Iceworld(; p_slip=0.30, nrows=10, ncols=10, holes, target=GWPos(7,7))
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

    MDP(DiscountedReward(0.99), initial_state;
        sp=transition,
        r=reward,
        a=FiniteSpace([NORTH, SOUTH, EAST, WEST])
    )
end

_gw_support(::Nothing, ::Nothing, target, nrows, ncols) = GridPointSpace(nrows, ncols)
function _gw_support(s, a, target, nrows, ncols)
    return if s == target
        FiniteSpace([terminal]) # TODO: Could productively specialize
    else
        FiniteSpace(
            [d for d in rel_dirs(s, a) if is_in_bounds(d, nrows, ncols)]
        )
    end
end

function GridWorld(; 
        nrows = 10, ncols = 10, 
        rewards         = Dict(
            (4,3) => -10.0, 
            (4,6) => -5.0, 
            (9,3) => 10.0, 
            (8,8) => 3.0
        ), 
        terminate_from  = Set(keys(rewards)),
        tprob = 0.70
    )
    mdp = (; nrows, ncols, rewards, terminate_from, tprob) # me desperately wanting the mdp as an object
    transition = @ConditionalDist GWPos begin
        function support(; s, a) # what if we want multiple methods for `support`? Can't dispatch on kwargs...
            if isnothing(s) && isnothing(a)
                GridPointSpace(nrows, ncols)
            else
                if s ∈ terminate_from
                    FiniteSpace([terminal]) # TODO: Could productively specialize
                else
                FiniteSpace(
                    gw_destinations(mdp, s)
                    # [d for d in rel_dirs(s, a) if is_in_bounds(d, nrows, ncols)]
                )
                end
            end
        end

        function rand(rng; s, a)
            states, probs = gw_transition((; nrows, ncols, terminate_from, rewards), s, a)
            r = sum(probs)*rand(rng)
            tot = zero(eltype(probs))
            for (s, p) in zip(states, probs)
                tot += p
                if r < tot
                    return s
                end
            end
        end

        function pdf(sp; s, a)
            states, probs = gw_transition(mdp, s, a)
            idx = findfirst(==(sp), states)
            return isnothing(idx) ? zero(eltype(probs)) : probs[idx]
        end
    end

    reward = @ConditionalDist Float64 begin
        function rand(rng; s, a, sp)
            get(rewards, s, 0.0)
        end
    end

    initial_state = @ConditionalDist @NamedTuple{s::GWPos} begin
        function rand(rng)
            (;s=SA[1,1])
        end
        function support() # Not sure if this is how it's meant to be implemented
            (;s=[SA[1,1]])
        end
    end

    MDP(DiscountedReward(0.99), initial_state;
        sp=transition,
        r=reward,
        a=FiniteSpace(collect(instances(Cardinal)))
    )
end

const DIR = Dict(
    NORTH => SA[0,1],
    EAST => SA[1,0],
    SOUTH => SA[0,-1],
    WEST => SA[-1, 0]
)

function gw_destinations(mdp::NamedTuple, s)
    A = instances(Cardinal)
    destinations = MVector{length(A)+1, GWPos}(undef)
    destinations[1] = s
    for (i, act) in enumerate(A)
        dest = s + DIR[act]
        destinations[i+1] = dest
    end
    return filter(destinations) do s
        inbounds(s, mdp.nrows, mdp.ncols)
    end
end

function gw_transition(mdp::NamedTuple, s::AbstractVector{Int}, a::Cardinal)
    if s in mdp.terminate_from || isterminal(s)
        return terminal
    end
    A = instances(Cardinal)

    destinations = MVector{length(A)+1, GWPos}(undef)
    destinations[1] = s

    probs = @MVector(zeros(length(A)+1))
    for (i, act) in enumerate(A)
        if act == a
            prob = mdp.tprob # probability of transitioning to the desired cell
        else
            prob = (1.0 - mdp.tprob)/(length(A) - 1) # probability of transitioning to another cell
        end

        dest = s + DIR[act]
        destinations[i+1] = dest

        if !inbounds(dest, mdp.nrows, mdp.ncols) # hit an edge and come back
            probs[1] += prob
            destinations[i+1] = GWPos(-1, -1) # dest was out of bounds - this will have probability zero, but it should be a valid state
        else
            probs[i+1] += prob
        end
    end

    return convert(SVector, destinations), convert(SVector, probs)
end

inbounds(s::AbstractVector{Int}, nrows::Int, ncols::Int) = (0 < s[1] ≤ nrows) && 0 < s[2] ≤ ncols
