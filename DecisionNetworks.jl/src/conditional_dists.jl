
"""
    ConditionalDist

A conditional distribution: a stochastic mapping from a set of conditioning variables `K` to
a random variable of type `T`.
"""
abstract type ConditionalDist{K, T} end

"""
    Base.eltype(::ConditionalDist{K, T}) where {K, T}

When applied to a `ConditionalDist`, give `T`, the type of values produced by the
distribution.
"""
Base.eltype(::ConditionalDist{K, T}) where {K, T} = T

"""
    support(cd::ConditionalDist{K, T}; kwargs...)

Give the support `Space` of the distribution when the conditioning variables `K` take on the
values in `kwargs` (if it is present), or a superspace containing it.

If no conditioning variables are provided, give the joint support `Space` over all
conditionings. Optionally, if some, but not all, conditioning variables are provided, the
joint support `Space` over the remaining conditioning variables should be returned.

By default, returns a `TypeSpace{T}`.
"""
function support(cd::ConditionalDist{K, T}; kwargs...) where {K, T}
    TypeSpace{T}()
end

"""
    conditions(cd::ConditionalDist)

Report the names of the conditioning variables of `cd` as a tuple of Symbols.
"""
conditions(::ConditionalDist{K, T}) where {K, T} = K


"""
    rand!(rng=default_rng(), cd::ConditionalDist{K, T}, dest::T; kwargs...) where {K, T}

Sample from a conditional distribution (in place using `dest` if possible), with the
conditioning variables taking on the values in `kwargs`.

Returns `dest` if in-place modification is successful; otherwise, returns a new instance.
By default, never modifies in place and defers to `rand`.
"""
function Random.rand!(rng::AbstractRNG, cd::ConditionalDist{K, T}, dest::T; kwargs...) where {K, T}
    rand(rng, cd; kwargs...)
end
function Random.rand!(cd::ConditionalDist{K, T}, dest::T; kwargs...) where {K, T}
    rand(Random.default_rng(), cd; kwargs...)
end


"""
    rand(rng=default_rng(), cd::ConditionalDist; kwargs...)

Sample from a conditional distribution, given values of conditioning variables in `kwargs`.

Equivalent to cd(; kwargs...).
"""
Random.rand(cd::ConditionalDist; kwargs...) = Random.rand(Random.default_rng(), cd; kwargs...)


"""
    fix(cd::ConditionalDist; fixed_args...)

Fix any number of variables conditioning a distribution to particular values, returning a
new conditional distribution conditioned on the variables that remain.

By default produces a FixedDist.
"""
function fix(cd::ConditionalDist; rvs...)
    FixedDist(cd; rvs...)
end


"""
    pdf(cd::ConditionalDist, x; kwargs...)

Gives the probability or probability density of a random variable distributed according to
`cd` with the value `x`, given values of conditioning variables in `kwargs`.

Equivalent to cd(x; kwargs...)
"""
function pdf end


"""
    logpdf(cd::ConditionalDist, x; kwargs...)

Gives the natural logarithm of the probability or probability density of the random variable
distributed according to `cd` having the value `x`, given values of conditioning variables
in `kwargs`.
"""
logpdf(cd::ConditionalDist, x; kwargs...) = exp(pdf(cd, x; kwargs...))


"""
    (cd::ConditionalDist)(; rng=default_rng(), kwargs...)

Sample a value from the conditional distribution `cd`, given values of the conditioning
variables given in `kwargs`.

Equivalent to rand(cd::ConditionalDist; kwargs...). This version mimics statistical
notation; i.e., with distribution `Q`, `Q(; a=1, b=2)` is analogous to ``x \\sim Q(\\cdot
\\mid a=1, b=2)``.
"""
function (cd::ConditionalDist{K, T})(
    ; rng=Random.default_rng(), kwargs...
)::Union{T, Terminal} where {K, T}
    Random.rand(rng, cd; kwargs...,)
end

"""
    (cd::ConditionalDist{F, P, S})(; meta=default_meta(), kwargs...) where {F, P, S}

Calculate the probability density of the conditional distribution `cd`, given values of the
conditioning variables given in `kwargs`. 

Equivalent to pdf(cd::ConditionalDist, x; kwargs...). This version mimics statistical
notation; i.e., with distribution `Q`, `Q(x; a=1, b=2)` is analogous to ``Q(x \\mid a=1,
b=2)``.
"""
function (cd::ConditionalDist)(x; kwargs...)::Float64
    pdf(cd, x; kwargs...)
