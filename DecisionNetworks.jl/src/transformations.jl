

"""
    abstract type DNTransformation

Abstract base class for transformations of decision networks and graphs.

Transformations are callable: `(t::DNTransformation)(p) = transform(t, p)`.
"""
abstract type DNTransformation end

(t::DNTransformation)(p) = transform(t, p)

"""
    transform(t::DNTransformation, d::DecisionNetwork)
    transform(t::DNTransformation, d::DecisionGraph)

Apply transformation `t` to decision network or graph `d`, returning a new network or graph.
"""
function transform end

function _default_transform(trans::DNTransformation, dn::DecisionNetwork)
    transform(trans, graph(dn))(; implementation(dn)...)
end

"""
    Insert <: DNTransformation
    Insert(nodes...)

Insert one or more nodes into a decision graph or decision network.

`nodes` are supplied as node definitions; that is, pairs of the form
`(::ConditioningGroup...) => ::Plate`.
"""
struct Insert <: DNTransformation 
    nodes
    Insert(nodes...) = new( Tuple.(nodes)) #?
end

function transform(trans::Insert, g::DecisionGraph)
    new_nodes = merge(nodes(g), NamedTuple([name(n[2]) => n for n in trans.nodes]))
    DecisionGraph(new_nodes, dynamic_pairs(g), ranges(g))
end

transform(trans::Insert, dn::DecisionNetwork) = _default_transform(trans, dn)

"""
    Implement <: DNTransformation
    Implement(; impls::ConditionalDist...)

Augment a decision network with conditional distribution(s) implementing one or more of its
nodes.

Conditional distributions are supplied to nodes matching the names of their kwargs. If a
distribution is supplied for a node that has one, the existing distribution is replaced. 
"""
struct Implement{B <: NamedTuple} <: DNTransformation
    implementation::B
    function Implement(; impls...) 
        impl = impls |> NamedTuple
        new{typeof(impl)}(impl)
    end
end

function transform(trans::Implement, dn::DecisionNetwork)
    new_bhv = merge(implementation(dn), trans.implementation)
    graph(dn)(; new_bhv...)
end

"""
    Unimplement <: DNTransformation
    Unimplement(nodes...)

Remove the conditional distribution(s) implementing one or more `nodes` in the decision
network, if they exist. 

The node names are given as Symbols.
"""
struct Unimplement <: DNTransformation
    nodes::Tuple{Vararg{Symbol}}
    Unimplement(node) = new((node,))
    Unimplement(node, nodes...) = new((node, nodes...))
end

function transform(trans::Unimplement, dn::DecisionNetwork)
    keep_nodes = filter(k -> k ∉ trans.nodes, keys(implementation(dn)))
    graph(dn)(; implementation(dn)[keep_nodes]...)
end

"""
    Recondition <: DNTransformation
    Recondition(; nodes...)

Change the conditioning of one or more nodes in a decision graph (not a decision network).

New conditionings are supplied as tuples of `ConditioningGroup`s, with the keyword name
giving the node they condition.
"""
struct Recondition{N<:NamedTuple} <: DNTransformation
    new_nodes::N
    function Recondition(; nodes...) 
        nt = nodes |> NamedTuple
        new{typeof(nt)}(nt)
    end
end

function transform(trans::Recondition, dg::DecisionGraph)
    for key in keys(trans.new_nodes)
        if key ∉ keys(nodes(dg))
            throw(ArgumentError("Node $key not found in decision graph"))
        end
    end
    new_nodes = map(values(nodes(dg))) do node
        rv = name(node[2])
        if rv ∈ keys(trans.new_nodes)
            trans.new_nodes[rv] => node[2]
        else
            node
        end
    end
    DecisionGraph(new_nodes, dynamic_pairs(dg), ranges(dg))
end

transform(t::Recondition, dn::DecisionNetwork) = _default_transform(t, dn)

"""
    IndexExplode <: DNTransformation
    IndexExplode(idx; sep='_')

Split all plates `a` in a decision network or graph over index `idx` into nodes `a_1, a_2,
..., a_N`, where N is given by `ranges`.

In a decision network, when a node with an implementation `dist` is exploded along axis `i`,
the resulting subnodes have distributions `fix(dist; i=1)`, `fix(dist; i=2)`, etc.
"""
struct IndexExplode <: DNTransformation
    idx::Symbol
    sep::Char
    IndexExplode(idx; sep='_') = new(idx, sep)
