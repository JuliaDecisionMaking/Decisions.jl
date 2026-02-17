


"""
    AnonymousDist

Dummy struct representing some kind of conditional probability distribution with
no class of its own. Convenient when defining a conditional
distribution inside a function.

[`@ADist`](@ref) is a shortcut for `AnonymousDist{gensym(...)}`. 
"""
struct AnonymousDist{id, params} end

"""
    @ADist

Defines a new, unique type of conditional probability distribution with no name.

Every usage of @ADist returns a unique `Type`. This is convenient when defining
throwaway / single-use distributions within functions. These distributions do
not store any parameters (but parameters can be supplied via closure to `rand`,
etc.)

!!! warning

    Functions defined on anonymous distributions still respect scoping rules.
    If you define an anonymous distribution within a function, then define methods
    for `rand`, `pdf`, etc. _within_ that function, those methods will be unavailable
    outside the host function.


References a probability distribution called `name` without explicitly defining
a class for it.

See [`AnonymousDist`](@ref).
"""
macro ADist() 
    quote
        AnonymousDist{gensym(:adist), (;)}
    end
end

# Defaults for rand

function Base.getproperty(::AnonymousDist{id, params}, s) where {id, params}
    params[s]
end

function Base.rand(rng, d::AnonymousDist; conditions...)
    Base.rand(d; conditions...)
end

function Random.rand!(rng, d::AnonymousDist, dest; conditions...)
    Random.rand!(d, dest; conditions...)
end

function Random.rand!(d::AnonymousDist, dest; conditions...)
    Base.rand(d; conditions...)
end