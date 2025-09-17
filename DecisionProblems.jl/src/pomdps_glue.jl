struct WrappedMDP{P<:MDP, S, A} <: POMDPs.MDP{S, A}
    p::P
    function WrappedMDP(p::MDP)
        return new{typeof(p), infer_statetype(p), infer_actiontype(p)}(p)
    end
end

struct WrappedPOMDP{P<:POMDP, S, A, O} <: POMDPs.POMDP{S, A, O}
    p::P
    function WrappedPOMDP(p::POMDP)
        return new{typeof(p), infer_statetype(p), infer_actiontype(p), infer_obstype(p)}(p)
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

## TRANSITION

function pomdp_transition(mdp::Union{MDP, POMDP}, s, a)
    T = mdp[:sp]
    SP = support(T; s, a)
    return transition(T, SP, s, a)
end

function transition(T, SP, s, a)
    return ImplicitDistribution() do rng
        T(rng; s, a)
    end
end

function transition(T, SP::FiniteSpace, s, a)
    p = map(SP) do sp
        pdf(T, sp; s, a)
    end
    return POMDPTools.SparseCat(SP, p)
end

function transition(T, SP::SingletonSpace, s, a)
    return POMDPTools.Deterministic(SP.el)
end

## OBSERVATION

function pomdp_observation(pomdp::POMDP, s, a, sp)
    O = pomdp[:o]
    OS = support(O; s, a, sp)
    return observation(O, OS, s, a, sp)
end

function observation(O, OS, s, a, sp)
    return POMDPTools.ImplicitDistribution() do rng
        O(rng; s, a, sp)
    end
end

function observation(O, OS::FiniteSpace, s, a, sp)
    p = map(OS) do o
        pdf(O, o; s, a, sp)
    end
    return POMDPTools.SparseCat(OS, p)
end

function observation(O, OS::SingletonSpace, s, a, sp)
    return POMDPTools.Deterministic(OS.el)
end

## INITIALSTATE

function pomdp_initialstate(p::Union{MDP,POMDP})
    S = p.initial
    SS = support(S)
    return initialstate(S, SS)
end

function initialstate(S, SS)
    return POMDPTools.ImplicitDistribution() do rng
        S(rng)
    end
end

function initialstate(S, SS::FiniteSpace)
    p = map(SS) do s
        pdf(S, s)
    end
    return POMDPTools.SparseCat(SS, p)
end

function initialstate(S, SS::SingletonSpace)
    return POMDPTools.Deterministic(SS.el)
end


## FIXME: should be a way to do this only working with types like Base.return_types

function infer_statetype(m::Union{MDP, POMDP})
    return eltype(support(m[:s]))
end

function infer_actiontype(m::Union{MDP, POMDP})
    return eltype(support(m[:a]))
end

function infer_obstype(m::Union{MDP, POMDP})
    return eltype(support(m[:o]))
end
