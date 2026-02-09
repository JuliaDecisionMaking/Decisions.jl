

# Conditional distribution !eq DN with one node.
#   A DN with one node is a _labelled_ conditional distribution.

# So join can target:
# * Two conditional distributions
#   - Requires labels for each distribution
#   - Requires an edge to define direction
#   - Outputs a decision network

# * Two decision networks
#   - Requires list of new edges
#   - No two nodes can be the same

# A conditional distribution is ANY object for which rand, sample, etc. are defined.
#   Hints can provide some info about what's available.
#   Could output any kind of object.

# Decision networks are labelled, so everything wrt them always outputs a NamedTuple.

# support
# rand, rand!
# pdf, logpdf
# eltype
# params

# But there are some things that should only work on labelled dists (ie, networks):
# fix, unfix
# conditions


# Reserved random variable names
#   rng
#   meta
#   params
#   hparams





"""
    Base.eltype(distribution)

When applied to a conditional distribution (or distribution type), determine the
type of value sampled from the distribution. 
"""
Base.eltype

"""
    support(dist; conditions...)

Give an upper bound on the support space of the conditional distribution `dist`
when it is conditioned on `conditions...` (or, if no conditions are provided,
give the joint support space over all conditionings).

The returned space should follow the spaces interface (must implement `eltype`
and `in`). It need not be exact: it is possible that for some element `e ∈
`support(...)`, `pdf(dist, e; conditions...) == 0`.

By default, returns a `TypeSpace` over the `eltype` of the distribution (that
is, asserts only that values must be of the right type to be supported by the
distribution).
"""
function support(dist; conditions...)
    TypeSpace{eltype(dist)}()
end

"""
    rand!([rng::AbstractRNG,] cd; conditions...)

Draw a sample from the conditional distribution `cd`, in place with `dest` if
possible.

Returns `dest` if in-place modification is successful; otherwise, returns a new
instance. Defaults to `rand`.
"""
function Random.rand!(rng::AbstractRNG, cd, dest; conditions...)
    rand(rng, cd; kwargs...)
end
function Random.rand!(cd, dest; kwargs...)
    rand(Random.default_rng(), cd; kwargs...)
end

"""
    rand(rng=default_rng(), cd::ConditionalDist; kwargs...)

Draw a sample from the conditional distribution `cd` when it is conditioned on
`conditions`.
"""
Random.rand(cd::ConditionalDist; kwargs...) = Random.rand(Random.default_rng(), cd; kwargs...)


"""
    pdf(cd, x; conditions...)

Evaluate the probability mass or probability density of a random variable
distributed according to `cd` with the value `x`, given values of conditioning
variables in `conditions`.
"""
function pdf end


"""
    logpdf(cd, x; kwargs...)

Evaluate the natural logarithm of the probability mass or probability density of
the random variable distributed according to `cd` having the value `x`, given
values of conditioning variables in `kwargs`.
"""
logpdf(cd::ConditionalDist, x; kwargs...) = exp(pdf(cd, x; kwargs...))




# """
#     FixedDist <: ConditionalDist

# A conditional distribution that wraps another, maintaining values of fixed variables; also,
# the default output of `fix`.

# Forwards most standard `ConditionalDist` functions to its underlying distribution,
# conditioned on the inputs and the fixed variables.
# """
# struct FixedDist{K_new, T, K_old, D<:ConditionalDist{K_old, T}, V<:NamedTuple} <: ConditionalDist{K_new, T}
#     base_dist::D
#     values::V

#     function FixedDist(cd; rvs...) 
#         T = eltype(cd)
#         K_old = conditions(cd)
#         K_new = [rv for rv in K_old if rv ∉ keys(rvs)] |> Tuple
#         v = rvs |> NamedTuple
#         new{K_new, T, K_old, typeof(cd), typeof(v)}(cd, v)
#     end
# end

# function rand!(rng::AbstractRNG, cd::FixedDist{K, T}, dest::T; kwargs...) where {K, T}
#     rand!(rng, cd.base_dist, dest; kwargs..., cd.values...)
# end
# function rand!(cd::FixedDist{K, T}, dest::T; kwargs...) where {K, T}
#     rand!(cd.base_dist, dest; kwargs..., cd.values...)
# end

# function support(cd::FixedDist{K, T}; kwargs...) where {K, T}
#     support(cd.base_dist; kwargs..., cd.values...)
# end

