struct MarkovTraits
    dict::Dict{Type{<:DecisionsTrait}, DecisionsTrait}

    MarkovTraits(pairs...) = new(Dict{Type{<:DecisionsTrait}, DecisionsTrait}(pairs...))
end

"""
    MarkovAmbiguousTraits
    MarkovAmbiguousTraits(pairs...)

A collection of traits for a standard Markov family problem.

`pairs` are `Trait => TraitValue` mappings; e.g., `Multiagency => NoAgent()`. Any traits
that are not defined default using `markov_default`.
"""
struct MarkovAmbiguousTraits
    dict::Dict{Type{<:DecisionsTrait}, Tuple{Vararg{DecisionsTrait}}}

    function MarkovAmbiguousTraits(pairs...) 
        tupled_pairs = map(pair -> pair[1] => Tuple(pair[2]), pairs) 
        new(Dict{Type{<:DecisionsTrait}, Tuple{Vararg{DecisionsTrait}}}(tupled_pairs...))
    end
end

function Base.getindex(traits::Union{MarkovTraits, MarkovAmbiguousTraits}, ::Type{Q}) where {Q<:DecisionsTrait}
    if Q in keys(traits.dict)
        traits.dict[Q]
    else
        markov_default(Q)
    end
end

function markov_nodes(traits::MarkovTraits)
    # There are exactly six possible nodes in the standard Markov family
    #   plus two inputs that can have edges from them
    possible_nodes = [:sp, :a, :o, :r, :mp, :τ, :s, :m]
    node_definitions = []
    for output_name in possible_nodes
        output = markov_node(Val(output_name), traits)
        isnothing(output) && continue # node not defined based on these traits
        inputs = []
        for input_name in possible_nodes
            input = markov_edge(Val(input_name), Val(output_name), traits)
            isnothing(input) && continue
            push!(inputs, input)
        end
        push!(node_definitions, Tuple(inputs) => output)
    end
    node_definitions
end

function markov_dynamic_pairs(traits::MarkovTraits)
    pairs = []
    traits[Statefulness]   isa Stateless    || push!(pairs, :s => :sp)
    traits[MemoryPresence] isa MemoryAbsent || push!(pairs, :m => :mp)
    NamedTuple(pairs)
end

function markov_ranges(traits::MarkovTraits)
    N = num_agents(traits[Multiagency])
    C = num_rewards(traits[RewardStyle])
    ranges = []
    N > 1 && push!(ranges, :i => N)
    C > 1 && push!(ranges, :j => C)
    NamedTuple(ranges)
end

function markov_type(traits::MarkovTraits)
    nodes = markov_nodes(traits)
    dynamic_pairs = markov_dynamic_pairs(traits)
    ranges = markov_ranges(traits)
    DecisionGraph(nodes, dynamic_pairs, ranges)
end

