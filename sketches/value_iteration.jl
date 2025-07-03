#=

Must be infinitely repeated or finitely repeated DDN

DDN must have s, sp, a, r.
Must be either an InfinitelyRepeatedDDN or a FinitelyRepeatedDDN (could also imagine a version for a DN).
Must be single agent.
s and sp, and a must have discrete spaces


The problem with POMDPs.jl is that you couldn't reliably check these things.

=#


# Option 1: Assumptions
# =====================
function solve(solver::ValueIterationSolver, p::DecisionProblem)
    @assumption(n_agents(p) == 1)
    @assumption(network(p) isa Union{FinitelyRepeatedDDN, InfinitelyRepeatedDDN})

    ddn = dynamic(network(p))
    @assumption(hasnode(ddn, :s))
    @assumption(hasnode(ddn, :a))
    @assumption(hasnode(ddn, :sp))
    @assumption(hasnode(ddn, :r))
    @assumption(isfinite(space(ddn[:s])))
    @assumption(isfinite(space(ddn[:sp])))
    @assumption(isfinite(space(ddn[:a])))
    @assumption(Set(parents(ddn, :sp)) == Set((:s, :a))) # Set makes this order-invariant

    obj = objective(p)
    @assumption(obj isa DiscountedRewardSum)

    p2 = p |> ModifyDDN(ConditionalMean(:r, (:s, :a)))

    policy, value = vi(p)
    return policy
end

# Option 2: Transformation
# ===================
function solve(solver::ValueIterationSolver, p::DecisionProblem)
    @assumption(network(p) isa Union{FinitelyRepeatedDDN, InfinitelyRepeatedDDN})

    obj = objective(p)
    @assumption(obj isa DiscountedRewardSum)

    p2 = p |> ModifyDDN(MakeForm(DDNForms.FiniteMDP)) # Resulting problem satisfies all of the assumptions above

    policy, value = vi(p)
    return policy
end

function vi(solver::ValueIterationSolver, p::DecisionProblem{<:InfinitelyRepeatedDDN})
    ddn = dynamic(network(p))

    T = distribution_matrix_dict(ddn, :sp; row=:sp, column=:s, keys=:a)
    R = value_vector_dict(ddn, :r; index=:s, keys=:a)
    gamma = discount(objective(p))

    n = length(space(ddn, :s))
    V = zeros(n)
    oldV = fill(-Inf, n)
    
    while maximum(abs, V-oldV) > solver.tol
        oldV[:] = V
        V[:] = max.((R[a] + gamma*T[a]*V for a in keys(R))...)
    end

    return V
end

function vi(solver::ValueIterationSolver, p::DecisionProblem{<:FinitelyRepeatedDDN})
    dn = network(p)

    # work backwards from last stage   

    return V
end


