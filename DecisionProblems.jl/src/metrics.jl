

"""
    DecisionMetric

A decision metric: an aggregator of outputs of a DecisionSetting, DecisionEnvironment, or
similar object. 

When called with one argument, performs `aggregate!`.

Unlike most Decisions.jl components they are allowed (and expected) to be mutable and
stateful. 
"""
abstract type DecisionMetric end

"""
    aggregate!(::DecisionMetric, values)

Aggregate values in the NamedTuple `values` into the metric.
"""
function aggregate! end

(dm::DecisionMetric)(values) = aggregate!(dm, values)

"""
    output(::DecisionMetric)

Give the current value of the aggregated metric calculated by the DecisionMetric.
"""
function output end

"""
    reset!(::DecisionMetric)

Resets the DecisionMetric to a state before aggregating.
"""
function reset! end


"""
    Discounted{id} <: DecisionMetric

Metric which aggregates a value labelled `id` as a discounted summation: every subsequent
`aggregate!` increases the discount and decreases the impact of future calls.

Discounting is forward-directed; that is, it is assumed that the first call to 
`aggregate!` is the least discounted.
"""
mutable struct Discounted{id} <: DecisionMetric
    #TODO: Doesn't make sense for semi-Markov; discount rate vs factor
    discount::Vector{Float64}
    cuml_discount::Vector{Float64}
    agg::Vector{Float64}
    Discounted(id::Symbol, discount::Float64)            = new{id}([discount], [1.0], [0.0])
    Discounted(id::Symbol, discount::Vector{Float64})    = new{id}(discount, ones(shape(discount)), zeros(shape(discount)))
    Discounted{id}(discount::Float64)            where {id} = new{id}([discount], [1.0], [0.0])
    Discounted{id}(discount::Vector{Float64})    where {id} = new{id}(discount, ones(shape(discount)), zeros(shape(discount)))
end

function aggregate!(dm::Discounted{id}, values) where {id}
    dm.agg = dm.agg .+ dm.cuml_discount .* values[id]
    dm.cuml_discount = dm.cuml_discount .* dm.discount
end

function reset!(dm::Discounted)
    dm.agg *= 0.0
    dm.cuml_discount = dm.cuml_discount .* 0.0 .+ 1.0
end

function output(dm::Discounted) 
    if length(dm.agg) == 1
        dm.agg[1]
    else
        dm.agg
    end
end

"""
    const DiscountedReward

Alias for `Discounted{:r}`.
"""
const DiscountedReward = Discounted{:r}



"""
    Trace{ids} <: DecisionMetric

Metric which simply aggregates all values labelled in the Tuple `ids` into Vectors.

If `ids` is the empty tuple, aggregates all values passed to it.
"""
mutable struct Trace{ids} <: DecisionMetric
    trace::Dict{Symbol, Vector} # Can't further specialize Vector; could be Any
    Trace(ids)   = new{ids}(Dict{Symbol, Vector}())
    Trace{ids}() where {ids} = new{ids}(Dict{Symbol, Vector}())
    Trace()      = new{( )}(Dict{Symbol, Vector}())
end

function aggregate!(t::Trace{ids}, values) where {ids}
    for id in ids
        if ! (id ∈ keys(t.trace)) 
            t.trace[id] = []
        end
        push!(t.trace[id], values[id])
    end
end

function aggregate!(t::Trace{()}, values) 
    for id in keys(values) # bad choice of naming `values`. Too abstract
        if ! (id ∈ keys(t.trace))
            t.trace[id] = []
        end
        push!(t.trace[id], values[id])
    end
end

function reset!(t::Trace)
    t.trace = Dict{Symbol, Vector}()
end

function output(t::Trace)
    t.trace
end


"""
    NIters <: DecisionMetric 

A metric that simply tracks the number of times it has been aggregated. 

More efficient for computing episode lengths than `length(output(t::Trace))`.
"""
mutable struct NIters <: DecisionMetric 
    t::Int
    MaxIters(max_t) = new(0, max_t)
end

aggregate!(dm::NIters, values) = (dm.t += 1)
reset!(dm::NIters) = (dm.t = 0)
output(dm::NIters) = dm.t

# TODO
"""
"""
mutable struct Constraints{N} <: DecisionMetric
    
end