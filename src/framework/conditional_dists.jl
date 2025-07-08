
# Probably this should be turned into a true type hierarchy


"""
    NO_PDF

Placeholder used for generative-only anonymous distributions; that is, distributions where
the PDF is not known.
"""
const NO_PDF = (x; kwargs...) ->
    throw(ArgumentError("This distribution is generative only (no PDF defined)."))


"""
    ConditionalDist

A conditional distribution: a random mapping from a set of conditioning variables to the
value of a random variable of type `T`.

A conditional distribution `cd` has generative function `cd(; <conditioning variables...>)` and
(optional) probability density function PDF `cd(<value of RV>; <conditioning
variables...>)` mimicking statistical notation with the semicolon replacing the
conditioning bar. They also include their own `support` - that is, the `Space` of possible
outputs.
"""
abstract type ConditionalDist{T} end


"""
    support(cd::ConditionalDist{T}; kwargs...)

Give the support `Space` of the distribution when the conditioning variables take on the
values in `kwargs` (if it is present), or a superspace containing it.

If no conditioning variables are provided, give the joint support `Space` over all
conditionings. Optionally, if some, but not all, conditioning variables are provided, the
joint support `Space` over the remaining conditioning variables should be returned.

By default, returns `TypeSpace{T}`.
"""
function support(cd::ConditionalDist{T}; kwargs...) where {T}
    TypeSpace{T}()
end


"""
    rand!(rng=default_rng(), cd::ConditionalDist, dest; kwargs...)

Sample from a conditional distribution (in place using `dest` if possible), with the
conditioning variables taking on the values in `kwargs`.

Returns `dest` if in-place modification is successful; otherwise, returns a new instance.
By default, never modifies in place and defers to `rand`.
"""
function rand!(rng::AbstractRNG, cd::ConditionalDist, dest; kwargs...)
    rand(rng, cd; kwargs...)
end
function rand!(cd::ConditionalDist, dest; kwargs...)
    rand(Random.default_rng(), cd; kwargs...)
end


"""
    rand(rng=default_rng(), cd::ConditionalDist; kwargs...)

    Sample from a conditional distribution, given values of conditioning variables in 
    `kwargs`.

Equivalent to cd(; kwargs...).
"""
Base.rand


"""
    fix(cd::ConditionalDist; fixed_args...)

Fix any number of variables conditioning a distribution to particular values, returning a
new conditional distribution conditioned on the variables that remain.
"""
function fix end


"""
    pdf(cd::ConditionalDist, x; kwargs...)
    pdf(rng, cd::ConditionalDist, x; kwargs...)

Gives the probability or probability density of a random variable distributed according to
`cd` with the value `x`, given values of conditioning variables in `kwargs`.

Equivalent to cd(x; kwargs...)
"""
function pdf end


"""
    logpdf(cd::ConditionalDist, x; kwargs...)
    logpdf(rng, cd::ConditionalDist, x; kwargs...)

Gives the natural logarithm of the probability or probability density of a random variable
distributed according to `cd` with the value `x`, given values of conditioning variables in
`kwargs`.
"""
function logpdf end


"""
    fix(cd::ConditionalDist; kwargs...)

Fix any number of variables conditioning a distribution to particular values, returning a
new conditional distribution conditioned on the variables that remain.
"""


"""
    (cd::ConditionalDist)(; rng=default_rng(), kwargs...)

Sample a value from the conditional distribution `cd`, given values of the conditioning
variables given in `kwargs`.

Equivalent to rand(cd::ConditionalDist; kwargs...). This version mimics statistical
notation; i.e., with distribution `Q`, `Q(; a=1, b=2)` is analogous to ``x \\sim Q(\\cdot
\\mid a=1, b=2)``.
"""
function (cd::ConditionalDist{T})(; rng=Random.default_rng(), kwargs...)::Union{T, Terminal} where {T}
    rand(rng, cd; kwargs...,)
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


