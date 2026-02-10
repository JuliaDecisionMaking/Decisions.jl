using GraphRecipes
using RecipesBase

"""
    as_graphs_jl(djl)

Give a Graphs.jl-style directed graph (that is, a `SimpleDiGraph`) corresponding to the 
`DecisionGraph` or `DecisionNetwork` `djl`.
"""
function as_graphs_jl(djl_graph::Union{DecisionGraph, DecisionNetwork})
    gjl_graph = SimpleDiGraph()
    id_map = Dict{Symbol, Int}()

    vertexlabel = String[]
    order = []

    for (i, rv) in enumerate(node_names(djl_graph))
        ret = add_vertex!(gjl_graph)
        id_map[rv] = i
        if ! ret
            throw(ArgumentError("Could not convert decision graph to Graphs.jl format"))
        end

        push!(vertexlabel, string(rv)) 
        push!(order, _node_order(djl_graph, rv))
    end

    for (rv, node_def) in pairs(nodes(djl_graph))
        (inputs, output) = node_def
        for input in inputs
            ret = add_edge!(gjl_graph, id_map[name(input)], id_map[name(output)])
            if ! ret
                throw(ArgumentError("Could not convert decision graph to Graphs.jl format"))
            end
        end
    end

    gjl_graph, id_map
end


@recipe function plot(dg::Union{DecisionGraph, DecisionNetwork})

    println("Getting dnplot args")
    g, id_map = as_graphs_jl(dg)
    
    # 1: Dynamically updated nodes should be readable left-to-right with their counterparts
    #   Unfortunately since GraphRecipes became part of Plots the pinning functionality
    #   is no longer exposed. So we have to do it in a roundabout way

    max_order = maximum([_node_order(dg, s) for s in node_names(dg)])
    pin_dict = Dict() # unspecified type
    for (y, (rv, rvp)) in enumerate(pairs(dynamic_pairs(dg)))
        pin_dict[rv]  = (-1, y)
        pin_dict[rvp] = (1, y)
    end
    pin = [rv ∈ keys(pin_dict) ? pin_dict[rv] : false for rv in node_names(dg)]
    points = NetworkLayout.spring(g; pin)
    x = [p[1] for p in points]
    y = [p[2] for p in points]

    # 2: Vertices should be labelled with their names
    #   GraphRecipes tends to be rather tight on the label margins so add a little padding
    names = map(node_names(dg)) do rv
        if rv ∈ keys(dynamic_pairs(dg))
            # This is a dynamic input
            rvp = dynamic_pairs(dg)[rv]
            source = nodes(dg)[rvp][2]
            if isempty(indices(source))
                " $(string(rv)) "
            else
                source_indices = join(indices(source), ", ")
                " $(string(rv))[$source_indices] "
            end
        else
            node_output = nodes(dg)[rv][2]
            " $(string(expr(node_output))) "
        end
    end

    # 3: Nodes should get the correct markers
    #   There's no formal concept of "node type" in Decisions. We assume unimplemented nodes
    #   are action nodes and leaf nodes are output nodes
    nodeshape = map(node_names(dg)) do rv
        _nodemarker(dg, rv)
    end |> collect

    # 4: Edges should be labelled by index
    edgelabel = Dict()
    for (rv_dest, node_def) in pairs(nodes(dg))
        (inputs, output) = node_def
        for input in inputs
            rv_source = name(input)
            text = join(indices(input), ", ")
            edgelabel[(id_map[rv_source], id_map[rv_dest])] = text
        end
    end

    # 5: Edges with no indices (dense edges) should be thicker
    function edgewidth(s, d, _)
        rv_s = node_names(dg)[s]
        rv_d = node_names(dg)[d]
        node_def = nodes(dg)[rv_d]
        for input in node_def[1]
            if name(input) == rv_s
                if ! isempty(indices(input))
                    return 2
                end
            end
        end
        return 1
    end


    layout_kw-->Dict(:x=>x, :y=>y, :free_dims=>[]),
    method-->:stress
    edgelabel-->edgelabel
    curves-->false
    names-->names
    markerstrokestyle-->_nodeoutline(dg)
    edgewidth-->edgewidth
    nodeshape-->nodeshape
    nodecolor-->[_nodecolor(dg, s) for s in node_names(dg)]
    g
end

_nodecolor(dn, s) = (s ∈ keys(nodes(dn))) ? :lightgray : :white

_nodeoutline(::DecisionGraph) = :dot
_nodeoutline(::DecisionNetwork) = :solid

function _diamond_shape(x, y, nodescale)
    [
        (x+nodescale/2, y),
        (x, y+nodescale/2),
        (x-nodescale/2, y),
        (x, y-nodescale/2),
    ]
end

function _square_shape(x, y, nodescale)
    [
        (x+nodescale/2, y+nodescale/2),
        (x-nodescale/2, y+nodescale/2),
        (x-nodescale/2, y-nodescale/2),
        (x+nodescale/2, y-nodescale/2),
    ]
end

function _nodemarker(dg::DecisionGraph, s::Symbol)
    :hexagon
end

function _nodemarker(dn::DecisionNetwork, s::Symbol)
    if s ∈ keys(dynamic_pairs(dn)) || s ∈ keys(implementation(dn))
        if isempty(children(dn, s))
            _diamond_shape
        else
            :circle
        end
    else
        _square_shape
    end
end