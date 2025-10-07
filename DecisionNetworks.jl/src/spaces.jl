
"""
    abstract type Space{T}

Abstract base representation for spaces, possibly infinite sets of instances all backed by
type `T`.
"""
abstract type Space{T} end

Base.eltype(::Space{T}) where {T} = T
Base.zero(::Space{T}) where {T} = zero(T)
Base.one(::Space{T}) where {T} = one(T)
Base.length(::Space) = Inf

subspace(s::Space; kwargs...) = s

"""
    FiniteSpace{T, N} <: Space{T}

Representation of a finite set backed by type `T`.

Supports iteration.
"""
struct FiniteSpace{V, T} <: Space{T}
    elements::V
end 
# Didn't like that the number of elements is necessarily part of the type signature
# On the other hand, it required (at least temporarily) defining new constructers below
const Collection{T} = Union{
    AbstractArray{T},
    NTuple{N, T}
} where N

function FiniteSpace(collection::Collection{T}) where T
    FiniteSpace{typeof(collection), T}(collection)
end

FiniteSpace(gen::Base.Generator) = FiniteSpace(collect(gen))

Base.in(el, s::FiniteSpace) = el ∈ s.elements
Base.eltype(::FiniteSpace{V,T}) where {V,T} = T
Base.iterate(s::FiniteSpace) = iterate(s.elements)
Base.iterate(s::FiniteSpace, state) = iterate(s.elements, state)
Base.length(s::FiniteSpace) = length(s.elements)
Base.eachindex(s::FiniteSpace) = eachindex(s.elements)
Base.getindex(s::FiniteSpace, args...) = getindex(s.elements, args...)

index(collection::Collection{T}, x::T) where T = findfirst(==(x), collection)
index(space::FiniteSpace, x) = index(space.elements, x)

Random.gentype(::Type{FiniteSpace{V,T}}) where {V,T} = T
Base.rand(rng::AbstractRNG, s::Random.SamplerTrivial{<:FiniteSpace}) = rand(rng, s[].elements)

"""
    RangeSpace{T} <: Space{T}

Space representing range of set elements backed by type `T` from `lb` to `ub`, inclusive
(according to `≤`).
"""
struct RangeSpace{T} <: Space{T}
    lb::T
    ub::T
end

Base.in(el, s::RangeSpace) = (el <= s.ub) && (el >= s.lb)


"""
    TypeSpace{T} <: Space{T}

Space that is exactly coextensive with its backing type, `T`: that is, any instance of `T`
is an element of `T`.

TypeSpace{T} can also be used (with caution) to represent proper subsets of `T` when the
exact extent of the subset is unknown or difficult to calculate.  
"""
struct TypeSpace{T} <: Space{T} end

Base.in(el, ::TypeSpace{T}) where {T} = el isa T

Base.eltype(::TypeSpace{T}) where T = T
Random.gentype(::Type{TypeSpace{T}}) where T = T
Base.rand(rng::AbstractRNG, ::Random.SamplerTrivial{TypeSpace{T}}) where T = rand(rng, T)

"""
    SingletonSpace{T} <: Space{T}

Space that consists of exactly one element `el`.
"""
struct SingletonSpace{T} <: Space{T} 
    el::T
end

Base.in(el, s::SingletonSpace) = el == s.el
Base.iterate(s::SingletonSpace) = iterate((s.el,))
Base.iterate(s::SingletonSpace, state) = iterate((s.el,), state)
Base.length(::SingletonSpace) = 1
Base.eachindex(::SingletonSpace) = Base.OneTo(1)
Base.getindex(s::SingletonSpace, args...) = getindex((s.el,), args...)

index(s::SingletonSpace, x) = s.el == x ? 1 : nothing

Base.eltype(::SingletonSpace{T}) where T = T
Random.gentype(::Type{SingletonSpace{T}}) where T = T
Base.rand(::AbstractRNG, s::Random.SamplerTrivial{SingletonSpace{T}}) where T = s[].el


## FIXME: probably a better more robust way to do this
Space(collection::Collection) = FiniteSpace(collection)
Space(x) = TypeSpace(x)
