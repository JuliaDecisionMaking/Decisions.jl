
"""
    DecisionNetwork

Representation of a decision network based on an underlying directed acyclic graph.
"""
struct DecisionNetwork{nodes, dynamic_pairs, ranges, B<:NamedTuple}
    implementation::B

    function DecisionNetwork{N, D, R}(; impls...) where {N, D, R}
        _check_dn_typespace(DecisionNetwork{N, D, R})

        N_standard, D_standard, R_standard = _standardize_dn_type(N, D, R)

        bhv = NamedTuple(impls)
        new{N_standard, D_standard, R_standard, typeof(bhv)}(bhv)
    end

    DecisionNetwork{N, D}(R::NamedTuple=(;); impls...) where {N, D} = DecisionNetwork{N, D, R}(; impls...)
end

"""
    const DecisionGraph = Type{<:DecisionNetwork}
    DecisionGraph(nodes, dynamic_pairs=nothing, ranges=nothing)

A decision graph: the underlying graph structure of a decision network, with
none of the distributions implemented. 

If `dynamic_pairs` or `ranges` is `nothing`, the corresponding `DecisionNetwork`
type parameter is left unspecified. (This way, it is possible to define a
`DecisionGraph` without knowing the dynamic pairs or ranges ahead of time.) 
"""
const DecisionGraph = Type{<:DecisionNetwork}

function (::Type{DecisionGraph})(nodes=nothing, dynamic_pairs=nothing, ranges=nothing)
    n, d, r = _standardize_dn_type(nodes, dynamic_pairs, ranges)
    DecisionNetwork{
        n, 
        isnothing(d) ? D : d, 
        isnothing(r) ? R : r, B
    } where {D, R, B<:NamedTuple}
end

function DecisionNetwork(nodes, dynamic_pairs=(;), ranges=(;); impls...)
    N_standard, D_standard, R_standard = _standardize_dn_type(nodes, dynamic_pairs, ranges)
    DecisionNetwork{N_standard, D_standard, R_standard}(impls...)
end


"""
    graph(dn::DecisionNetwork)

Give the decision graph for decision network `dn`.
"""
graph(::DecisionNetwork{N, D, R}) where {N, D, R} = DecisionNetwork{N, D, R}


"""
    nodes(::DecisionGraph)
    nodes(::DecisionNetwork)
    
Give the node definitions of a decision network.
"""
nodes(::DecisionNetwork{N}) where {N} = N
nodes(::Type{<:DecisionNetwork{N}}) where {N} = N


"""
    dynamic_pairs(::DecisionGraph)
    dynamic_pairs(::DecisionNetwork)
    
Give the dynamic pairs for a decision network, mapping current to next iterate node
names.
"""
dynamic_pairs(::DecisionNetwork{N, D}) where {N, D} = D
dynamic_pairs(::Type{<:DecisionNetwork{N, D}}) where {N, D} = D


"""
    ranges(::DecisionGraph)
    ranges(::DecisionNetwork)
    
Give a NamedTuple defining the ranges over which plates in a decision network are defined:
each key is a name of an indexing variables, and each value is the plate size along that
index.

If given a `DecisionGraph` where the `range` parameter is not specified, returns `nothing`.
"""
ranges(::DecisionNetwork{N, D, R}) where {N, D, R} = R
ranges(::Type{<:DecisionNetwork{N, D, R}}) where {N, D, R} = R
ranges(::Type{<:DecisionNetwork}) = nothing

"""
    implementation(dn::DecisionNetwork)
    
Give the conditional distributions implementing the nodes of a decision network as a
NamedTuple mapping node names to distributions.
"""
implementation(dn::DecisionNetwork) = dn.implementation


"""
    node_names(::DecisionGraph)
    node_names(::DecisionNetwork)

Give the names (as Symbols) of all random variables in a decision network.
"""
node_names(dn::DecisionGraph) = (keys(nodes(dn))..., keys(dynamic_pairs(dn))...)
node_names(dn::DecisionNetwork) = (keys(nodes(dn))..., keys(dynamic_pairs(dn))...)


