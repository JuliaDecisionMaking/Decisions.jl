## Decisions.jl -> POMDPs.jl

struct WrappedMDP{P<:MDP, S, A} <: POMDPs.MDP{S, A}
    p::P
    function WrappedMDP(p::MDP)
        return new{typeof(p), POMDPs.statetype(p), POMDPs.actiontype(p)}(p)
    end
end

struct WrappedPOMDP{P<:POMDP, S, A, O} <: POMDPs.POMDP{S, A, O}
    p::P
    function WrappedPOMDP(p::POMDP)
        return new{typeof(p), POMDPs.statetype(p), POMDPs.actiontype(p), POMDPs.obstype(p)}(p)
    end
end

POMDPs.MDP(m::MDP) = WrappedMDP(m)
POMDPs.POMDP(m::POMDP) = WrappedPOMDP(m)

const WrappedProblem{S,A} = Union{WrappedMDP{S,A}, WrappedPOMDP{S,A}} where {S,A}

# lots of assumptions, not general

POMDPs.initialstate(p::WrappedProblem) = pomdp_initialstate(p.p)
POMDPs.transition(p::WrappedProblem, s, a) = pomdp_transition(p.p, s, a)
POMDPs.observation(p::WrappedPOMDP, s, a, sp) = pomdp_observation(p.p, s, a, sp) # FIXME: assumes s,a,sp dependence
POMDPs.states(p::WrappedProblem) = support(p.p[:s])
POMDPs.actions(p::WrappedProblem) = support(p.p[:a]) # FIXME: assumes no state-dependent action space
POMDPs.observations(p::WrappedPOMDP) = support(p.p[:o])
POMDPs.discount(p::WrappedProblem) = p.p.objective.discount
POMDPs.reward(p::WrappedProblem, s, a) =  p.p[:r](; s, a) # FIXME: assumes rewards dependent only on s,a and deterministic


#### There's probably a much cleaner way to generate these distributions ####

function to_pomdp_distribution(d, support; kwargs...)
    return POMDPTools.ImplicitDistribution() do rng
        d(rng; kwargs...)
    end
end

function to_pomdp_distribution(d, support::FiniteSpace; kwargs...)
    p = map(support) do x
        pdf(d, x; kwargs...)
    end
    return POMDPTools.SparseCat(support, p)
end

function to_pomdp_distribution(d, support::SingletonSpace; kwargs...)
    return POMDPTools.Deterministic(support.el)
end

pomdp_initialstate(p::Union{MDP, POMDP}) = to_pomdp_distribution(p.initial, support(p.initial).s) # FIXME: this prob breaks if support isn't implemented
pomdp_transition(p::Union{MDP, POMDP}, s, a) = to_pomdp_distribution(p[:sp], support(p[:sp]; s, a); s, a)
pomdp_observation(p::POMDP, s, a, sp) = to_pomdp_distribution(p[:o], support(p[:o]; s, a, sp); s, a, sp)

POMDPs.statetype(m::Union{MDP, POMDP}) = eltype(m[:s])
POMDPs.actiontype(m::Union{MDP, POMDP}) = eltype(m[:a])
POMDPs.obstype(m::Union{MDP, POMDP}) = eltype(m[:o])


## POMDPs.jl -> Decisions.jl

function pomdps_transition(m::Union{POMDPs.MDP{S,A}, POMDPs.POMDP{S,A}}) where {S, A}
    return @ConditionalDist S begin
        function support(; s, a)
            if isnothing(s) && isnothing(a)
                return POMDPs.states(m)
            else
                POMDPs.support(POMDPs.transition(m, s, a))
            end
        end

        function rand(rng; s, a)
            POMDPs.@gen(:sp)(m, s, a, rng)
        end

        function pdf(sp; s, a)
            POMDPs.pdf(POMDPs.transition(m, s, a), sp)
        end
    end
end

function pomdps_reward(m::Union{POMDPs.MDP{S,A}, POMDPs.POMDP{S,A}}) where {S, A}
    return @ConditionalDist Float64 begin
        function rand(rng; s, a, sp)
            POMDPs.reward(m, s, a, sp)
        end
    end
end

function pomdps_observation(m::POMDPs.POMDP{S,A,O}) where {S, A, O}
    return @ConditionalDist O begin
        function support(; s, a, sp)
            if isnothing(s) && isnothing(a)
                return POMDPs.observations(m)
            else
                POMDPs.support(POMDPs.observation(m, s, a, sp))
            end
        end

        function rand(rng; s, a, sp)
            POMDPs.@gen(:o)(m, s, a, sp, rng)
        end

        function pdf(o; s, a, sp)
            POMDPs.pdf(POMDPs.observation(m, s, a, sp), o)
        end
    end
end

function pomdps_initialstate(m::Union{POMDPs.MDP{S}, POMDPs.POMDP{S}}) where S
    return @ConditionalDist @NamedTuple{s::S} begin
        function rand(rng)
            (;s=rand(rng, POMDPs.initialstate(m)))
        end
        function support() # Not sure if this is how it's meant to be implemented
            (;s=POMDPs.support(POMDPs.initialstate(m)))
        end
    end
end

function DecisionProblems.MDP(pomdp::POMDPs.MDP)
    return DecisionProblems.MDP(
        DiscountedReward(POMDPs.discount(pomdp), pomdps_initialstate(pomdp));
        sp = pomdps_transition(pomdp),
        r = pomdps_reward(pomdp),
        a = POMDPs.actions(pomdp)
    )
end

function DecisionProblems.POMDP(pomdp::POMDPs.POMDP)
    return DecisionProblems.POMDP(
        DiscountedReward(POMDPs.discount(pomdp), pomdps_initialstate(pomdp));
        sp = pomdps_transition(pomdp),
        o = pomdps_observation(pomdp),
        r = pomdps_reward(pomdp),
        a = POMDPs.actions(pomdp)
    )
end
