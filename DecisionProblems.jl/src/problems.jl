
"""
    DecisionProblem

A decision problem, formally stated: a union of a _model_, given as a `DecisionNetwork`, an
_objective_, given as a `DecisionNetwork`, and an optional initial distribution, given as a
ConditionalDist with no conditions.
"""
struct DecisionProblem{M <: DecisionMetric, DG <: DecisionNetwork, I <: Union{ConditionalDist{()}, Nothing}}
    model::DG
    objective::M
    initial::I
end

"""
    DecisionProblem(objective, initial=nothing, ranges=(;); dists...)

Construct a DecisionProblem from a model (a DecisionNetwork with index ranges `ranges` and
node implementations `dists`), an objective (a DecisionMetric), and an optional initial
distribution.

DecisionProblems can be indexed by random variable names (symbols), returning the
corresponding conditional distribution in the model.
"""
function (d::Type{<:DecisionProblem})(objective, initial=nothing, ranges=(;); dists...)
    network = graph(d)(ranges; dists...)
    DecisionProblem(network, objective, initial)
end

"""
    objective(dp::DecisionProblem)

Give the `DecisionMetric` that is the objective of `dp`.
"""
objective(dp::DecisionProblem) = dp.objective

"""
    model(dp::DecisionProblem)

Give the `DecisionNetwork` that is the model for `dp`.
"""
model(dp::DecisionProblem) = dp.model

"""
    graph(::DecisionProblem{M, DG})

When applied to a DecisionProblem, give the DecisionGraph for its underlying model.
"""
DecisionNetworks.graph(::DecisionProblem{M, DG}) where {M, DG} = DG

# This gets a little silly with the type params...
DecisionNetworks.graph(::Type{<:DecisionProblem{<:M, <:DecisionNetwork{A}}}) where {M, A} = DecisionNetwork{A}
DecisionNetworks.graph(::Type{<:DecisionProblem{<:M, <:DecisionNetwork{A, B}}}) where {M, A, B} = DecisionNetwork{A, B}
DecisionNetworks.graph(::Type{<:DecisionProblem{<:M, <:DecisionNetwork{A, B, C}}}) where {M, A, B, C} = DecisionNetwork{A, B, C}

"""
    initial(dp::DecisionProblem, s::Symbol)
    initial(dp::DecisionProblem)

Give an initial value for the random variable `s` in problem `dp` (or a NamedTuple for all
random variables for which an initialization is specified, if `s` is not given).
"""
initial(dp::DecisionProblem, s::Symbol) = dp.initial()[s]
initial(dp::DecisionProblem) = isnothing(dp.initial) ? (;) : dp.initial()


Base.getindex(dp::DecisionProblem, rv::Symbol) = dp.model[rv]

"""
    transform(t::DNTransformation, d::DecisionProblem)
    transform(t::DNTransformation, d::Type{<:DecisionProblem})

When applied to a `DecisionProblem` or a type of `DecisionProblem`, applies the
transformation on the underlying `DecisionNetwork` or `DecisionGraph`, respectively.
"""
function DecisionNetworks.transform(t::DNTransformation, d::DecisionProblem)
    DecisionProblem(
        transform(t, d.model),
        d.objective,
        d.initial
    )
end
function DecisionNetworks.transform(t::DNTransformation, ::Type{<:DecisionProblem{DG, M}}) where {DG, M}
    DecisionProblem{transform(t, DG), M}
end