"""
    conditions(dn::DecisionGraph, s::Symbol)
    conditions(dn::DecisionNetwork, s::Symbol)

Give the names of the conditioning variables of `s` in `dn` (including any indexing
variables).
"""
function conditions(dn::DecisionGraph, s::Symbol) 
    if s ∈ keys(dynamic_pairs(dn))
        return (dynamic_pairs(dn)[s],)
    end

    c = [
        [name(n) for n in nodes(dn)[s][1]]...;
        indices(nodes(dn)[s][2])...
    ]
    _sorted_tuple(c)
end

conditions(dn::T, s::Symbol) where {T <: DecisionNetwork} = conditions(T, s)

"""
    children(dn::DecisionGraph, s::Symbol)
    children(dn::DecisionNetwork, s::Symbol)

Give the names of all nodes in `dn` that are conditioned on `s`.
"""
function children(dn::DecisionGraph, s::Symbol)
    filter(node_names(dn)) do rv
        s ∈ conditions(dn, rv)
    end
end

children(::T, s::Symbol) where {T <: DecisionNetwork} = children(T, s)


# TODO: Document that index of dynamic input falls through to next-iterate version 
function Base.getindex(dp::DecisionNetwork, rv::Symbol) 
    if rv ∈ keys(dynamic_pairs(dp))
        rv = dynamic_pairs(dp)[rv]
    end
    implementation(dp)[rv]
end

Base.keys(dp::DecisionNetwork) = keys(nodes(dp))
Base.keys(dp::DecisionGraph) = keys(nodes(dp))

Base.iterate(dp::DecisionNetwork) = iterate(keys(nodes(dp)))
Base.iterate(dp::DecisionGraph) = iterate(keys(nodes(dp)))

Base.iterate(dp::DecisionNetwork, state) = iterate(keys(nodes(dp)), state)
Base.iterate(dp::DecisionGraph, state) = iterate(keys(nodes(dp)), state)

Base.in(rv::Symbol, dp::DecisionNetwork) = rv ∈ keys(nodes(dp))
Base.in(rv::Symbol, dp::DecisionGraph) = rv ∈ keys(nodes(dp))


"""
    next(dn::DecisionNetwork, node)
    next(dn::DecisionGraph, node)

Give the next-step counterpart of `node` in a [type of] decision network `dn`.

`dn` must be a dynamic decision network.

# Examples
```jldoctest 
julia> next(MDP_DN, :s)
:sp
```
"""
next(dn::DecisionNetwork, rv::Symbol) = dynamic_pairs(dn)[rv]
next(dn::DecisionGraph, rv::Symbol) = dynamic_pairs(dn)[rv]


"""
    prev(dn::DecisionNetwork, node)
    prev(dn::DecisionGraph, node)

Give the previous-step counterpart of `node` in a [type of] decision network `dn`.

`dn` must be a dynamic decision network.

# Examples
```jldoctest
julia> prev(MDP_DN, :sp)
:s
```
"""
prev(dn::DecisionNetwork, rv::Symbol) = findfirst((i) -> i==rv, dynamic_pairs(dn))
prev(dn::DecisionGraph, rv::Symbol) = findfirst((i) -> i==rv, dynamic_pairs(dn))


"""
    rand(dn::DecisionNetwork; meta, inputs...)

Samples a decision network given `inputs`.

If the decision network is a _dynamic_ decision network, samples until
`terminal` is sampled from a node marked as possibly terminal.

Returns a NamedTuple `NamedTuple` where each key is is a random variable name
and each value its realizations (or an array of such NamedTuples, for a dynamic DN).
"""
function Base.rand(dn::DecisionNetwork; meta=(;), inputs...)
    stop_fn = (:stop_fn ∈ keys(meta)) ? meta[:stop_fn] : (c)->false

    

    sample(dn, (;), inputs |> NamedTuple, nothing) do c
        println(c)
        stop_fn(c)
    end
end

