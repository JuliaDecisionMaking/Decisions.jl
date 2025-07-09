
"""
    DecisionGraph{structure, dynamism}

Representation of a directed, acyclic, possibly repeated graph that underlies a (dynamic)
decision network.

`structure` is a NamedTuple mapping nodes to their inputs (tuples of symbols). `dynamism` is
a named tuple mapping nodes to their next-iteration counterparts to allow for infinitely
repeated DAGs (which underlie _dynamic_ decision networks).

"""
struct DecisionGraph{structure, dynamism}
    function DecisionGraph(structure, dynamism)
        # Decision networks should be order invariant wrt their nodes
        #   We need a wrapper with an inner constructor to enforce that
        #   (I'd use Set but ! isbitstype(Set))
        # TODO: Ideally we would also optionally check for cycles here


        sorted_structure = _sortkeys(map(structure) do vars
            # TODO: We want an immutable type here but we also want to be able to sort
            #   Probably there is a more efficient way to do this
            Tuple(sort([vars...]))
        end)

        sorted_dynamism = _sortkeys(dynamism)
        new{sorted_structure, sorted_dynamism}()
    end
end

@generated _sortkeys(nt::NamedTuple{KS}) where {KS} =
    :( NamedTuple{$(Tuple(sort(collect(KS))))}(nt) )


"""
    DecisionNetwork{dn::DecisionGraph{structure, dynamism}} where {structure, dynamism}

Representation of a decision network based on an underlying directed acyclic graph.

Every type of decision problem is described by a concrete decision network (DN) or dynamic
decision network (DDN). A decision network is a directed acyclic graph where each node is a
conditional distribution. `structure` gives this graph as a named tuple mapping symbols
(nodes) to tuples of symbols (conditioning variables). Not all conditioning variables need
be defined as nodes in the structure; those that are not are interpreted as inputs.

If `dynamism` is a non-empty named tuple, a _dynamic_ decision network is specified.
`dynamism` maps node names to their next-step counterparts and vice versa (for instance,
`:s` <=> `:sp` in an MDP.) In this case, `structure` gives the DN for a single step.

A concrete decision problem provides the conditional distributions for any of the nodes (or
none of them) in the named tuple `behavior`. Nodes not in `behavior` have distributions
specified by the agent; that is, they are action nodes.

For convenience, functions querying a problem's structure (not the underlying distributions)
accept both `DecisionNetwork{...}` and `Type{DecisionNetwork{...}}`

# Supported Base functions
 - `keys`: Give all node names defined in the problem.
 - `iterate`: Iterate through node names defined in the problem.
 - `getindex(::DecisionNetwork, in::Symbol)`: Give conditional distribution of `in`, if one
   is specified.
 - `in(idx::Symbol, dn::DecisionNetwork)`: Give whether there is a variable labeled `idx` in
    `dn`.
"""
struct DecisionNetwork{dn<:DecisionGraph}
    behavior::NamedTuple
end

function DecisionNetwork{dn}(; nodes...) where dn
    new{dn}((;), NamedTuple(nodes))
end

"""
    structure(::Type{DecisionNetwork})
    structure(::DecisionNetwork)
    
Give the graph structure of a decision network.
"""
structure(::DecisionNetwork{DecisionGraph{S, D}}) where {S, D} = S
structure(::Type{<:DecisionNetwork{DecisionGraph{S, D}}}) where {S, D} = S


"""
    dynamism(::Type{DecisionNetwork})
    dynamism(::DecisionNetwork)
    
Give the dynamic pairs for a decision network (which maps current to next iterate node
names).
"""
dynamism(::DecisionNetwork{DecisionGraph{S, D}}) where {S, D} = D
dynamism(::Type{<:DecisionNetwork{DecisionGraph{S, D}}}) where {S, D} = D


Base.getindex(dp::DecisionNetwork, idx::Symbol) = behavior(dp)[idx]

Base.keys(dp::DecisionNetwork) = keys(structure(dp))
Base.keys(dp::Type{<:DecisionNetwork}) = keys(structure(dp))

Base.iterate(dp::DecisionNetwork) = iterate(pairs(structure(dp)))
Base.iterate(dp::Type{<:DecisionNetwork}) = iterate(pairs(structure(dp)))

Base.iterate(dp::DecisionNetwork, state) = iterate(pairs(structure(dp)), state)
Base.iterate(dp::Type{<:DecisionNetwork}, state) = iterate(pairs(structure(dp)), state)

# We have to check if `idx` is a conditioning variable for any node because it might
# not itself be a node. This happens for DDNs: e.g., in an MDP, :s doesn't have its own
# node, so without this check we unintuitively have !(:s ∈ MDP)
function Base.in(idx::Symbol, dp::DecisionNetwork)
    S = structure(dp)
    (idx in keys(S) || any(map((cvs) -> idx ∈ cvs, S)))
end

function Base.in(idx::Symbol, dp::Type{<:DecisionNetwork})
    S = structure(dp)
    (idx in keys(S) || any(map((cvs) -> idx ∈ cvs, S)))
end


"""
    `next(dn::DecisionNetwork, node)`
    `next(dn::Type{DecisionNetwork{_, dynamism}}, node)``

Give the next-step counterpart of `node` in a [type of] decision network `dn`.

`dn` must be a dynamic decision network.

# Examples
```jldoctest
julia> next(MDP, :s)
:sp
```
"""
next(dn::DecisionNetwork, idx::Symbol) = dynamism(dn)[idx]
next(dn::Type{<:DecisionNetwork}, idx::Symbol) = dynamism(dn)[idx]