macro ConditionalDist(sample_type, block)

    fns = filter(block.args) do q
        Meta.isexpr(q, :function) || Meta.isexpr(q, :(=))
    end
    fn_defs = map(splitdef, fns)

    fns_defd = Symbol[]
    fn_block = quote end
    for fn_def in fn_defs
        fn_def[:body] = fn_def[:body] |> esc
        if haskey(fn_def, :args)
            fn_def[:args] = fn_def[:args] .|> esc
        end
        if haskey(fn_def, :kwargs)
            fn_def[:kwargs] = fn_def[:kwargs] .|> esc
        end
        fn = combinedef(fn_def)
        name = fn_def[:name]
        push!(fns_defd, name)
        push!(fn_block.args, fn)
    end

    quote
        let
            $fn_block
            AnonymousDist($sample_type; $(fns_defd...))
        end
    end
end


struct AnonymousDist{T, 
        SupportFn <: Union{Function, Missing}, 
        RandFn <: Union{Function, Missing},
        RandBangFn <: Union{Function, Missing},
        FixFn <: Union{Function, Missing},
        PdfFn <: Union{Function, Missing},
        LogPdfFn <: Union{Function, Missing}} <: ConditionalDist{T} 
    support::SupportFn
    rand::RandFn
    rand!::RandBangFn
    fix::FixFn
    pdf::PdfFn
    logpdf::LogPdfFn
    function AnonymousDist(
        ::Type{T}; 
        support::A = missing,
        rand::B = missing,
        rand!::C = missing,
        fix::D = missing,
        pdf::E = missing,
        logpdf::F = missing,
    ) where {T, A, B, C, D, E, F}
        new{T, A, B, C, D, E, F}(support, rand, rand!, fix, pdf, logpdf)
    end
end

support(cd::AnonymousDist; kwargs...) = cd.support(; kwargs...)
Base.rand(rng::AbstractRNG, cd::AnonymousDist; kwargs...) = cd.rand(rng; kwargs...)
Base.rand(cd::AnonymousDist; kwargs...) = cd.rand(Random.default_rng(); kwargs...)
fix(cd::AnonymousDist; kwargs...) = cd.fix(; kwargs...)
logpdf(cd::AnonymousDist, x; kwargs...) = cd.logpdf(x; kwargs...)

function rand!(cd::AnonymousDist, dest; kwargs...)
    rand!(Random.default_rng(), cd, dest; kwargs...)
end

function rand!(rng::AbstractRNG, cd::AnonymousDist, dest; kwargs...)
    if ismissing(cd.rand!)
        rand(rng, cd; kwargs...)
    else
        cd.rand!(rng, dest; kwargs...)
    end
end

function pdf(cd::AnonymousDist, x; kwargs...)
    if ismissing(cd.pdf)
        exp(logpdf(cd, x; kwargs...))
    else
        cd.pdf(x; kwargs...)
    end
end

function support(cd::AnonymousDist{T, A, B, C, D, E, F}; kwargs...) where {T, A, B, C, D, E, F}
    if ismissing(cd.support)
        TypeSpace{T}()
    else
        cd.pdf(x; kwargs...)
    end
end





"""
    ConditionalDist(fn [, 
        pdf::Function,
        support::Union{Space, Type, Function}
    ]; is_deterministic=false)


    ConditionalDist(fn, kws::Tuple{Varargs{Symbol}} [,
        pdf::Function,
        support::Union{Space, Type, Function}
    ]; is_deterministic=false)

Construct an anonymous conditional distribution from a generative function (and optionally a
`Space` support and/or a probability density function)`, conditioned on variables named in
the tuple `kws` (or, if not provided, whatever keyword arguments `fn` accepts).

If `kws` is provided, the names are associated with the (non-keyword) arguments of `fn` in
order, which allows for `do` block syntax to define conditional distributions. If `kws` is
not provided, conditioning variables will be passed to `fn` as keyword arguments. In this
case, `fn` must accept the `meta` keyword. 

If a PDF is provided, it must accept conditioning variables as keyword arguments (including
`meta`). Its only ordered argument must be the value of the random variable. If a PDF is not
provided, `NO_PDF` is used.

If a support is provided, it may be a fixed `Space` or a `Type` (which will be interpreted
as a `TypeSpace`). Either way, it must be true that that `fn(; ...) ∈ S`; that is, any
sample from the distribution must be in the space. If not provided, the support is assumed
to be `TypeSpace{Any}`; that is, any instance of any type could be sampled from the
distribution. Conditional supports cannot be specified with anonymous distributions.
"""
# # TODO: Benchmark this wrapper; possibly it can be moved to type space
# function ConditionalDist(fn, 
#     kws::Tuple{Vararg{Symbol}}, 
#     pdf=NO_PDF, 
#     support=TypeSpace{Any}; 
#     is_deterministic=false
# )
#     kw_gen = function(; kwargs...)
#         fn(kwargs[kws]...)
#     end
#     kw_pdf = function(x ; kwargs...)
#         pdf(x, kwargs[kws]...)
#     end
#     AnonymousDist(kw_gen, kw_pdf, support, is_deterministic)
# end