end

function _get_split_output(n::Indep, idx::Symbol, new_name)
    idx ∈ indices(n) || throw(ArgumentError("Can't split node $(n) along nonexistent index $idx"))
    new_indices = filter(i -> i != idx, indices(n))
    if isempty(new_indices)
        # Prefer joint over indep when there are no indices
        Joint(new_name; hints(n)...)
    else
        Indep(new_name, new_indices...; hints(n)...)
    end
end

function _get_split_output(n::JointAndIndep, idx::Symbol, new_name)
    # TODO
end

function _get_split_output(n::Joint, idx::Symbol, new_name)
    throw(ArgumentError("Can't split node $(name(n)); it is jointly sampled"))
end

# corr_output is the output of the node matching name(n)
function _get_split_input(n::Dense, corr_output, i)
    if isnothing(corr_output)
        [n]
    elseif length(corr_output) == 1
        [n]
    else
        [Dense(name(n_i)) for n_i in corr_output]
    end
end

function _get_split_input(n::Parallel, corr_output, i)
    if isnothing(corr_output)
        [n]
    elseif length(corr_output) == 1
        [n]
    else
        new_indices = filter(i -> i != idx, indices(n))
        if isempty(new_indices)
            [Dense(name(corr_output[i]))]
        else
            [Parallel(name(corr_output[i]), new_indices...)]
        end
    end
end

function _split_node(range, idx, sep, dg::DecisionGraph)
    # Degenerate case
    if ranges(dg)[idx] <= 1
        return dg
    end

    output_map = map(nodes(dg)) do node
        if idx ∈ indices(node[2])
            map(range) do i
                new_name = Symbol(name(node[2]), sep, i)
                _get_split_output(node[2], idx, new_name)
            end
        else
            [node[2]]
        end
    end
    new_nodes = []
    for (rv, new_groups_out) in pairs(output_map)
        old_node = nodes(dg)[rv]
        for (i, new_group_out) in zip(range, new_groups_out)
            new_groups_in = []
            for old_group_in in old_node[1]
                rv = name(old_group_in)
                corr_output = (rv ∈ keys(output_map)) ? output_map[rv] : nothing
                append!(new_groups_in, _get_split_input(old_group_in, corr_output, i))
            end
            push!(new_nodes, (new_groups_in |> Tuple) => new_group_out)
        end
    end
    new_ranges = filter(p -> p[1] != idx, pairs(ranges(dg))) |> NamedTuple
    DecisionGraph(new_nodes, dynamic_pairs(dg), new_ranges)
end

function transform(trans::IndexExplode, dg::DecisionGraph)
    if isnothing(ranges(dg))
        throw(ArgumentError("No ranges specified on this decision graph"))
    end

    _split_node(1:ranges(dg)[trans.idx], trans.idx, trans.sep, dg)
end

function _get_wrapper_dist(input_node, dn, idx;  sep="_")
    
end

function transform(trans::IndexExplode, dn::DecisionNetwork)
    new_dg = transform(trans, graph(dn))
    range = 1:ranges(dn)[trans.idx]
    all_impls = implementation(dn)
    new_impls = []

    for (rv, impl) in pairs(all_impls)
        node = nodes(dn)[rv]
        old_output = node[2]

        half_correct_dists = if trans.idx ∈ indices(old_output)
            # If this was a distribution for a node that got exploded,
            #   fix its index to make new distributions

            map(range) do i
                Symbol(rv, trans.sep, i) => fix(impl; trans.idx => i)
            end
        else
            [rv => impl]
        end

        full_correct_dists = map(enumerate(half_correct_dists)) do (i, pair)
            updated_name = pair[1]
            updated_dist = pair[2]
            for old_input in node[1]
                old_rv_in = name(old_input)

                # Option 1: This input is not a node
                if old_rv_in ∉ keys(nodes(dn))
                    #TODO - no plates on dynamic nodes right now
                    continue
                end

                # Option 2: This input was not exploded
                source_output_node = nodes(dn)[name(old_input)][2]
                if trans.idx ∉ indices(source_output_node)
                    # We need not modify the distribution for this input at all
                    continue
                end
                    

                # Option 3: Both input and output exploded and had parallel relationship
                #   on the exploding index
                if trans.idx ∈ indices(old_output) && trans.idx ∈ indices(old_input)
                    new_rv_in = Symbol(rv, trans.sep, i)
                    updated_dist = RenamedDist(updated_dist; old_rv_in => new_rv_in)
                    continue
                end

                # Option 4: Input and output had dense relationship:
                #   either the output did not explode (trans.idx ∉ indices(old_output))
                #   or the input was dense (trans.idx ∉ indices(old_input))
                new_rvs = map(range) do j
                    Symbol(old_rv_in, trans.sep, j)
                end
                # TODO: We might or might not be able to infer the output type here
                wrapper_dist = CollectDist(Any, new_rvs...)
                updated_dist = MergedDist(updated_dist, old_rv_in => wrapper_dist)
            end

            updated_name => updated_dist
        end

        append!(new_impls, full_correct_dists)
    end

    new_dg(; new_impls...)
