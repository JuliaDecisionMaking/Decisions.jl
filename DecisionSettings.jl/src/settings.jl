"""
    DecisionEnvironment
"""
abstract type DecisionEnvironment end

# FIXME: move elsewhere probably
abstract type DecisionAgent end

"""
    evaluate(env::DecisionEnvironment, bhv, stopping_metric, metrics...) where {DN}

Run a single contiguous interaction between joint agent behavior `behavior` and the
environment `env` until stopped, aggregating environment output into `metrics`, until the
output of `stopping_metric` is `false`.

Returns the output of `metrics` as a Tuple.
"""
function evaluate(env::DecisionEnvironment, bhv, stopping_metric, metrics...) end

"""
    reset!(env::DecisionEnvironment)

Return `env` to a pre-interaction state.
"""
function reset!(env::DecisionEnvironment) end


"""
    DecisionSetting

Abstract base type for a decision setting, which specifies how and when information from an
environment is distributed to decision agents.
"""
abstract type DecisionSetting end

"""
    agents(setting::DecisionSetting)

Return the collection of `DecisionAgent`s that interact in this setting.
"""
function agents end

"""
    environment(setting::DecisionSetting)

Return the `DecisionEnvironment` in which agents interact in this setting.
"""
function environment end

"""
    evaluate(s::DecisionSetting, metrics...)

Evaluate `metric` or `metrics` over a series of interactions between `agents(setting)` and
`environment(setting)`.

`setting` determines when data is aggregated to the metric. After the entire series of
interactions is completed, returns the output of the metric (if a single metric was
provided) or a Tuple of outputs (if multiple metrics were provided), and `reset!`s the
metric(s).
"""
function evaluate end


struct Online <: DecisionSetting 
    agents::Tuple{Vararg{<:DecisionAgent}}
    env::DecisionEnvironment
    stopping_metric::DecisionMetric
    function Online(env, agents...; stopping_metric=NeverStop()) 
        new(agents |> Tuple, env, stopping_metric)
    end
end

environment(s::Online) = s.env
agents(s::Online) = s.agents

function evaluate(s::Online, metrics...)    
    agent_params = map(agents(s)) do agent
        init_parameters(agent)
    end
    bhv = behavior(agents(s), agent_params)

    evaluate(environment(s), bhv, s.stopping_metric, metrics...)
end


struct MultipleInteractions <: DecisionSetting 
    agents::Tuple{Vararg{<:DecisionAgent}}
    env::DecisionEnvironment
    inner_metrics::Tuple{Vararg{DecisionMetric}}
    inner_stopping_metric::DecisionMetric
    outer_stopping_metric::DecisionMetric
    function MultipleInteractions(
        inner_metrics, env, agents...; 
        inner_stopping_metric=NeverStop(), 
        outer_stopping_metric=MaxIters(100)) 
        new(agents |> Tuple, env, inner_metrics |> Tuple, inner_stopping_metric, outer_stopping_metric)
    end
end

environment(s::MultipleInteractions) = s.env
agents(s::MultipleInteractions) = s.agents

function evaluate(s::MultipleInteractions, outer_metrics...)
    # TODO: Metrics should really be kwargs so they're named
    #   otherwise "out" is super confusing

    agent_params = map(agents(s)) do agent
        init_parameters(agent)
    end
    agent_hparams = map(agents(s)) do agent
        init_hyperparameters(agent)
    end
    
    while true
        bhv = behavior(agents(s), agent_params)
    
        out = evaluate(environment(s), bhv, s.inner_stopping_metric, s.inner_metrics...)

        for metric in outer_metrics
            aggregate!(metric, (; params=agent_params, out))
        end

        agent_params = map(enumerate(agents(s))) do (i, agent)
            update_parameters!(agent, agent_params[i], out, agent_hparams[i])
        end

        aggregate!(s.outer_stopping_metric, (; params=agent_params, out))
        if output(s.outer_stopping_metric)
            result = map(outer_metrics) do metric
                output(metric)
            end
            reset!.(outer_metrics)
            reset!(s.outer_stopping_metric)
            return result
        end
    end

end


struct MultipleHyperInteractions <: DecisionSetting end



# function (::DecisionSetting)(fn, ::DecisionAgent, ::DecisionEnvironment) end



"""
    Simulated <: DecisionEnvironment

A decision environment that is simply a simulated (D)DN.

Simulation stops if the DN produces Terminal() or if the stopping metric outputs `false`.
"""
struct Simulated{DN <: DecisionNetwork} <: DecisionEnvironment 
    dn::DN
    initial_config::NamedTuple

    Simulated(dn::DN; kwargs...) where {DN} = new{DN}(dn, kwargs |> NamedTuple)
    Simulated(dn::DN, config) where {DN} = new{DN}(dn, config)
end

function evaluate(env::Simulated{DN}, bhv, stopping_metric, metrics...) where {DN}
    # TODO: Not using rng param
    regular_metrics = metrics |> Tuple
    inputs = map(env.initial_config) do dist
        if dist isa ConditionalDist
            dist(;)
        else
            dist
        end
    end
    sample(env.dn, bhv, inputs) do values
        for metric in regular_metrics
            aggregate!(metric, values)
        end
        aggregate!(stopping_metric, values)
        output(stopping_metric)
    end
    result = output.(metrics) |> Tuple
    reset!.(metrics)
    result
end

function reset!(env::Simulated{DN}) where {DN} end # nothing to do
