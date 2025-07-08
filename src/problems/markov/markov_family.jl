
"""
    ```
    _markov_structure(
        N::Type{<:Multiagency},
        Z::Type{<:Observability},
        C::Type{<:Centralization},
        M::Type{<:MemoryPresence},
        R::Type{<:RewardConditioning})
    ```

Build the decision network for a Markov problem with the given traits.

This is only used to define the Markov family. Prefer `structure(ProblemName)`.
""" 
function _markov_structure(
    N::Multiagency,
    Z::Observability,
    C::Centralization,
    M::MemoryPresence,
    R::RewardConditioning
)

    # TODO: All of these add either one or zero nodes; push! is the wrong way to go
    nodes = Pair[]
    push!(nodes, mkv_stt(N)...)
    push!(nodes, mkv_act(N, Z, C, M)...)
    push!(nodes, mkv_rwd(N, R)...)
    push!(nodes, mkv_obs(Z, C)...)
    push!(nodes, mkv_mem(M, Z, C)...)
    NamedTuple(nodes)
end

_markov_dynamism(::MemoryAbsent)  = (; s=:sp)
_markov_dynamism(::MemoryPresent) = (; s=:sp, m=:mp)

# macro rewards_from(cond, call::Expr)
#     call.args[1] = :($prob |> Recondition(; r=$cond))
#     call
# end

"""
    MarkovProblem(
        N::Multiagency,
        Z::Observability,
        C::Centralization,
        M::Union{MemoryPresence, Nothing},
        R::Union{RewardConditioning, Nothing})

Define a type of Markov problem from a set of characteristic traits.

The minimal Wray class decision network that captures the traits is used.
Many common Markov problem types are ambiguous with respect to memory presence and reward
conditioning, so providing `nothing` for these traits yields a `Union` over all possible
decision networks. (This allows e.g. `POMDP` to refer to all POMDPs, regardless of the
conditioning of the reward or presence of the memory node.)
"""
function MarkovProblem(
    N::Multiagency,
    Z::Observability,
    C::Centralization,
    M::Union{MemoryPresence, Nothing},
    R::Union{RewardConditioning, Nothing})

    memory_options = if isnothing(M)
        [MemoryAbsent(), MemoryPresent()]
    else [M] end

    types = []
    for mem in memory_options
        reward_options = if isnothing(R)
            # TODO: Hack for getting the node names - reward conditioning doesn't affect
            #  them so we can just assume an arbitrary one
            nodes = [:s, keys(_markov_structure(N, Z, C, mem, NoReward()))...]
            
            # Special cases: 
            # (1) We assume the reward is not conditioned on memory
            #   except in explicitly named cases - that is, rho-problems
            # (2) The reward can't be conditioned on itself or other rewards
            # (3) The reward can't be conditioned on slacks
            nodes = filter(nodes) do idx
                ! ('r' in string(idx) || 'm' in string(idx) || 'c' in string(idx))
            end

            # Powerset
            result = Tuple[()]
            for elem in nodes, j in eachindex(result)
                push!(result, (result[j]..., elem))
            end
            map((rwd) -> ConditionedOn{rwd}(), result)
        else [R] end

        for rwd in reward_options
            structure = _markov_structure(N, Z, C, mem, rwd)
            dynamism = _markov_dynamism(mem)
            graph = DecisionGraph(structure, dynamism)
            push!(types, DecisionNetwork{typeof(graph)})
        end
    end

    Union{types...}
end

# """
#     MarkovProblem(N, Z, C, M, R)

# Representation of decision problems in the Markov family.

# # Type parameters
# - 'N <: Multiagency': No-, single-, or multi-agent
# - 'Z <: Observability': Partially or fully observable
# - 'C <: Centralization': Centralized or decentralized (assumed centralized for 
#   non-multi-agent problems)
# - 'M <: MemoryPresence': Whether memory nodes are included (carrying beliefs,
#   agent internal state, etc). Present by default.
# - 'R <: RewardConditioning': Variables which condition the reward node (if one is present).
#   By default, matches `behavior[:r]`. 

# See also [`ProblemTrait`](@ref).
# """