# function Random.rand(rng::AbstractRNG, cd::FixedDist; kwargs...)
#     rand(rng, cd.base_dist; kwargs..., cd.values...)
# end

# function Random.rand(cd::FixedDist; kwargs...)
#     rand(cd.base_dist; kwargs..., cd.values...)
# end

# function fix(cd::FixedDist; kwargs...)
#     # We'd like to avoid having recursive FixedDists
#     new_fixes = merge(cd.values, kwargs |> NamedTuple)
#     FixedDist(cd.base_dist; new_fixes...)
# end

# function pdf(cd::FixedDist, x; kwargs...)
#     pdf(cd.base_dist, x; kwargs..., cd.values...)
# end

# function logpdf(cd::FixedDist, x; kwargs...)
#     logpdf(cd.base_dist, x; kwargs..., cd.values...)
# end


# """
#     RenamedDist <: ConditionalDist

# A conditional distribution that wraps another, renaming the conditioning variables.
# """
# struct RenamedDist{K_new, T, K_old, D<:ConditionalDist{K_old, T}, N} <: ConditionalDist{K_new, T}
#     base_dist::D

#     function RenamedDist(cd; new_names...) 
#         T = eltype(cd)
#         K_old = conditions(cd)

#         name_map = map(K_old) do rv
#             new_rv = (rv ∈ keys(new_names)) ? new_names[rv] : rv
#             rv => new_rv
#         end |> NamedTuple

#         K_new = values(name_map) |> _sorted_tuple
#         @assert K_old == keys(name_map)
#         new{K_new, T, K_old, typeof(cd), name_map}(cd)
#     end

#     # TODO: Prevent stacking RenamedDist needlessly
# end

# # TODO: This is really slow! Should be @generated
# function _rvs_for(::RenamedDist{K_new, T, K_old, D, N}, rvs) where {K_new, T, K_old, D, N}
#     reverse_map = (values(N) .=> keys(N)) |> NamedTuple
#     values(reverse_map[keys(rvs)]) .=> values(values((rvs))) # ugh
# end

# function rand!(rng::AbstractRNG, cd::RenamedDist{K, T}, dest::T; kwargs...) where {K, T}
#     rand!(rng, cd.base_dist, dest; _rvs_for(cd, kwargs)...)
# end
# function rand!(cd::RenamedDist{K, T}, dest::T; kwargs...) where {K, T}
#     rand!(cd.base_dist, dest; _rvs_for(cd, kwargs)...)
# end

# function support(cd::RenamedDist{K, T}; kwargs...) where {K, T}
#     support(cd.base_dist; _rvs_for(cd, kwargs)...)
# end

# function Random.rand(rng::AbstractRNG, cd::RenamedDist; kwargs...)
#     rand(rng, cd.base_dist; _rvs_for(cd, kwargs)...)
# end

# function Random.rand(cd::RenamedDist; kwargs...)
#     rand(cd.base_dist; _rvs_for(cd, kwargs)...)
# end

# # TODO: for now default fix is fine I guess

# function pdf(cd::RenamedDist, x; kwargs...)
#     pdf(cd.base_dist, x; _rvs_for(cd, kwargs)...)
# end

# function logpdf(cd::RenamedDist, x; kwargs...)
#     logpdf(cd.base_dist, x; _rvs_for(cd, kwargs)...)
# end

# """
#     MergedDist <: ConditionalDist

# A conditional distribution which merges two subdistributions, using one as an input for
# another.
# """
# struct MergedDist{K, T, rv, Ka, Ta, Kb} <: ConditionalDist{K, T}
#     # I don't think there's any good way to prevent nested MergedDists
#     #   (since we have to maintain every constituent dist anyway)
#     dist_a::ConditionalDist{Ka, Ta}
#     dist_b::ConditionalDist{Kb, T}
#     # a => b
#     function MergedDist(dist_b::ConditionalDist, input::Pair{Symbol, <:ConditionalDist})
#         rv = input[1]
#         dist_a = input[2]
#         Ka = conditions(dist_a)
#         Kb = conditions(dist_b)
#         K = filter(s -> s != rv, (Ka..., Kb...)) |> Set |> _sorted_tuple
#         Ta = eltype(dist_a)
#         T = eltype(dist_b)
#         new{K, T, rv, Ka, Ta, Kb}(dist_a, dist_b)
#     end
# end