# function ConditionalDist(fn, 
#     pdf=NO_PDF, 
#     support=TypeSpace{Any}; 
#     is_deterministic=false
# )
#     AnonymousDist(fn, pdf, support, is_deterministic)
# end

# function support(cd::AnonymousDist)
#     cd.support
# end

# function support(cd::AnonymousDist; kwargs...)
#     subspace(cd.support; kwargs...)
# end

# """
#     Base.rand(rng=default_rng(), cd::ConditionalDist; kwargs...)

# Sample from a conditional distribution, conditioned on `kwargs`.

# Equivalent to `(cd::ConditionalDist)(; kwargs...)`.
# """
# function Base.rand(rng, cd::AnonymousDist; kwargs...)
#     meta = (; rng)
#     cd(; kwargs..., meta)
# end

# function Base.rand(cd::AnonymousDist; kwargs...)
#     cd(; kwargs..., meta)
# end


# function pdf(cd::AnonymousDist; kwargs...)
# end

# """
#     default_meta()

# Generate default meta-information for a conditional distribution.
# """
# default_meta() = (; rng=Random.default_rng())


# """
#     fix(cd::ConditionalDist; fixed_args...)

# Fix any number of variables conditioning a distribution to particular values, returning a
# new conditional distribution conditioned on the variables that remain.
# """
# function fix(cd::AnonymousDist{F, P, S}, support::S; fixed_args...) where {F, P, S}
#     reconditioned_gen = (; kwargs...) -> cd.f(; kwargs..., fixed_args...)
#     reconditioned_pdf = (x; kwargs...) -> cd.f(x; kwargs..., fixed_args...)
#     AnonymousDist{F, P, S}(reconditioned_gen, reconditioned_pdf, support)
# end

# function fix(cd::AnonymousDist; fixed_args...)
#     fix(cd, cd.support; fixed_args...)
# end

# function UniformDist(support::FiniteSpace{T}) where {T}
#     f = (; kwargs...) -> rand(meta.rng, support.elements)
#     d = (x ; kwargs...) -> 1 / length(support)

#     AnonymousDist(f,d, support)
# end

# function CategoricalDist(table_fn::Function, ::Type{T}, kws=nothing) where {T}
#     # TODO: Seems like there might be a more efficient representation of this `gen`
#     function gen(; meta, kwargs...)
#         table = table_fn(; kwargs...)
#         actions = keys(table)
#         r = rand(meta.rng)
#         for action in actions
#             r -= table[action]
#             if r <= 0
#                 return action
#             end
#         end
#     end
#     function pdf(x; kwargs...)
#         table_fn(kwargs...)[x]
#     end
#     function subspace_fn(; kwargs...)
#         FiniteSpace{T}(keys(table_fn(kwargs...)))
#     end
#     support = ConditionalSpace{T}(subspace_fn)

#     if isnothing(kws)
#         AnonymousDist(gen, pdf, support)
#     else
#         AnonymousDist(gen, kws, pdf, support)
#     end
# end

# function EmptyDist(support)
#     f = (; meta) -> Terminal()
#     AnonymousDist(f, NO_PDF, support)
# end

# # TODO: Should be able to generate Dirac PDF for this
# function DeterministicDist(args...)
#     AnonymousDist(args...; is_deterministic=true)
# end

# function SingletonDist(value::T) where {T}
#     f(; meta) = value
#     pdf(x; meta) = (x == value) ? Inf : -Inf
#     support = SingletonSpace{T}(value)
#     AnonymousDist(f, pdf, support, true)
# end