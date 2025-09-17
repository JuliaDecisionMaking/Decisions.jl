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
    return ImplicitDistribution() do rng
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

pomdp_initialstate(p::Union{MDP, POMDP}) = to_pomdp_distribution(p[:s], support(p[:s]))
pomdp_transition(p::Union{MDP, POMDP}, s, a) = to_pomdp_distribution(p[:sp], support(p[:sp]; s, a); s, a)
pomdp_observation(p::POMDP, s, a, sp) = to_pomdp_distribution(p[:o], support(p[:o]; s, a, sp); s, a, sp)

POMDPs.statetype(m::Union{MDP, POMDP}) = eltype(m[:s])
POMDPs.actiontype(m::Union{MDP, POMDP}) = eltype(m[:a])
POMDPs.obstype(m::Union{MDP, POMDP}) = eltype(m[:o])