end    


"""
    @ConditionalDist

Generate an anonymous conditional distribution definition from a set of functions.

The functions can be any of those in the ConditionalDist interface and must be named
accordingly, with the ::ConditionalDist argument omitted. They can be defined with the
`function` keyword or in the compact style. The names of conditioning variables are
automatically inferred from the names of keyword arguments.

The `rng` argument is mandatory in functions that use it.
"""
macro ConditionalDist(sample_type, block)

    fns = filter(block.args) do q
        Meta.isexpr(q, :function) || Meta.isexpr(q, :(=))
    end
    fn_defs = map(splitdef, fns)

    conditionals_defd_set = Set{Symbol}()
    for fn_def in fn_defs
        if haskey(fn_def, :kwargs) 
            for kw in fn_def[:kwargs]
                if kw isa Symbol
                    push!(conditionals_defd_set, kw)
                else
                    throw(ArgumentError("Keyword arguments (conditioning variables) must be \
                    explicit in @ConditionalDist. kwargs... and defaults not allowed."))
                end
            end
        end
    end

    conditionals_defd = Tuple(sort!([conditionals_defd_set...]))
    kwargs = [Expr(:kw, k, :nothing) for k in conditionals_defd]

    fns_defd = Symbol[]
    fn_block = quote end
    for fn_def in fn_defs
        fn_def[:body] = fn_def[:body] |> esc
        if haskey(fn_def, :args)
            fn_def[:args] = fn_def[:args] .|> esc
        end
        if haskey(fn_def, :kwargs)
            fn_def[:kwargs] = kwargs .|> esc
        end
        fn = combinedef(fn_def)
        name = fn_def[:name]
        push!(fns_defd, name)
        push!(fn_block.args, fn)
    end

    quote
        let
            $fn_block
            AnonymousDist($conditionals_defd, $(esc(sample_type)); $(fns_defd...))
        end
    end
end

"""
    AnonymousDist

An anonymous distribution: one defined with @ConditionalDist. 

It carries its implementation as higher order functions, so every `AnonymousDist` has a unique
type (not unlike anonymous functions).
"""
struct AnonymousDist{K, T, 
        SupportFn <: Union{Function, Missing}, 
        RandFn <: Union{Function, Missing},
        RandBangFn <: Union{Function, Missing},
        FixFn <: Union{Function, Missing},
        PdfFn <: Union{Function, Missing},
        LogPdfFn <: Union{Function, Missing}} <: ConditionalDist{K, T} 
    support::SupportFn
    rand::RandFn
    rand!::RandBangFn
    fix::FixFn
    pdf::PdfFn
    logpdf::LogPdfFn
    function AnonymousDist(
        K::Tuple{Vararg{Symbol}},
        ::Type{T}; 
        support::A = missing,
        rand::B = missing,
        rand!::C = missing,
        fix::D = missing,
        pdf::E = missing,
        logpdf::F = missing,
    ) where {T, A, B, C, D, E, F}
        new{K, T, A, B, C, D, E, F}(support, rand, rand!, fix, pdf, logpdf)
    end
end

function Random.rand(rng::AbstractRNG, cd::AnonymousDist{K, T}; kwargs...
)::Union{T, Terminal} where {K, T}
    cd.rand(rng; kwargs...)
end

function Random.rand(cd::AnonymousDist{K, T}; kwargs...
)::Union{T, Terminal} where {K, T}
    cd.rand(Random.default_rng(); kwargs...)
end

function fix(cd::AnonymousDist; kwargs...) 
    if ismissing(cd.fix)
        FixedDist(cd; kwargs...)
    else
        cd.fix(; kwargs...)
    end
end

function logpdf(cd::AnonymousDist, x; kwargs...)
    cd.logpdf(x; kwargs...)
end

function rand!(cd::AnonymousDist{K, T}, dest::T; kwargs...) where {K, T}
    rand!(Random.default_rng(), cd, dest; kwargs...)
end

function rand!(rng::AbstractRNG, cd::AnonymousDist{K, T}, dest::T; kwargs...
)::Union{T, Terminal} where {K, T}
    if ismissing(cd.rand!)
        rand(rng, cd; kwargs...)
    else
        cd.rand!(rng, dest; kwargs...)
    end