end


"""
    MergeForward <: DNTransformation
    MergeForward(nodes...)

Merges nodes named in `nodes` forward in a decision network or decision graph: for each such
node `n`, nodes that `n` as an input now have the inputs of `n` as inputs (and `n` is
removed from the network).

In a decision network, nodes with implemented distributions have those distributions merged
with `MergedDist`.
"""
struct MergeForward <: DNTransformation
    nodes::Tuple{Vararg{Symbol}}
    MergeForward(node) = new((node,))
    MergeForward(node, nodes...) = new((node, nodes...))
end

# a => b => c
#      a => c
# (1) If a => b, b => c, or a => c is dense, a => c' is dense.
# (2) If a => b and b => c are both parallel, and a => doesn't exist,
#   a => c' is parallel along the axes that both are parallel (or dense if none).
# (3) If a => b, b => c, and a => c are all parallel,
#   a => c' is parallel along the axes that all are parallel (or dense if none).


# Annoying type dispatch with three cases
_promote_input(ab::Dense, bc, ac) = Dense(name(ab))
_promote_input(ab, bc::Dense, ac) = Dense(name(ab))
_promote_input(ab, bc, ac::Dense) = Dense(name(ab))
_promote_input(ab::Dense, bc::Dense, ac) = Dense(name(ab))
_promote_input(ab, bc::Dense, ac::Dense) = Dense(name(ab))
_promote_input(ab::Dense, bc, ac::Dense) = Dense(name(ab))
_promote_input(ab::Dense, bc::Dense, ac::Dense) = Dense(name(ab))

function _promote_input(ab::Parallel, bc::Parallel, ac::Nothing)
    parallel_idxs = Set(indices(ab)) ∩ Set(indices(bc))
    isempty(parallel_idxs) ? Dense(name(ab)) : Parallel(name(ab), parallel_idxs...)
end

function _promote_input(ab::Parallel, bc::Parallel, ac::Parallel)
    parallel_idxs = Set(indices(ab)) ∩ Set(indices(bc)) ∩ Set(indices(ac))
    isempty(parallel_idxs) ? Dense(name(ab)) : Parallel(name(ab), parallel_idxs...)
end

function transform(trans::MergeForward, dg::DecisionGraph)
    for collapsing_rv in trans.nodes
        new_nodes = []
        for current_node in nodes(dg)
            if name(current_node[2]) == collapsing_rv
                continue
            end 
            output_group = current_node[2]

            new_input_groups = []
            collapsing_input_group_idx = findfirst((in) -> name(in) == collapsing_rv, current_node[1])
            if ! isnothing(collapsing_input_group_idx)
                collapsing_input_group = current_node[1][collapsing_input_group_idx]
                # If this random variable has an associated node (isn't a DN input)
                if collapsing_rv ∈ keys(nodes(dg))
                    # ... then push all its conditions forward
                    for carry_input_group in nodes(dg)[collapsing_rv][1]
                        carry_rv = name(carry_input_group)
                        # For every input of the collapsing node `carry_rv`
                        #   check if that rv already conditions the current node
                        side_input_group_idx = findfirst((in) -> (name(in) == carry_rv), current_node[1])
                        side_input_group = isnothing(side_input_group_idx) ? nothing : current_node[1][side_input_group_idx]
                        new_input_group = _promote_input(
                            carry_input_group, 
                            collapsing_input_group, 
                            side_input_group
                        )
                        push!(new_input_groups, new_input_group)
                    end
                end
            end
            # Push all other inputs in, if they haven't already been included
            for old_input_group in current_node[1]
                if name(old_input_group) != collapsing_rv
                    if name(old_input_group) ∉ [name(g) for g in new_input_groups]
                        push!(new_input_groups, old_input_group)
                    end
                end
            end
            push!(new_nodes, new_input_groups => output_group)
        end
        new_pairs = filter(pairs(dynamic_pairs(dg))) do p
            (p[1] != collapsing_rv && p[2] != collapsing_rv)
        end |> NamedTuple
        dg = DecisionGraph(new_nodes, new_pairs, ranges(dg))
    end
    return dg