"""
    `@def_markov NAME Multiagency Observability Centralization MemoryPresence
    RewardConditioning`

Name a specific type of MarkovProblem with the given traits, and make a corresponding
constructor.

This creates an alias for a MarkovProblem with the specified traits. The
constructor accepts conditional distributions in the following order: transition,
observation, reward, sojourn time, slack. Only the distributions needed to specify the
problem are included.

Memory presence and reward conditioning can remain unspecified using `Any`. In this case,
they are type parameters on the aliased name. In the constructor, they default to
[`default_mkv_memory_presence`](@ref) and [`default_mkv_reward_conditioning`](@ref).

# Examples
```jldoctest
@def_markov MyMDP   SingleAgent     FullyObservable     Centralized Any Any

@def_markov MRP   NoAgent     FullyObservable     Centralized Any Any
```
"""
macro def_markov(name, traits...)
    mem_presence_defined = (traits[4] != :Any)
    reward_cond_defined  = (traits[5] != :Any)

    multiagency         = traits[1]
    observability       = traits[2]
    centralization      = traits[3]
    memory_presence     = (mem_presence_defined ? traits[4] : (() -> nothing))
    reward_conditioning = (reward_cond_defined  ? traits[5] : (() -> nothing))

    # TODO: There should absolutely not be an eval here
    network_type = @eval begin
        MarkovProblem(
            $multiagency(),
            $observability(),
            $centralization(),
            $memory_presence(),
            $reward_conditioning()
        )
    end

    problem_type_quot = Meta.quot(network_type)


    # hack; brittle to changes in trait names
    required_nodes = Symbol[
        :sp
        (observability == :FullyObservable) ? [] : :o
        (reward_conditioning == :NoReward) ? [] : :r
    ]

    nodename_map = (; 
        sp = :transition,
        o = :observation,
        r = :reward,
        a = :action_space,
        mp = :memory_space
    )
    required_names = values(nodename_map[required_nodes])
    required_nodes_doublequote = Tuple(required_nodes) # what have we done
    required_names_expr = Expr(:tuple, required_names...)

    if ! mem_presence_defined 
        memory_presence = :(Decisions.default_mkv_memory_presence())
    end
    if ! reward_cond_defined 
        reward_conditioning = :(Decisions.default_mkv_reward_conditioning(reward))
    end

    action_support_to_dist = (:a in required_nodes) ? :(action_space = EmptyDist(action_space)) : :()
    memory_support_to_dist = (:m in required_nodes) ? :(memory_space = EmptyDist(memory_space)) : :()

    quote
        Core.@__doc__ const $name = $problem_type_quot 

        function (::Type{$problem_type_quot})($(required_names...))
            behavior = NamedTuple{$required_nodes_doublequote}($required_names_expr)
            $action_support_to_dist
            $memory_support_to_dist
            MarkovProblem(
                $multiagency(),
                $observability(),
                $centralization(),
                ($memory_presence)(),
                ($reward_conditioning)()
            )(behavior)
        end
        
        Multiagency(::Type{$problem_type_quot}) = $multiagency()
        Observability(::Type{$problem_type_quot}) = $observability()
        Centralization(::Type{$problem_type_quot}) = $centralization()
    end |> esc
end

# TODO: Refactor traits for Markov problems into a nontyped regime
# Multiagency(::MarkovProblem{N,Z,C,M,R}) where {N,Z,C,M,R} = N()
# Observability(::MarkovProblem{N,Z,C,M,R}) where {N,Z,C,M,R} = Z()
# Centralization(::MarkovProblem{N,Z,C,M,R}) where {N,Z,C,M,R} = C()
# MemoryPresence(::MarkovProblem{N,Z,C,M,R}) where {N,Z,C,M,R} = M()
# RewardConditioning(::MarkovProblem{N,Z,C,M,R}) where {N,Z,C,M,R} = R()

# But not all problem traits are required to define a Markov family problem.
#   (Of course not; there are infinitely many possible ones.)
#   We can provide hints for the other traits in a more ordinary manner.
# Sequentiality(::MarkovProblem) = Simultaneous()


# The idea here is to dispatch on traits to build up the DN. That way, any named problem
#   can just be defined in terms of its traits. 
# TODO: I wonder if there's a principled ordering to traits in these builder functions.

# The RewardConditioning trait explicitly carries the names of the values the reward
#   is conditioned on. This is unique from other nodes because of the ambiguity in the
#   way reward functions are defined.
"""
    function mkv_rwd(::Multiagency, ::RewardConditioning) end
"""
const NotCompetitive = Union{NoAgent, SingleAgent, Cooperative} 
mkv_rwd(_, ::NoReward) = []
mkv_rwd(::NotCompetitive, ::ConditionedOn{nodes}) where nodes = [:r => nodes]
mkv_rwd(::Competitive, ::ConditionedOn{nodes}) where nodes = [:(r[i]) => nodes]



