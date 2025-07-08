# Solvers are callable structs

@with_kw struct ValueIteration
    atol::Float64 # absolute tolerance - same abreviation as isapprox
end

function (vi::ValueIteration)(p::DecisionProblem)

end

function infinite_horizon_vi(ddn)
    T = distribution_matrix_dict(ddn[:sp]; row=:sp, column=:s, keys=:a)
    R = value_vector_dict(ddn[:r]; index=:s, keys=:a)
    gamma = discount(objective(p))

    n = length(space(ddn, :s))
    V = zeros(n)
    oldV = fill(-Inf, n)
    
    while maximum(abs, V-oldV) > solver.atol
        oldV[:] = V
        V[:] = max.((R[a] + gamma*T[a]*V for a in keys(R))...)
    end

    return V
end

function distribution_matrix_dict(node)
    
end
 
function value_vector_dict(node)

end