# function _rvs_for_a(::MergedDist{K, T, rv, Ka, Ta, Kb}, rvs) where {K, T, rv, Ka, Ta, Kb}
#     k = Symbol[i for i ∈ Ka if i ∈ keys(rvs)]
#     rvs[k]
# end
# function _rvs_for_b(cd::MergedDist{K, T, rv, Ka, Ta, Kb}, rvs) where {K, T, rv, Ka, Ta, Kb}
#     # TODO
#     Kb_only = [r for r in Kb if r != rv]
#     k = Symbol[i for i ∈ Kb_only if i ∈ keys(rvs)]
#     rvs[k]
# end

# function rand!(rng::AbstractRNG, cd::MergedDist{K, T, rv}, dest::T; kwargs...) where {K, T, rv}
#     # TODO: No way to do this middle RV in place; annoying
#     x = rand(rng, cd.dist_a; _rvs_for_a(cd, kwargs)...)
#     rand!(rng, cd.dist_b, dest; _rvs_for_b(cd, kwargs)..., rv => x)
# end
# function rand!(cd::MergedDist{K, T, rv}, dest::T; kwargs...) where {K, T, rv}
#     x = rand(cd.dist_a; _rvs_for_a(cd, kwargs)...)
#     rand!(cd.dist_b, dest; _rvs_for_b(cd, kwargs)..., rv => x)
# end

# function support(cd::MergedDist{K, T}; kwargs...) where {K, T}
#     # TODO: Also, weirdly, can't scope support on :a
#     support(cd.dist_b; _rvs_for_b(cd, kwargs)...)
# end

# function Random.rand(rng::AbstractRNG, cd::MergedDist{K, T, rv}; kwargs...) where {K, T, rv}
#     x = rand(rng, cd.dist_a; _rvs_for_a(cd, kwargs)...)
#     rand(rng, cd.dist_b; _rvs_for_b(cd, kwargs)..., rv => x)
# end

# function Random.rand(cd::MergedDist{K, T, rv}; kwargs...) where {K, T, rv}
#     x = rand(cd.dist_a; _rvs_for_a(cd, kwargs)...)
#     rand(cd.dist_b; _rvs_for_b(cd, kwargs)..., rv => x)
# end

# function pdf(cd::MergedDist{K, T, rv}, x; kwargs...) where {K, T, rv}
#     # TODO, only works in discrete case
#     akw = _rvs_for_a(cd, kwargs)
#     bkw = _rvs_for_b(cd, kwargs)
#     sum([support(cd.dist_a; akw...)...]) do a
#         pa = pdf(cd.dist_a, a; akw...)
#         pb = pdf(cd.dist_b, x; bkw..., rv => a)
#         pa * pb
#     end
# end


# """
#     CollectDist <: ConditionalDist

# A deterministic conditional dist which simply stacks its inputs as a Tuple. 
# """
# struct CollectDist{K, T} <: ConditionalDist{K, T}
#     function CollectDist(el, rvs...)
#         T = Tuple{[el for _ in rvs]...}
#         new{rvs |> _sorted_tuple, T}()
#     end
# end

# # TODO: Using default rand!

# # TODO: Should be marked as deterministic

# function support(cd::CollectDist{K, T}; kwargs...) where {K, T}
#     r = map(K) do k
#         kwargs[k]
#     end 
#     FiniteSpace([r])
# end

# function Random.rand(rng::AbstractRNG, cd::CollectDist{K, T}; kwargs...) where {K, T}
#     map(K) do k
#         kwargs[k]
#     end 
# end

# function pdf(cd::CollectDist{K, T}, x; kwargs...) where {K, T}
#     # TODO: For continuous this is Dirac delta
#     #   Currently assuming discrete.
#     r = map(K) do k
#         kwargs[k]
#     end 
#     (x == r) ? 1.0 : 0.0
# end




# """
#     UniformDist{K, T} <: ConditionalDist{K, T}

# A discrete uniform distribution: selects elements from its finite support with equal
# probability.
# """
# struct UniformDist{K, T} <: ConditionalDist{K, T}
#     support::Tuple{Vararg{T}} # TODO: Continuous support
#     UniformDist{K}(t) where {K} = new{K, eltype(t)}(t |> Tuple)
#     UniformDist(t) = new{(), eltype(t)}(t |> Tuple)
# end

# Random.rand(rng::AbstractRNG, cd::UniformDist; kwargs...) = rand(rng, cd.support)
# Random.rand(cd::UniformDist; kwargs...) = rand(cd.support)
# support(cd::UniformDist; kwargs...) = FiniteSpace(cd.support)

