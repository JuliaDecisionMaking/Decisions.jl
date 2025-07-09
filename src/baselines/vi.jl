# Solvers are callable structs

@with_kw struct ValueIteration
    atol::Float64 # absolute tolerance - same abreviation as isapprox
end

function (vi::ValueIteration)(p::DecisionProblem)

end

function infinite_horizon_vi(ddn)
    T = distribution_matrix_dict(ddn, :sp; row=:s, column=:sp, keys=:a)
    R = value_vector_dict(ddn, :r; index=:s, keys=:a)
    gamma = discount(objective(p))

    n = length(support(ddn[:s]))
    V = zeros(n)
    oldV = fill(-Inf, n)
    
    while maximum(abs, V-oldV) > solver.atol
        oldV[:] = V
        V[:] = max.((R[a] + gamma*T[a]*V for a in keys(R))...)
    end

    return V
end


function distribution_matrix_dict(ddn, node; row::Symbol, column::Symbol, keys::Union{Symbol, Tuple})
    @assert column == node # TODO: handle other cases
    @assert keys isa Symbol # TODO: handle multiple keys
    ConditionalTuple = NamedTuple{(row, keys), (eltype(support(ddn[row])), eltype(support(ddn[keys])))}

    d = Dict{eltype(support(ddn[keys])), SparseMatrixCSC{Float64, Int}}()
    for k in support(ddn[keys])
        is = Int[] # row
        js = Int[] # column
        ps = Float64[] # probabilities
        for (i, rowval) in enumerate(support(ddn[row]))
            conditionals = ConditionalTuple(rowval, k) # Can the compiler handle this?

            # TODO: This can be made sparse with a few more functions
            # dist = fix(ddn[column]; conditionals...)
            # for (val, p) in weighted_iterator(dist)
            #     j = index(support(ddn[column]), val)
  
            for (j, val) in enumerate(support(ddn[column]))
                p = ddn[column](val; conditionals...)
                if p > 0
                    push!(is, i)
                    push!(js, j)
                    push!(ps, p)
                end
            end
        end
        d[k] = mat
    end
    return d
end
 
function value_vector_dict(ddn, node; index::Symbol, keys::Union{Symbol, Tuple})
    @assert keys isa Symbol # will handle multiple keys later
    # TODO: assert isdeterministic(ddn[:node])
    ConditionalTuple = NamedTuple{(index, keys), (eltype(support(ddn[index])), eltype(support(ddn[keys])))}

    d = Dict{eltype(support(ddn[keys])), Vector{Float64}}()
    for k in support(ddn[keys])
        d[k] = zeros(length(support(node[index])))
        for (i, val) in enumerate(support(node[index]))
            conditionals = ConditionalTuple(val, k) #TODO: this is probably slow
            d[k][i] = node[:r](val; conditionals...)
        end
    end
    return d
end
