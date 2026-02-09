"""
    CompoundDist(dists...; idx, strict=false)

A conditional distribution which implements P(⋅ | idx, ...) using multiple P(⋅ |
...) subdistributions `dists`. The random variable named by `idx` indexes which
subdistribution to sample (according to the order of `dists`).

If `strict=true`, the `idx` variable is filtered out of `conditions`, so
compounded distributions are not made aware of how they are indexed. This
has a slight overhead.

Useful for merging behavior of multiple agents into a single distribution.
"""
struct CompoundDist{strict, D<:Tuple}
    dists::D
    idx_var::Symbol

    function CompoundDist(dists...; idx, strict=false)
        new{strict}(dists |> Tuple , idx)
    end
end

function _get_dist(cd::CompoundDist; conditions...)
    cd.dists[conditions[cd.idx_var]]
end

function _get_subconditions(cd::CompoundDist{true}, conditions)
    Base.structdiff(conditions, NamedTuple{(cd.idx_var,)})
end

# If ! strict, we want to be able to compile this out - thus the type parameter
function _get_subconditions(::CompoundDist{false}, conditions)
    conditions
end

function Random.rand!(rng::AbstractRNG, cd::CompoundDist{K, T}, dest::T; conditions...) where {K, T}
    rand!(rng, _get_dist(cd; conditions...), dest; _get_subconditions(cd, conditions)...)
end
function Random.rand!(cd::CompoundDist{K, T}, dest::T; conditions...) where {K, T}
    rand!(_get_dist(cd; conditions...), dest; _get_subconditions(cd, conditions)...)
end

function support(cd::CompoundDist{K, T}; conditions...) where {K, T}
    support(_get_dist(cd; conditions...); _get_subconditions(cd, conditions)...)
end

function Random.rand(rng::AbstractRNG, cd::CompoundDist; conditions...)
    rand(rng, _get_dist(cd; conditions...); _get_subconditions(cd, conditions)...)
end

function Random.rand(cd::CompoundDist; conditions...)
    rand(_get_dist(cd; conditions...); _get_subconditions(cd, conditions)ns...)
end

function fix(cd::CompoundDist; conditions...)
    fix(_get_dist(cd; conditions...); _get_subconditions(cd, conditions)...)
end

function pdf(cd::CompoundDist, x; conditions...)
    pdf(_get_dist(cd; conditions...), x; _get_subconditions(cd, conditions)...)
end

function logpdf(cd::CompoundDist, x; conditions...)
    logpdf(_get_dist(cd; conditions...), x; _get_subconditions(cd, conditions)...)
end