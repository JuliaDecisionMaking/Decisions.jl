

abstract type DecisionAlgorithm end

"""
    solve(da::DecisionAlgorithm, model::DecisionProblem)

Apply a decision algorithm to a model problem.

Should output a NamedTuple, where each name is an action node of the model's
`DecisionNetwork`, and each value is its solution `ConditionalDist`. 
"""
function solve end

"""
    simulate!(dp::DecisionProblem, da::DecisionAlgorithm...; metrics::DecisionMetric...)
    simulate!(fn, dp::DecisionProblem, da::DecisionAlgorithm...; metrics::DecisionMetric...)

Solve decision problem `dp` with algorithm(s) `da`, merge the behavior provided by the
algorithms into the decision network `network(dp)`, and roll out that network, aggregating
`metrics`, until terminal conditions are reached.

Returns a NamedTuple of metric outputs with names matching the keywords `metrics`, with an
additional entry always named `:objective` mapping to the output of `objective(dp)`.

If `fn` is provided, it is passed through to `sample` to enable early termination.
"""
function simulate!(fn, da::DecisionAlgorithm, dp::DecisionProblem; metrics...)

    reset!.([m for m in metrics])
    reset!(dp.objective)

    decisions = solve(da, dp)
    initialization = isnothing(dp.initial) ? (;) : dp.initial()
    if isnothing(fn)
        sample(dp.model, decisions, initialization) do rvs
            aggregate!(dp.objective, rvs)
            for other_metric in metrics
                aggregate!(other_metric, rvs)
            end
            false
        end
    else
        sample(dp.model, decisions, initialization) do rvs
            aggregate!(dp.objective, rvs)
            for other_metric in metrics
                aggregate!(other_metric, rvs)
            end
            fn(rvs)
        end
    end
    
    metrics_nt = NamedTuple(metrics) # ugh
    (; objective=output(dp.objective), map(output, metrics_nt)...)
end

function simulate!(da::DecisionAlgorithm, dp::DecisionProblem; metrics...)
    simulate!(nothing, da, dp; metrics...)
end
