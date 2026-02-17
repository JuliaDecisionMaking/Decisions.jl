function Base.show(io::IO, z::DecisionNetwork)
    alias = Base.make_typealias(typeof(z))
    if isnothing(alias)
        print(io, "DecisionNetwork{…}:")
    else
        from = get(io, :module, Main)
        if (from === nothing || ! Base.isvisible(alias[1].name, alias[1].mod, from))
            show(io, alias[1].mod)
            print(io, ".")
        end
        print(io, alias[1].name)
        printstyled(io, " (alias for DecisionNetwork{…})", color=:light_black)
        print(io, ":")
    end

    node_strings = map(nodes(z)) do node_def
        string(expr(node_def[2]))
    end |> values
    cond_strings = map(nodes(z)) do node_def
        s = string.(expr.(node_def[1])) |> collect
        append!(s, string.(indices(node_def[2])))
        join(s, ", ")
    end |> values
    dist_strings = map(keys(nodes(z))) do rv
        if rv ∈ keys(implementation(z))
            string(Base.typename(typeof(z[rv])).wrapper)
        else
            ""
        end
    end
    
    dyna_strings = map(keys(dynamic_pairs(z))) do rv
        string(rv)
    end
    dynb_strings = map(dynamic_pairs(z)) do rv
        string(rv)
    end |> values

    idxs_strings = map(keys(ranges(z))) do idx
        string(idx)
    end
    rang_strings = map(ranges(z)) do n
        "1:$n"
    end |> values

    n_col_1 = maximum(length.([node_strings...; dyna_strings...; idxs_strings...]))
    n_col_2 = maximum(length.(cond_strings))
    
    for (a, b, c) ∈ zip(node_strings, cond_strings, dist_strings)
        print(io, 
            "\n",
            a,
            repeat(" ", n_col_1 - length(a)),
            " | ",
            b,
            repeat(" ", n_col_2 - length(b))
        )
        if isempty(c)
            printstyled(io, "  (no dist)", color=:light_black)
        else
            print(io, "  (", c, ")")
        end
    end

    for (a, b) ∈ zip(dyna_strings, dynb_strings)
        print(io,  
            "\n",
            a,
            repeat(" ", n_col_1 - length(a)),
            " => ",
            b
        )
    end

    for (a, b) ∈ zip(idxs_strings, rang_strings)
        print(io,  
            "\n",
            a,
            repeat(" ", n_col_1 - length(a)),
            " ∈ ",
            b
        )
    end
end