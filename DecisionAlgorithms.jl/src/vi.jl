struct ValueIteration <: DecisionAlgorithm
    max_iters::Int
end

function get_full_statespace(prob::MDP)
    S = Set(support(prob.initial)[:s])
    for s ∈ S
        _get_states!(prob, S, s)
    end
    return S
end

function _get_states!(prob, S, s)
    isterminal(s) && return S
    A = support(prob[:a]; s)
    for a ∈ A
        for sp ∈ support(prob[:sp]; s, a)
            if sp ∉ S
                push!(S, sp)
                _get_states!(prob, S, sp)
            end
        end
    end
    S
end

function DecisionProblems.solve(alg::ValueIteration, prob::MDP)
    γ = prob.objective.discount
    r0 = zero(support(prob.model[:r]))
    rmin = typemin.(r0)
    S = get_full_statespace(prob)

    V = Dict(s => r0            for s ∈ support(prob[:s]))
    π = Dict(s => rand([support(prob[:a])...]) for s ∈ support(prob[:s]))

    for _ in 1:alg.max_iters
        for s in support(prob[:s])
            Vs_best, a_best = rmin, rand([support(prob[:a])...])

            for a in support(prob[:a]; s)
                Vs = r0
                for sp in support(prob[:sp]; a, s)
                    Vs += prob[:r](; s, a, sp) # Assuming reward is deterministic; see #24
                    if !isterminal(sp)
                        Vs += γ * prob[:sp](sp ; s, a) * V[sp]
                    end
                end
                if Vs > Vs_best
                    Vs_best, a_best = Vs, a
                end
            end
            V[s], π[s] = Vs_best, a_best
        end
    end
    (; a = @ConditionalDist Any begin
            rand(rng; s) = π[s]
        end
    )
end