end

function pdf(cd::AnonymousDist, x; kwargs...)::Float64
    if ismissing(cd.pdf)
        exp(logpdf(cd, x; kwargs...))
    else
        cd.pdf(x; kwargs...)
    end
end

function support(cd::AnonymousDist{K, T}; kwargs...
) where {K, T}
    if ismissing(cd.support)
        TypeSpace{T}()
    else
        cd.support(; kwargs...)
    end
end

"""
    UndefinedDist

A distribution that has no PDF or sampling defined. Only its support is known.
"""
struct UndefinedDist{K, T, F<:Function} <: ConditionalDist{K, T}
    support::F
end

support(cd::UndefinedDist; kwargs...) = cd.support(; kwargs...)


function Base.convert(::Type{ConditionalDist{K}}, f::F) where {K, F<:Function}
    # TODO: Can't infer output type from `f` so this is horribly type instable
    AnonymousDist(K, Any; rand = f)
end

function Base.convert(::Type{ConditionalDist{K, T}}, s::Space{<:T}) where {K, T}
    f = (; kwargs...) -> s
    UndefinedDist{K, T, typeof(f)}(f)
end

function Base.convert(::Type{ConditionalDist{K}}, s::Space{T}) where {K, T}
    f = (; kwargs...) -> s
    UndefinedDist{K, T, typeof(f)}(f)
end

function Base.convert(::Type{Union{Terminal, A}}, x) where {A}
    Base.convert(A, x)
end