end


function transform(trans::MergeForward, dn::DecisionNetwork)
    G = transform(trans, graph(dn))
    all_impls = implementation(dn)
    new_impls = []
    for (rv, impl) in pairs(all_impls)
        if rv ∈ trans.nodes
            continue
        end
        new_impl = impl
        for input in nodes(dn)[rv][1]
            if name(input) ∈ trans.nodes
                if name(input) ∈ keys(all_impls)
                    new_impl = MergedDist(new_impl, name(input) => all_impls[name(input)])
                else
                    throw(ArgumentError("Cannot merge unimplemented node $(name(input)) \
                    into implemented node $rv"))
                end
            end
        end
        push!(new_impls, rv => new_impl)
    end
    G(; new_impls...)
end


"""
    Rename <: DNTransformation
    Rename(; names...)

Rename nodes in a decision network.

Each keyword argument maps an old to new node name.
"""
struct Rename{N<:NamedTuple} <: DNTransformation
    names::N
    function Rename(; names...) 
        t = names |> NamedTuple
        new{typeof(t)}(t)
    end
end
# TODO: It's not great that such a simple transformation is kind of complicated

function transform(trans::Rename, dg::DecisionGraph)
    new_nodes = map(values(nodes(dg))) do node
        inputs = map(node[1]) do input
            if name(input) ∈ keys(trans.names)
                rename(input, trans.names[name(input)])
            else
                input
            end
        end
        output = if name(node[2]) ∈ keys(trans.names)
            rename(node[2], trans.names[name(node[2])])
        else
            node[2]
        end
        inputs => output
    end
    new_dynnames = map(keys(dynamic_pairs(dg))) do rv
        (rv ∈ keys(trans.names)) ? trans.names[rv] : rv
    end
    new_dynvals = map(values(dynamic_pairs(dg))) do rv
        (rv ∈ keys(trans.names)) ? trans.names[rv] : rv
    end
    new_dyn = NamedTuple{new_dynnames}(new_dynvals)

    if isnothing(ranges(dg))
        DecisionGraph(new_nodes, new_dyn, nothing)
    else
        new_idxnames = map(keys(ranges(dg))) do rv
            (rv ∈ keys(trans.names)) ? trans.names[rv] : rv
        end
        new_idxs = NamedTuple{new_idxnames}(values(ranges(dg)))
        DecisionGraph(new_nodes, new_dyn, new_idxs)
    end
end

function transform(trans::Rename, dn::DecisionNetwork)
    G = transform(trans, graph(dn))

    impls = implementation(dn)
    new_names = map(keys(impls)) do rv
        (rv ∈ keys(trans.names)) ? trans.names[rv] : rv
    end
    new_dists = map(values(impls)) do dist
        new_conds = map(conditions(dist)) do rv
            new_rv = (rv ∈ keys(trans.names)) ? trans.names[rv] : rv
            rv => new_rv
        end
        RenamedDist(dist; new_conds...)
    end
    new_impls = NamedTuple{new_names}(new_dists)
    G(; new_impls...)
end


"""
    SetNodeHints <: DNTransformation
    SetNodeHints(node; hints...)

Transformation which sets the node hints for a node in a network.
"""
struct SetNodeHints{H} <: DNTransformation
    node::Symbol
    hints::H
    function SetNodeHints(node; hints...) 
        ht = hints |> NamedTuple
        new{typeof(ht)}(node, ht)
    end
end

function transform(trans::SetNodeHints, dn::DecisionGraph)

    new_nodes = map(values(nodes(dn))) do node_def
        if name(node_def[2]) == trans.node
            new_node_output = with_hints(node_def[2]; trans.hints...)
            node_def[1] => new_node_output
        else
            node_def
        end
    end
    DecisionGraph(new_nodes, dynamic_pairs(dn), ranges(dn))
end
transform(trans::SetNodeHints, dn::DecisionNetwork) = _default_transform(trans, dn)