"""
    function mkv_act(::Multiagency, ::Observability, ::Centralization, ::MemoryPresence) end
"""
mkv_act(::NoAgent,_, _, _) = []
mkv_act(::SingleAgent,::FullyObservable,    _,::MemoryAbsent)  = [:a => (:s,)]
mkv_act(::SingleAgent,::FullyObservable,    _,::MemoryPresent) = [:a => (:s, :m,)]
mkv_act(::SingleAgent,::PartiallyObservable,_,::MemoryAbsent)  = [:a => (:o,)]
mkv_act(::SingleAgent,::PartiallyObservable,_,::MemoryPresent) = [:a => (:o, :m)]

mkv_act(::MultiAgent,::FullyObservable,    _,              ::MemoryAbsent)  = [:(a[i]) => (:s,)]
mkv_act(::MultiAgent,::FullyObservable,    ::Centralized,  ::MemoryPresent) = [:(a[i]) => (:s, :m,)]
mkv_act(::MultiAgent,::FullyObservable,    ::Decentralized,::MemoryPresent) = [:(a[i]) => (:s, :(m[i]),)]
mkv_act(::MultiAgent,::PartiallyObservable,::Centralized,  ::MemoryAbsent)  = [:(a[i]) => (:o,)]
mkv_act(::MultiAgent,::PartiallyObservable,::Centralized,  ::MemoryPresent) = [:(a[i]) => (:o, :m,)]
mkv_act(::MultiAgent,::PartiallyObservable,::Decentralized,::MemoryAbsent)  = [:(a[i]) => (:(o[i]),)]
mkv_act(::MultiAgent,::PartiallyObservable,::Decentralized,::MemoryPresent) = [:(a[i]) => (:(o[i]), :(m[i]),)]


# Only three options for observation, depending on centralization (and whether there
#   are observations at all).
"""
    function mkv_obs(::Observability, ::Centralization) end
"""
mkv_obs(::FullyObservable, _) = []
mkv_obs(::PartiallyObservable, _)               = [:o       => (:s,)]
mkv_obs(::PartiallyObservable, ::Decentralized) = [:(o[i])  => (:s,)]


# There are five possible memory configurations:
#   Either fully or partially observable (determines whether state or obs is added),
#   and either centralized or decentralized (determines how many memories there are),
#   and one degenerate case where memory is absent entirely.
"""
    function mkv_mem(::MemoryPresence, ::Observability, ::Centralization) end
"""
mkv_mem(::MemoryAbsent, _, _) = []
mkv_mem(::MemoryPresent,::PartiallyObservable,::Centralized)   = [:mp => (:m, :o, :a)]
mkv_mem(::MemoryPresent,::FullyObservable,    ::Centralized)   = [:mp => (:m, :s, :a)]
mkv_mem(::MemoryPresent,::PartiallyObservable,::Decentralized) = [:(mp[i]) => (:(m[i]), :(o[i]), :(a[i]))]
mkv_mem(::MemoryPresent,::FullyObservable,    ::Decentralized) = [:(mp[i]) => (:(m[i]), :s, :(a[i]))]


# Finally, the state node is always present. It only cares about the number of actions.
function mkv_stt(::Multiagency) end
mkv_stt(::NoAgent)     = [:sp => (:s,)]
mkv_stt(::SingleAgent) = [:sp => (:s, :a)]
mkv_stt(::MultiAgent)  = [:sp => (:s, :(a[i]))]


# TODO: Constraints / lexico / slack and sojourn not yet implemented. Should be pretty
#   straightforward along the lines of the other nodes.

"""
    default_mkv_reward_conditioning(fn; consider_mem=false)

Gives the default reward conditioning for a Markov family problem based on the reward
function.

If the reward function is has a method for one, two, or three parameters, we assume it
is conditioned on (s,), (s, a), or (s, a, s′) respectively, assuming the reward function is
not intended to be conditioned on memory. If the reward function _is_ intended to be
conditioned on memory (denoted with `consider_mem=true`), we assume it is conditioned on
(m,) or (m, a) if it has one or two arguments respectively.
"""
function default_mkv_reward_conditioning(fn; consider_mem=false)
    if ! consider_mem
        if hasmethod(fn, (Any, Any, Any))
            ConditionedOn{(:s, :a, :sp)}
        elseif hasmethod(fn, (Any, Any))
            ConditionedOn{(:s, :a)}
        else
            ConditionedOn{(:s,)}
        end
    else
        if hasmethod(fn, (Any, Any))
            ConditionedOn{(:m, :a)}
        else
            ConditionedOn{(:m,)}
        end
    end
end
"""
    default_mkv_memory_presence()

Gives the default memory presence for a Markov family problem.

We assume the memory node is present when allowed, so the agent to persist information 
between steps. If a truly memoryless approach is desired, the `MemoryAbsent` trait can
be used as a type parameter. 
"""
function default_mkv_memory_presence()
    MemoryPresent
end