function markov_type(t::MarkovAmbiguousTraits)
    possible_traits = map(pair -> pair[1] .=> pair[2], [pairs(t.dict)...])
    possible_types = map(Iterators.product(possible_traits...)) do (T...)
        traits = MarkovTraits(T...)
        nodes = markov_nodes(traits)
        dynamic_pairs = markov_dynamic_pairs(traits)
        std_nodes, std_dynamic_pairs = _standardize_dn_type(nodes, dynamic_pairs)
        DecisionNetwork{std_nodes, std_dynamic_pairs #= ranges left ambiguous =#}
    end
    Union{possible_types...}
end

function markov_concretize_traits(ambiguous_traits::MarkovAmbiguousTraits, behavior, ranges)
    new_traits = map([keys(ambiguous_traits.dict)...]) do T
        inferred_trait = markov_infer_trait(T, ambiguous_traits, behavior, ranges)
        T => inferred_trait
    end
    MarkovTraits(new_traits...)
end
function markov_infer_trait(::Type{Q}, ambiguous_traits, behavior, ranges) where {Q<:DecisionsTrait}
    if length(ambiguous_traits[Q]) == 1
        ambiguous_traits[Q][1]
    else
        throw(ArgumentError("Could not infer trait $Q from options $(T(traits))"))
    end
end
function markov_infer_trait(::Type{MemoryPresence}, ambiguous_traits, behavior, ranges)
    (:mp ∈ keys(behavior)) ? MemoryPresent() : MemoryAbsent()
end
function markov_infer_trait(::Type{RewardStyle}, ambiguous_traits, behavior, ranges)
    if ! (:r ∈ keys(behavior))
        NoReward()
    else
        if ! (behavior[:r] isa ConditionalDist)
            # TODO: Annoying special case wrt functions
            ambiguous_traits[RewardStyle][1]
        elseif ! (:j ∈ keys(ranges))
            nonindexing_rvs = filter(x -> x ∉ (:i, :j), c)
            SingleReward(nonindexing_rvs...)
        else
            nonindexing_rvs = filter(x -> x ∉ (:i, :j), c)
            MultipleRewards(ranges[:j], nonindexing_rvs...)
        end
    end
end
function markov_infer_trait(::Type{Observability}, ambiguous_traits, behavior, ranges)
    (:o  ∈ keys(behavior)) ? PartiallyObservable() : FullyObservable()
end
function markov_infer_trait(::Type{TimestepStyle}, ambiguous_traits, behavior, ranges)
    (:τ  ∈ keys(behavior)) ? SemiMarkov() : FixedTimestep()
end
function markov_infer_trait(::Type{Multiagency}, ambiguous_traits, behavior, ranges)
    if ! (:a ∈ keys(behavior))
        # TODO: This is an assumption
        ambiguous_traits[Multiagency][1]
    elseif ! (:i ∈ keys(ranges))
        SingleAgent()
    else
        DefiniteAgents{ranges[:i]}()
    end
end

function markov_check_trait(trait::DecisionsTrait, possibilities)
    trait ∈ possibilities
end

# Edge case 1: IndefiniteAgents permits any DefiniteAgents
function markov_check_trait(trait::DefiniteAgents, possibilities)
    IndefiniteAgents() ∈ possibilities || trait ∈ possibilities
end

# Edge case 2: IndefiniteRewards permits DefiniteRewards with same conditioning rvs
function markov_check_trait(trait::DefiniteRewards{N, rvs}, possibilities) where {N, rvs}
    IndefiniteRewards(rvs) ∈ possibilities || trait ∈ possibilities
end

function markov_check_type(ta::MarkovAmbiguousTraits, td::MarkovTraits)
    for field in keys(ta.dict)
        if ! (markov_check_trait(td[field], ta[field]))
            throw(ArgumentError(
                "Implied network trait $(td[field]) is not among the possible \
                options $(ta[field])."))
        end
    end
end

"""
    @markov_alias(name, traits)

Build a type alias and constructor for a standard Markov decision network with the given
`traits`.

`traits` is expected to be a `MarkovAmbiguousTraits`. If any traits are ambiguous, a Union
over the possible decision graphs is defined. Otherwise, a single decision graph is defined.
"""
macro markov_alias(name, abstract_traits)
    quote
        Core.@__doc__ const $name = DecisionNetworks.markov_type($abstract_traits)

        # function $name(plates=(;); kwargs...)
        #     behavior = NamedTuple(kwargs)
        #     concrete_traits = Decisions.markov_concretize_traits($abstract_traits, behavior, plates)
        #     Decisions.markov_check_type($abstract_traits, concrete_traits)
        #     Decisions.markov_type(concrete_traits)(; behavior...)
        # end
    end |> esc
end

macro markov_edge(edge, pattern...)
    input  = :(Val{$(edge.args[2])})
    output = :(Val{$(edge.args[3])})
    traits = pattern[begin:end-1]
    defs = pattern[end].args

    fns = []
    for def in defs
        (def isa Expr) || continue
        args = if def.args[2] isa Symbol
            [:(::$(def.args[2])), ]
        else
            map(def.args[2].args) do arg
                :(::$arg)
            end
        end
        push!(fns, :(markov_edge(::$input, ::$output, $(args...)) = $(def.args[3])))
    end

    trait_vals = map(traits) do trait
        :(markov_traits[$trait])
    end

    block = quote
        function markov_edge(::$input, ::$output, markov_traits::DecisionNetworks.MarkovTraits)
            markov_edge($input(), $output(), $(trait_vals...))
        end
    end 
    append!(block.args, fns)
    block |> esc
end

macro markov_node(node, pattern...)
    output = :(Val{$node})
    traits = pattern[begin:end-1]
    defs = pattern[end].args

    fns = []
    for def in defs
        (def isa Expr) || continue
        args = if def.args[2] isa Symbol
            [:(::$(def.args[2])), ]
        else
            map(def.args[2].args) do arg
                :(::$arg)
            end
        end
        push!(fns, :(markov_node(::$output, $(args...)) = $(def.args[3])))
    end

    trait_vals = map(traits) do trait
        :(markov_traits[$trait])
    end

    block = quote
        function markov_node(::$output, markov_traits::DecisionNetworks.MarkovTraits)
            markov_node($output(), $(trait_vals...))
        end
    end 
    append!(block.args, fns)
    block |> esc
end

markov_edge(::Val, ::Val, ::MarkovTraits) = nothing
markov_node(::Val, ::MarkovTraits) = nothing


# IMPLICATIONS
# not MultiAgent => Cooperative
# not MultiAgent => SingleObservation
# not MultiAgent => Centralized
# not MultiAgent => not AgentFactored
# Individual     => Decentralized

# STATE NODE
@markov_node :sp Statefulness begin
    AgentFactored => Indep(:sp, :i; is_terminable=true)
    Stateful      => Joint(:sp;     is_terminable=true)
    Stateless     => nothing
end
@markov_edge (:τ => :sp) TimestepStyle begin
    SemiMarkov    => Dense(:τ)
    FixedTimestep => nothing
end
@markov_edge (:a => :sp) Multiagency Statefulness begin
    (MultiAgent,  Stateful)      => Dense(:a)
    (MultiAgent,  Stateless)     => Dense(:a)
    (MultiAgent,  AgentFactored) => Parallel(:a, :i)
    (SingleAgent, Any)      => Dense(:a)
    (NoAgent,     Any)      => nothing
end
@markov_edge (:s => :sp) Statefulness begin
    AgentFactored => Parallel(:s, :i)
    Stateful      => Dense(:s)
    Stateless     => nothing
end


# REWARD NODE
@markov_node :r RewardStyle Cooperation begin
    (MultipleRewards, Individual ) => Indep(:r, :i, :j; is_terminable=false)
    (MultipleRewards, Competitive) => Indep(:r, :i, :j; is_terminable=false)
    (MultipleRewards, Cooperative) => Indep(:r, :j;     is_terminable=false)
    (SingleReward,    Individual ) => Indep(:r, :i;     is_terminable=false)
    (SingleReward,    Competitive) => Indep(:r, :i;     is_terminable=false)
    (SingleReward,    Cooperative) => Joint(:r;         is_terminable=false)
    (NoReward,        Any ) => nothing
end
# Special case: RewardStyle has a type parameter due to the combinatorial edge options
function markov_edge(::Val{id}, ::Val{:r}, traits::MarkovTraits) where {id}
    if id ∉ reward_conditions(traits[RewardStyle])
        return nothing
    end

    source_id = id
    if id == :m 
        source_id = :mp
    elseif id == :s
        source_id = :sp
    end

    source_node = markov_node(Val(source_id), traits)
    if isnothing(source_node)
        return nothing
    elseif traits[Cooperation] isa Individual && (:i in indices(source_node))
        Parallel(id, :i)
    else
        Dense(id)
    end
end


# ACTION NODE
@markov_node :a Multiagency AgentCorrelation begin
    (MultiAgent,  Correlated)   => Joint(:a, :i; is_terminable=false)
    (MultiAgent,  Uncorrelated) => Indep(:a, :i; is_terminable=false)
    (SingleAgent, Any)          => Joint(:a    ; is_terminable=false)
    (NoAgent,     Any)          => nothing
end
@markov_edge (:m => :a) MemoryPresence Centralization begin
    (MemoryPresent, Centralized)   => Dense(:m)
    (MemoryPresent, Decentralized) => Parallel(:m, :i)
    (MemoryAbsent,  Any)           => nothing
end
@markov_edge (:s => :a) Statefulness Observability MemoryPresence Centralization begin
    (Stateful,      FullyObservable,     MemoryAbsent,  Any)           => Dense(:s)
    (AgentFactored, FullyObservable,     MemoryAbsent,  Centralized)   => Dense(:s)
    (AgentFactored, FullyObservable,     MemoryAbsent,  Decentralized) => Parallel(:s, :i)
    (Any,           FullyObservable,     MemoryAbsent,  Any)           => nothing
    (Any,           FullyObservable,     MemoryPresent, Any)           => nothing
    (Any,           PartiallyObservable, Any,           Any)           => nothing
end


# OBSERVATION NODE
@markov_node :o Observability Multiagency begin
    (PartiallyObservable, MultiAgent) => Joint(:o, :i; is_terminable=false)
    (PartiallyObservable, Any)        => Joint(:o    ; is_terminable=false)
    (FullyObservable,     Any)        => nothing
end

# @markov_node :o Observability Multiagency Centralization begin
#     (PartiallyObservable, MultiAgent) => Joint(:o, :i; is_terminable=false)
#     (PartiallyObservable, Any)        => Joint(:o    ; is_terminable=false)
#     (FullyObservable,     Any)        => nothing
#     (PartiallyObservable, MultiAgent, Decentralized) => Indep(:o, :i; is_terminable=false)
# end

@markov_edge (:sp => :o) Statefulness begin 
    Stateful      => Dense(:sp)
    AgentFactored => Parallel(:sp, :i)
    Stateless     => nothing
end
@markov_edge (:τ => :o) TimestepStyle begin 
    SemiMarkov    => Dense(:τ)
    FixedTimestep => nothing
end
@markov_edge (:a => :o) Multiagency begin
    MultiAgent  => Dense(:a)
    SingleAgent => Dense(:a)
    NoAgent     => nothing
end
@markov_edge (:s => :o) Statefulness begin 
    Stateful      => Dense(:s)
    AgentFactored => Parallel(:s, :i)
    Stateless     => nothing
end


# MEMORY NODE
@markov_node :mp MemoryPresence Centralization begin
    (MemoryPresent, Centralized)   => Joint(:mp    ; is_terminable=false)
    (MemoryPresent, Decentralized) => Indep(:mp, :i; is_terminable=false)
    (MemoryAbsent,  Any)           => nothing
end
@markov_edge (:a => :mp) Multiagency Centralization begin
    (MultiAgent, Centralized)   => Dense(:a)
    (MultiAgent, Decentralized) => Parallel(:a, :i)
    (SingleAgent, Any)          => Dense(:a)
    (NoAgent, Any)              => nothing
end
@markov_edge (:m => :mp) Centralization begin
    Centralized => Dense(:m)
    Decentralized => Parallel(:m, :i)
end
@markov_edge (:o => :mp) Observability Centralization begin
    (PartiallyObservable, Centralized)   => Dense(:o)
    (PartiallyObservable, Decentralized) => Parallel(:o, :i)
    (FullyObservable,     Any)           => nothing
end
@markov_edge (:sp => :mp) Observability Statefulness Centralization begin
    (FullyObservable,     AgentFactored, Centralized)   => Dense(:sp)
    (FullyObservable,     AgentFactored, Decentralized) => Parallel(:sp, :i)
    (FullyObservable,     Stateful,      Any)           => Dense(:sp)
    (FullyObservable,     Stateless,     Any)           => nothing
    (PartiallyObservable, Any,           Any)           => nothing
end
@markov_edge (:s => :mp) Observability Statefulness Centralization begin
    (FullyObservable,     AgentFactored, Centralized)   => Dense(:s)
    (FullyObservable,     AgentFactored, Decentralized) => Parallel(:s, :i)
    (FullyObservable,     Stateful,      Any)           => Dense(:s)
    (FullyObservable,     Stateless,     Any)           => nothing
    (PartiallyObservable, Any,           Any)           => nothing
end


# SOJOURN NODE
@markov_node :τ TimestepStyle begin
    SemiMarkov    => Joint(:τ; is_terminable=false)
    FixedTimestep => nothing 
end
@markov_edge (:sp => :τ) Statefulness begin
    Stateful      => Dense(:sp)
    AgentFactored => Dense(:sp)
    Stateless     => nothing
end
@markov_edge (:a => :τ) Multiagency begin
    MultiAgent  => Dense(:a)
    SingleAgent => Dense(:a)
    NoAgent     => nothing
end
@markov_edge (:s => :τ) Statefulness begin
    Stateful      => Dense(:s)
    AgentFactored => Dense(:s)
    Stateless     => nothing
end

# Six of these have the power to declare nodes (among potentially other things)
#   Default is "no node declared"
markov_default(::Type{Statefulness})     = Stateless()
markov_default(::Type{Multiagency})      = NoAgent()
markov_default(::Type{Observability})    = FullyObservable()
markov_default(::Type{RewardStyle})      = NoReward()
markov_default(::Type{MemoryPresence})   = MemoryAbsent()
markov_default(::Type{TimestepStyle})    = FixedTimestep()

# Three of these declare independence in certain important parts of the network
#   Default is "no independence" (because we can't assume presence of indices)
markov_default(::Type{Centralization})   = Centralized()
markov_default(::Type{Cooperation})      = Cooperative()
markov_default(::Type{AgentCorrelation}) = Correlated()