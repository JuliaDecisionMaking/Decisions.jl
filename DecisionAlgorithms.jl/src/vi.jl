struct ValueIteration <: DecisionAlgorithm
    max_iters::Int
end

function DecisionProblems.solve(alg::ValueIteration, prob::MDP)
    γ = prob.objective.discount
    r0 = zero(support(prob.model[:r]))
    rmin = typemin(r0)

    A = collect(support(prob[:a]))
    V = Dict(s => r0            for s ∈ support(prob[:s]))
    π = Dict(s => rand(A) for s ∈ support(prob[:s]))

    for _ in 1:alg.max_iters
        for s in support(prob[:s])
            Vs_best, a_best = rmin, rand(A)

            for a in support(prob[:a]; s)
                Vs = r0
                for sp in support(prob[:sp]; a, s)
                    Vs += prob[:r](; s, a, sp) # Assuming reward is deterministic; see #24
                    #= 
                    Even if assuming deterministic, shouldn't it be assuming
                    a deterministic distribution not just one value?
                    =# 
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
    (; a = @ConditionalDist valtype(π) begin
            rand(rng; s) = π[s]
            pdf(a;s) = float(a == π[s])
        end
    )
end

