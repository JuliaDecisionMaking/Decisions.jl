# Visualization

```@setup viz
using Decisions
using Plots
```

## `Base.show`

Decision networks are pretty-printed to show the constituent random/indexing variables and
their conditions:

```@example viz
DecPOMDP_DN((; i = 4); sp = (; a, s) -> "successor state")
```
Ordinary random variables are shown with a conditioning bar. If there is a corresponding
conditional distribution implemented in the network, the type of the distribution is shown.
Past-iterate / future-iterate random variable pairs are denoted with `=>`, and indexing
variables are shown denoted with `∈`.

Plates which are independently sampled over one or more indices are shown with those indices
in array notation. Similarly, [`Parallel`](@ref) conditionings are also shown with their
indices. For instance, here, we see that the actions `a` for each player `i` are
independently sampled, using the corresponding player's memory from `m`.

Decision graphs are _not_ similarly pretty-printed, for [reasons related to Julia
internals](https://github.com/JuliaLang/julia/issues/29428).

## Plots.jl

Decisions.jl has Plots.jl support (via Graphs.jl). Use `plot` to visualize a `DecisionNetwork` or a `DecisionGraph` into a `Plots.jl` plot.

This can be very useful to debug the specific definition of particular decision graphs. For
instance, we can query the structure of a particular Dec-POMDP:

```@example viz
my_decpomdp = DecPOMDP_DN((; i=4); 
    o = (; s, a, i) -> "obs", 
    r = (; s, a, sp) -> "rwd",
    sp = (; s, a) -> "successor state"
)

plot(my_decpomdp)
```

As before, parallel edges and independently sampled nodes are denoted with array notation.

`sp` and `mp` are the next-iterate names for `s` and `m` (according to
[`dynamic_pairs`](@ref)). As such, `s` and `m` are always identities of last-iterate `sp`
and `mp`, which is represented with a white (rather than gray) infill in those nodes. 

Decisions.jl typically makes no innate distinction between action, output, and chance nodes,
but for purposes of visualization the following definitions are used:

* **Action** nodes (squares) are nodes without an implemented conditional distribution.
* **Output** nodes (diamonds) are leaf nodes.
* **Chance** nodes (circles) are all other nodes.

We can also query the structure of Dec-POMDPs _in general_ (that is, the decision graph
`DecPOMDP_DN`):

```@example viz
plot(DecPOMDP_DN)
```

Since only `DecisionNetworks` carry node implementations, without which it is impossible to
distinguish between action and chance nodes, all nodes in `DecisionGraphs` are rendered
as hexagons.

