# Sloppy internals of decision networks. These are mostly used for generating the code in
# `simulate` and therefore executed at compile-time, so eloquence is not the primary
# concern. But, TODO, some cleaning up here would be appropriate.


"""
    _sorted_tuple(v)

Give a tuple containing the elements in v, sorted according to `sort`.

Useful for imposing a structure on a Tuple used as a type parameter.
"""
_sorted_tuple(t) = Tuple(sort(collect(t)))
_sorted_tuple(t::Symbol) = (t,)

"""
    _sortkeys(::NamedTuple)

Sort the keys in a NamedTuple (to enforce order invariance).
"""
@generated _sortkeys(nt::NamedTuple{KS}) where {KS} = :(NamedTuple{$(_sorted_tuple(KS))}(nt))

"""
    _get_dn_type_params(nodes, dynamic_pairs=nothing, ranges=nothing)

Standardize the type parameters for a decision network (imposing an order, making them the
correct types, etc.)

Output is a 3-tuple. `nodes` is required. If `dynamic_pairs` and `ranges` are not provided,
`nothing` is returned for them.
"""
function _standardize_dn_type(nodes, dynamic_pairs=nothing, ranges=nothing)
    defs = map(nodes) do node
        inputs = map(node[1]) do node
            convert(ConditioningGroup, node)
        end |> Tuple
        sorted_inputs = sort([inputs...]; lt = (a, b) -> (name(a) < name(b))) |> Tuple
        output = convert(Plate, node[2])
        sorted_inputs => output
    end |> Tuple
    names = map(defs) do def
        name(def[2])
    end
    nodes_standardized = NamedTuple{Tuple(names)}(defs)
    
    (
        _sortkeys(nodes_standardized),
        isnothing(dynamic_pairs) ? nothing : _sortkeys(dynamic_pairs),
        isnothing(ranges)        ? nothing : _sortkeys(ranges)
    )
end

"""
    _crawl_dn(dn, constituents, input, output)

Give all nodes required to compute nodes `output` of `dn`, given that nodes `input` are
known, in order.
"""
function _crawl_dn(dn, ids_in, ids_out)
    # We don't want to evaluate any plates we don't have to: only the ones between the
    # inputs and the outputs.
    dynamic_inputs = Symbol[k for k in keys(dynamic_pairs(dn)) if k ∈ ids_in]

    println(dynamic_inputs)

    input = [Set([ids_in...; keys(ranges(dn))...])...]  
    output = [Set([ids_out...; dynamic_pairs(dn)[dynamic_inputs]...])...]

    inter_nodes = Symbol[output...]
    req_nodes = Symbol[]

    while ! isempty(inter_nodes)
        node = popfirst!(inter_nodes)
        if ! ((node ∈ input) || (node ∈ req_nodes))
            push!(req_nodes, node)
            for child in conditions(dn, node)
                push!(inter_nodes, child)
            end
        end
    end

    sort!(req_nodes; by=(n) -> _node_order(dn, n))
end

"""
    _node_order(dn, rv)

Calculate the order of the random variable named `rv` in decision network `dn`; that is,
`n` such that `rv` is conditioned on random variables of at most order `n-1`. 
"""
function _node_order(dg, node; traversed=[])
    if (! isnothing(ranges(dg))) && (node ∈ keys(ranges(dg)))
        # indexing variables are always known with no ancestors
        return -1 
    end
    if ((! (node ∈ dg)) || isempty(conditions(dg, node)))
        # Node is an input or unconditioned
        return 0
    end
    if node ∈ traversed
        # Cycle detected
        return Inf
    end
    traversed = [traversed; node]
    1 + maximum([_node_order(dg, c; traversed) for c in conditions(dg, node)])
end

"""
    _make_node_initialization(dn, id)

Infer an expression that initializes an empty `MArray` of the correct size and name for node
`id` in `dn`.
"""
function _make_node_initialization(dn, id)
    output_def = nodes(dn)[id][2]

    isempty(indices(output_def)) && return nothing  # don't wrap non-arrays
    dims = map(indices(output_def)) do idx
        ranges(dn)[idx]
    end

    :(
        $id = MArray{
            Tuple{$(dims...)}, 
            eltype(dists[$(Meta.quot(id))]),
            length($dims),
            prod($dims)
        }(undef)
    )
end

"""
    _make_node_assignment(dn, id; in_place=false)

Generate an `Expr` that updates random variable `id` based on decision network `dn`.
"""
function _make_node_assignment(dn, id; in_place=false)
    inputs_def = nodes(dn)[id][1]
    output_def = nodes(dn)[id][2]

    # Generate the keywords arguments specifying the input of the node
    kws_rvs = map(inputs_def) do input
        Expr(:kw, name(input), expr(input))
    end

    kws_idxs = map(indices(output_def)) do idx_var
        Expr(:kw, idx_var, idx_var)
    end
    
    kws = Expr(:parameters, kws_rvs..., kws_idxs...)
    

    # Generate the rand / rand! call that samples the node (given the keywords)
    call = if in_place
        Expr(:call, :rand!, kws, :(dists[$(Meta.quot(id))]), expr(output_def))
    else
        Expr(:call, :rand, kws, :(dists[$(Meta.quot(id))]))
    end

    # Generate the block that actually assigns the R.V. to have the sampled value,
    #   and checks it for terminality.
    #   If we have the NotTerminable hint we can skip the check.
    assgn_block = if Terminality(nodes(dn)[id][2]) == NotTerminable()
        quote
            $(expr(output_def)) = $call
        end
    else
        tmp_id = gensym()
        quote
            $tmp_id = $call
            isterminal($tmp_id) && return
            $(expr(output_def)) = $tmp_id
        end
    end

    # Generate a loop around that block over the indices, if there are any
    if length(indices(output_def)) > 0
        loop_idxs = map(indices(output_def)) do idx_var
            n = ranges(dn)[idx_var]
            :($idx_var=1:$n)
        end
        Expr(:for, Expr(:block, reverse(loop_idxs)...), assgn_block)
    else
        assgn_block
    end
end