"""
    sample(fn = (_) -> false, dn::DecisionNetwork [, decisions::NamedTuple, input::NamedTuple, output::Tuple])

Sample nodes or plates `out` in decision network `dn` based on input values `in` and node
implementations provided by `decisions` and `dn.implementation`. `fn`, if present, executes upon
each iteration of a (dynamic) network on a NamedTuple mapping the names `out` to their
values, and stops when `fn` returns true.

Returns `terminal` if a terminal condition is reached. Otherwise, returns a NamedTuple
mapping the names `out` to their values after the last (or only) iteration. 

Only ancestors of `out`, up to (but not including) the nodes in `in`, are sampled. If any of
the sampled nodes are not implemented by either `dn.implementation` or `decisions`, an error is
thrown. If _both_ `dn.implementation` and `decisions` specify the same node, the implementation in
`decisions` is preferred.
"""
function sample(
    dn::DecisionNetwork, 
    decisions::NamedTuple=(;), 
    input::NamedTuple=(;), 
    output::Union{Tuple{Vararg{Symbol}}, Symbol, Nothing}=nothing)
    sample(dn, decisions, input, output) do _
        false # just wait for terminal if fn is not provided
    end
end

function sample(
    fn,
    dn::DecisionNetwork, 
    decisions::NamedTuple=(;), 
    input::NamedTuple=(;), 
    output::Union{Tuple{Vararg{Symbol}}, Symbol, Nothing}=nothing)

    dnout = isnothing(output) ? Val(node_names(dn)) : Val(output)
    sample(fn, dn, decisions, input, dnout, Val(false))
end

function sample_expr(
    dn::DecisionNetwork, 
    decisions::NamedTuple=(;), 
    input::NamedTuple=(;), 
    output::Union{Tuple{Vararg{Symbol}}, Symbol, Nothing}=nothing)

    dnout = isnothing(output) ? Val(node_names(dn)) : Val(output)
    sample(dn, decisions, input, dnout, Val(true)) do _
        false
    end
end

@generated function sample(
    fn,
    dn::DecisionNetwork, 
    decisions::NamedTuple, 
    input::NamedTuple{rvs_in}, 
    _::Val{rvs_out},
    _::Val{as_expr}) where {rvs_out, rvs_in, as_expr}

    nodes_in_order = _crawl_dn(dn, rvs_in, rvs_out)
    
    # Zeroeth pass: Inputs
    zeroeth_pass_block = quote 
        dists = merge(dn.implementation, decisions) 
    end
    for rv in rvs_in
        sym = Meta.quot(rv)
        push!(zeroeth_pass_block.args, :($rv = input[$sym]))
    end
    for rv in keys(nodes(dn))
        init_stmt = _make_node_initialization(dn, rv)
        if ! isnothing(init_stmt)
            push!(zeroeth_pass_block.args, init_stmt)
        end
    end

    # First pass: intitial defs; can't use rand!
    first_pass_block = quote end
    for rv in nodes_in_order
        push!(first_pass_block.args, _make_node_assignment(dn, rv))
    end
    for (node, node_prime) in pairs(dynamic_pairs(dn))
        if node_prime in nodes_in_order
            push!(first_pass_block.args, :($node = $node_prime))
        end
    end
    push!(first_pass_block.args, quote
        output = NamedTuple{$rvs_out}(($(rvs_out...),))
        fn(output) && return output
    end)

    # Special case: If the network is not dynamic, we just stop here and never loop
    if isempty(dynamic_pairs(dn))
        return quote
            $zeroeth_pass_block
            $first_pass_block
        end
    end
    
    # Second and further pass: rand! available
    second_pass_block = quote end
    for rv in nodes_in_order
        push!(second_pass_block.args, _make_node_assignment(dn, rv; in_place=true))
    end
    for (node, node_prime) in pairs(dynamic_pairs(dn))
        if node_prime in nodes_in_order
            push!(second_pass_block.args, :($node = $node_prime))
        end
    end
    push!(second_pass_block.args, quote
        output = NamedTuple{$rvs_out}(($(rvs_out...),))
        fn(output) && return output
    end)

    q = quote
        $zeroeth_pass_block
        $first_pass_block
        while true
            $second_pass_block
        end
        output
    end
    if as_expr
        Meta.quot(q)
    else
        q
    end
end