"""
    CompoundDist{K, T, Ki} <: ConditionalDist{K, T}

A distribution which implements P(⋅ | idx, ...) using a `Tuple` of P(⋅ | ...) distributions
(where `idx` maps into that tuple).

Useful for merging behavior of multiple agents into a single distribution.
"""
struct CompoundDist{K_new, T, K_old} <: ConditionalDist{K_new, T}
    dists::Tuple{Vararg{ConditionalDist{K_old, <:T}}}
    idx_var::Symbol

    function CompoundDist(dists...; idx, check_conditions=false)
        T = typejoin(eltype.(dists)...)
        K_old = conditions(dists[1])
        if check_conditions
            for dist in dists
                if conditions(dist) != K_old
                    throw(ArgumentError("Cannot compound distributions with different conditions:
                    $K_old and $(conditions(dist))"))
                end
            end
        end
        K = (K_old..., idx) |> Tuple
        new{K, T, K_old}(dists |> Tuple, idx)
    end
end

@generated function _rvs_for(::CompoundDist{K, T, K_new}, rvs) where {K, T, K_new}
    :(rvs[$(K_new)])
end

function _get_dist(cd::CompoundDist; kwargs...)
    cd.dists[kwargs[cd.idx_var]]
end

function rand!(rng::AbstractRNG, cd::CompoundDist{K, T}, dest::T; kwargs...) where {K, T}
    rand!(rng, _get_dist(cd; kwargs...), dest; rvs_for(cd, kwargs)...)
end
function rand!(cd::CompoundDist{K, T}, dest::T; kwargs...) where {K, T}
    rand!(_get_dist(cd; kwargs...), dest; rvs_for(cd, kwargs)...)
end

function support(cd::CompoundDist{K, T}; kwargs...) where {K, T}
    support(_get_dist(cd; kwargs...); rvs_for(cd, kwargs)...)
end

function Random.rand(rng::AbstractRNG, cd::CompoundDist; kwargs...)
    rand(rng, _get_dist(cd; kwargs...); rvs_for(cd, kwargs)...)
end

function Random.rand(cd::CompoundDist; kwargs...)
    rand(_get_dist(cd; kwargs...); rvs_for(cd, kwargs)...)
end

function fix(cd::CompoundDist; kwargs...)
    fix(_get_dist(cd; kwargs...); rvs_for(cd, kwargs)...)
end

function pdf(cd::CompoundDist, x; kwargs...)
    pdf(_get_dist(cd; kwargs...), x; rvs_for(cd, kwargs)...)
end

function logpdf(cd::CompoundDist, x; kwargs...)
    logpdf(_get_dist(cd; kwargs...), x; rvs_for(cd, kwargs)...)
end

"""
    FixedDist <: ConditionalDist

A conditional distribution that wraps another, maintaining values of fixed variables; also,
the default output of `fix`.

Forwards most standard `ConditionalDist` functions to its underlying distribution,
conditioned on the inputs and the fixed variables.
"""
struct FixedDist{K_new, T, K_old, D<:ConditionalDist{K_old, T}, V<:NamedTuple} <: ConditionalDist{K_new, T}
    base_dist::D
    values::V

    function FixedDist(cd; rvs...) 
        T = eltype(cd)
        K_old = conditions(cd)
        K_new = [rv for rv in K_old if rv ∉ keys(rvs)] |> Tuple
        v = rvs |> NamedTuple
        new{K_new, T, K_old, typeof(cd), typeof(v)}(cd, v)
    end
end

function rand!(rng::AbstractRNG, cd::FixedDist{K, T}, dest::T; kwargs...) where {K, T}
    rand!(rng, cd.base_dist, dest; kwargs..., cd.values...)
end
function rand!(cd::FixedDist{K, T}, dest::T; kwargs...) where {K, T}
    rand!(cd.base_dist, dest; kwargs..., cd.values...)
end

function support(cd::FixedDist{K, T}; kwargs...) where {K, T}
    support(cd.base_dist; kwargs..., cd.values...)
end

function Random.rand(rng::AbstractRNG, cd::FixedDist; kwargs...)
    rand(rng, cd.base_dist; kwargs..., cd.values...)
end

function Random.rand(cd::FixedDist; kwargs...)
    rand(cd.base_dist; kwargs..., cd.values...)
end

function fix(cd::FixedDist; kwargs...)
    # We'd like to avoid having recursive FixedDists
    new_fixes = merge(cd.values, kwargs |> NamedTuple)
    FixedDist(cd.base_dist; new_fixes...)
end

function pdf(cd::FixedDist, x; kwargs...)
    pdf(cd.base_dist, x; kwargs..., cd.values...)
end

function logpdf(cd::FixedDist, x; kwargs...)
    logpdf(cd.base_dist, x; kwargs..., cd.values...)
end


"""
    RenamedDist <: ConditionalDist

A conditional distribution that wraps another, renaming the conditioning variables.
"""
struct RenamedDist{K_new, T, K_old, D<:ConditionalDist{K_old, T}, N} <: ConditionalDist{K_new, T}
    base_dist::D

    function RenamedDist(cd; new_names...) 
        T = eltype(cd)
        K_old = conditions(cd)

        name_map = map(K_old) do rv
            new_rv = (rv ∈ keys(new_names)) ? new_names[rv] : rv
            rv => new_rv
        end |> NamedTuple

        K_new = values(name_map) |> _sorted_tuple
        @assert K_old == keys(name_map)
        new{K_new, T, K_old, typeof(cd), name_map}(cd)
    end

    # TODO: Prevent stacking RenamedDist needlessly
end

# TODO: This is really slow! Should be @generated
function _rvs_for(::RenamedDist{K_new, T, K_old, D, N}, rvs) where {K_new, T, K_old, D, N}
    reverse_map = (values(N) .=> keys(N)) |> NamedTuple
    values(reverse_map[keys(rvs)]) .=> values(values((rvs))) # ugh
end

function rand!(rng::AbstractRNG, cd::RenamedDist{K, T}, dest::T; kwargs...) where {K, T}
    rand!(rng, cd.base_dist, dest; _rvs_for(cd, kwargs)...)
end
function rand!(cd::RenamedDist{K, T}, dest::T; kwargs...) where {K, T}
    rand!(cd.base_dist, dest; _rvs_for(cd, kwargs)...)
end

function support(cd::RenamedDist{K, T}; kwargs...) where {K, T}
    support(cd.base_dist; _rvs_for(cd, kwargs)...)
end

function Random.rand(rng::AbstractRNG, cd::RenamedDist; kwargs...)
    rand(rng, cd.base_dist; _rvs_for(cd, kwargs)...)
end

function Random.rand(cd::RenamedDist; kwargs...)
    rand(cd.base_dist; _rvs_for(cd, kwargs)...)
end

# TODO: for now default fix is fine I guess

function pdf(cd::RenamedDist, x; kwargs...)
    pdf(cd.base_dist, x; _rvs_for(cd, kwargs)...)
end

function logpdf(cd::RenamedDist, x; kwargs...)
    logpdf(cd.base_dist, x; _rvs_for(cd, kwargs)...)
end

"""
    MergedDist <: ConditionalDist

A conditional distribution which merges two subdistributions, using one as an input for
another.
"""
struct MergedDist{K, T, rv, Ka, Ta, Kb} <: ConditionalDist{K, T}
    # I don't think there's any good way to prevent nested MergedDists
    #   (since we have to maintain every constituent dist anyway)
    dist_a::ConditionalDist{Ka, Ta}
    dist_b::ConditionalDist{Kb, T}
    # a => b
    function MergedDist(dist_b::ConditionalDist, input::Pair{Symbol, <:ConditionalDist})
        rv = input[1]
        dist_a = input[2]
        Ka = conditions(dist_a)
        Kb = conditions(dist_b)
        K = filter(s -> s != rv, (Ka..., Kb...)) |> Set |> _sorted_tuple
        Ta = eltype(dist_a)
        T = eltype(dist_b)
        new{K, T, rv, Ka, Ta, Kb}(dist_a, dist_b)
    end
end


@generated function _rvs_for_a(::MergedDist{K, T, rv, Ka, Ta, Kb}, rvs) where {K, T, rv, Ka, Ta, Kb}
    :(rvs[$(Ka)])
end
@generated function _rvs_for_b(cd::MergedDist{K, T, rv, Ka, Ta, Kb}, rvs) where {K, T, rv, Ka, Ta, Kb}
    Kb_only = [r for r in Kb if r != rv]
    :(rvs[$(Kb_only)])
end

function rand!(rng::AbstractRNG, cd::MergedDist{K, T, rv}, dest::T; kwargs...) where {K, T, rv}
    # TODO: No way to do this middle RV in place; annoying
    x = rand(rng, cd.dist_a; _rvs_for_a(cd, kwargs)...)
    rand!(rng, cd.dist_b, dest; _rvs_for_b(cd, kwargs)..., rv => x)
end
function rand!(cd::MergedDist{K, T, rv}, dest::T; kwargs...) where {K, T, rv}
    x = rand(cd.dist_a; _rvs_for_a(cd, kwargs)...)
    rand!(cd.dist_b, dest; _rvs_for_b(cd, kwargs)..., rv => x)
end

function support(cd::MergedDist{K, T}; kwargs...) where {K, T}
    # TODO: Also, weirdly, can't scope support on :a
    support(cd.dist_b; _rvs_for_b(cd, kwargs)...)
end

function Random.rand(rng::AbstractRNG, cd::MergedDist{K, T, rv}; kwargs...) where {K, T, rv}
    x = rand(rng, cd.dist_a; _rvs_for_a(cd, kwargs)...)
    rand(rng, cd.dist_b; _rvs_for_b(cd, kwargs)..., rv => x)
end

function Random.rand(cd::MergedDist{K, T, rv}; kwargs...) where {K, T, rv}
    x = rand(cd.dist_a; _rvs_for_a(cd, kwargs)...)
    rand(cd.dist_b; _rvs_for_b(cd, kwargs)..., rv => x)
end


"""
    CollectDist <: ConditionalDist

A deterministic conditional dist which simply stacks its inputs as a Tuple. 
"""
struct CollectDist{K, T} <: ConditionalDist{K, T}
    function CollectDist(el, rvs...)
        T = Tuple{[el for _ in rvs]...}
        new{rvs |> _sorted_tuple, T}()
    end
end

# TODO: Using default rand!

# TODO: Should be marked as deterministic

# TODO: No support(), even though it's totally possible

function Random.rand(rng::AbstractRNG, cd::CollectDist{K, T}; kwargs...) where {K, T}
    map(K) do k
        kwargs[k]
    end 
end


# Default `fix` is correct

# PDF is Dirac delta which we don't have implemented yet


"""
    UniformDist{K, T} <: ConditionalDist{K, T}

A discrete uniform distribution: selects elements from its finite support with equal
probability.
"""
struct UniformDist{K, T} <: ConditionalDist{K, T}
    support::Tuple{Vararg{T}} # TODO: Continuous support
    UniformDist{K}(t) where {K} = new{K, eltype(t)}(t |> Tuple)
    UniformDist(t) = new{(), eltype(t)}(t |> Tuple)
end

Random.rand(rng::AbstractRNG, cd::UniformDist; kwargs...) = rand(rng, cd.support)
Random.rand(cd::UniformDist; kwargs...) = rand(cd.support)
support(cd::UniformDist; kwargs...) = FiniteSpace(cd.support)

