


"""
    AnonymousDist{name}

Dummy struct representing some kind of conditional probability distribution with
no class of its own. Useful when it's convenient to define a conditional
distribution inside a function.

[@ADist(name)] is a shortcut for `AnonymousDist{name::Symbol}`. Thus anonymous
distributions with the same name are considered the same distribution (that is,
they are dispatched identically).

!!! warning

    Functions defined on anonymous distributions still respect scoping rules.
    If you define an anonymous distribution within a function, then define methods
    for `rand`, `pdf`, etc. _within_ that function, those methods will be unavailable
    outside the host function.
"""
struct AnonymousDist{name} end

"""
    @ADist(name)

References a probability distribution called `name` without explicitly defining
a class for it.

See [`AnonymousDist`](@ref).
"""
macro ADist(name) 
    quote
        Val{$(Meta.quot(name))}
    end
end