"""
    `prev(dn::DecisionNetwork, node)`
    `prev(dn::Type{DecisionNetwork{_, dynamism}}, node)``

Give the previous-step counterpart of `node` in a [type of] decision network `dn`.

`dn` must be a dynamic decision network.

# Examples
```jldoctest
julia> prev(MDP, :sp)
:s
```
"""
prev(dn::DecisionNetwork, idx::Symbol) = findfirst((i) -> i==idx, dynamism(dn))
prev(dn::Type{<:DecisionNetwork}, idx::Symbol) = findfirst((i) -> i==idx, dynamism(dn))


# TODO: Examples for `structure` and `dynamism` - need to make sure they are consistent
# # Examples
# ```jldoctest
# julia> dynamism(MDP)
# (; s=:sp, sp=:s, m=:mp, mp=:m)



# Convenience wrapper type for tuple of symbols
struct DNOut{ids} end
DNOut(name::Symbol) = DNOut{(name,)}()
DNOut(names...) = DNOut{names}()
DNOut(names::Tuple) = DNOut{names}()

"""
    sample(dn::DecisionNetwork [, decisions::NamedTuple, in::NamedTuple, out::Tuple])

Sample dynamic decision network `dn` based on input values `in` and node implementations
provided by `decisions` and `dn.behavior` (or
return `Terminal()` if a terminal condition is reached).

Only ancestors of `out`, up to (but not including) the nodes in `in`, are sampled. If any of
the sampled nodes are not implemented by either `dn.behavior` or `decisions`, an error is
thrown. If _both_ `dn.behavior` and `decisions` specify the same node, the implementation in
`decisions` is preferred.
"""
function sample(
    dn::DecisionNetwork, 
    decisions::NamedTuple=(;), 
    in::NamedTuple=(;), 
    out::Union{Tuple{Vararg{Symbol}}, Symbol}=())
    sample(dn, decisions, in, DNOut{out}())
end


@generated function sample(
    problem::DecisionNetwork,
    decisions,
    in::NamedTuple{ids_in},
    _::DNOut{ids_out}) where {ids_out, ids_in}

    graph = structure(problem)

    expr = quote 
        node_defs = merge(problem.behavior, decisions) 
    end

    for id in ids_in
        sym = Expr(:quote, id)
        block = quote
            $id = in[$sym]
        end
        append!(expr.args, block.args)
    end

    nodes_in_order = _crawl_graph(graph, ids_in, ids_out)
    out_so_far = []

    for id in nodes_in_order
        sym = Expr(:quote, id)
        cond_vars = graph[id]
        block = quote
            $id = node_defs[$sym]($(cond_vars...))
            if isterminal($id) 
                return Terminal()
            end
        end
        if ids in ids_out
            push!(out_so_far, id)
        end
        append!(expr.args, block.args)
    end

    return_block = quote
        return NamedTuple{$ids_out}($(ids_out...))
    end
    append!(expr.args, return_block.args)

    return expr
end

function _crawl_graph(graph, in, out)
    # We don't want to evaluate any nodes we don't have to: only the ones between the inputs
    # and the outputs. Also, want to do them in order.
    # TODO: This is terribly inefficient; O(n^2). Surely there's a better way.
    # This is a rigorous graph theory problem but it's not one I know the name of,
    #   and it's not worth any more time figuring it out right now.
    distribution
    nodes = Symbol[]
    inter_nodes = Symbol[out...]
    while ! isempty(inter_nodes)
        node = popfirst!(inter_nodes)
        if ! ((node ∈ in) || (node ∈ nodes))
            push!(nodes, node)
            try
                append!(inter_nodes, graph[node])
            catch
                throw(ArgumentError("Initial value required for node :$(node)"))
            end
        end
    end

    sort!(nodes; by=(n) -> _order(graph, n))
end

function _order(graph, node)
    # welcome to cs 101 lol    
    if ((! (node ∈ keys(graph))) || isempty(graph[node]))
        return 0
    end
    1 + maximum([_order(graph, c) for c in graph[node]])
end

# """
#     simulate(dn::DecisionNetwork [, decisions::NamedTuple, in::NamedTuple, out::Tuple])

# Simulate dynamic decision network `dn` based on input values `in` and node implementations
# provided by `decisions` and `dn.behavior`, proceeding through iterates
# of the network until any node yields `Terminal()`. 

# In a non-dynamic decision network, functionally identical to `sample`.
# """
# function simulate(
#     dn::DecisionNetwork, 
#     decisions::NamedTuple=(;), 
#     in::NamedTuple=(;), 
#     out::Union{Tuple{Vararg{Symbol}}, Symbol}=())

#     simulate(dn, decisions, in, DNOut{out}())
# end

# @generated function simulate(
#     dn::DecisionNetwork{graph}, 
#     decisions::NamedTuple, 
#     in::NamedTuple{in_ids}, 
#     out::DNOut{out_ids}) where {graph, out_ids, in_ids}

#     trace_ids = Tuple(union(Set(a), Set(b)))

#     present_ids = keys(dynamism(dn))
#     future_ids = dynamism(dn)[present_ids] # need to ensure they're in corresponding order

#     quote
#         s = sample(dn, decisions, in, $trace_ids)
#         in = NamedTuple{$present_ids}(s)
#     end
# end


"""
    struct Terminal end
    
Unique value representing the output of a decision node as being terminal or otherwise
exceptional. Nodes with `Terminal` input always produce `Terminal` output.
"""
struct Terminal end

isterminal(::Terminal) = true
isterminal(::Any) = false
