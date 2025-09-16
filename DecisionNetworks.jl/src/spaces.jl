
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
Base.iterate(s::FiniteSpace) = iterate(s.elements)
Base.iterate(s::FiniteSpace, state) = iterate(s.elements, state)
Base.length(s::FiniteSpace) = length(s.elements)


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


"""
    SingletonSpace{T} <: Space{T}

Space that consists of exactly one element `el`.
"""
struct SingletonSpace{T} <: Space{T} 
    el::T
end
