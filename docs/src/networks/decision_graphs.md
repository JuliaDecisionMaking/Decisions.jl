```@setup dgs
using Decisions
using Plots
```

# Decision graphs

Decision graphs are `Type`s of decision networks. More specifically, they are directed
acyclic graphs without any implementations for the conditional distributions backing the
nodes. Decisions.jl uses decision graphs to compile optimized code for any particular kind
of decision network. Additionally, DecisionNetworks.jl allows for modifying these decision
graphs to define new problem frameworks. As such, decision graphs are imbued with
significantly more functionality than Julia types in general.

One can extract the decision graph from a decision network using `graph`, or just plain old
`typeof`.

```@docs
graph
```

## Structure of decision graphs

### Random variable groups                                                                                        

Every node of a decision graph represents a random variable, or more specifically, a _plate_
of random elements (which is itself a random variable). Plates have `indexing variables`:
special named variables treated like random variables which indicate which element within a
plate is to be considered. Since indexing variables are treated like random variables,
instead of writing ``p(\cdot | ...)`` for all ``i`` (where `i` is an indexing variable), we
need only write ``p(\cdot | i, ...)``. 

`Plate`s can be jointly sampled across their elements, independently sampled, or joint on
some axes and independent on others. 

```@docs
DecisionNetworks.Plate
Joint
Indep
JointAndIndep
```

Each input into a plate is a group of random variables from another plate, which we call
_conditioning groups_. `ConditioningGroup`s can condition every element of a `Plate`
(many-to-many), or only those elements at corresponding indices (one-to-one).

```@docs
DecisionNetworks.ConditioningGroup
Dense
Parallel
```

Plates and conditioning groups know the name of the random variable they represent, as well
as the names of the indexing variables that index into them:

```@docs
name
indices
```

## Components of decision graphs
Decision graphs are represented with three components: 
1. An inputs => output definition for each node, 
2. Mappings from current-iterate to next-iterate nodes (for a dynamic decision network), and
3. The range of variables that index into each plate.
They can all be queried of both `DecisionNetwork`s and `Type{<:DecisionNetwork}`s.

```@docs
    nodes
    dynamic_pairs
    ranges
```

A number of convenience functions are also provided to make navigating `DecisionGraph`s
slightly easier:

```@docs
node_names
children
next
prev
```

## Defining decision graphs

DecisionNetworks.jl provides names for some of the most commonly used decision networks,
like those that represent MDPs and POMDPs. However, if you're using this package chances are
you'd like to define a much wider set of problems and networks based on concepts like
multiagency, semi-Markovness, decentralization, and correlation. While there are obviously
too many such extensions to name, Decisions.jl provides first-class support for any network
once its decision graph has been defined.

### Standard Markov family networks

Members of certain families of decision networks can be specified from a limited set of
traits. In particular, the family containing most Markov-style networks - and therefore the
vast majority of decision problems used today - can be defined using only six nodes and two
inputs:

* `s`: Current state
* `m`: Current [memory](@ref "What exactly are the `m`/`mp` nodes?")
* `sp`: Successor state; that is, **s**tate-**p**rime. The distribution that implements it
  is often called the _transition_. Dynamically paired with `s`.
* `mp`: Successor [memory](@ref "What exactly are the `m`/`mp` nodes?"); that is,
  **m**emory-**p**rime (a decision node).  
* `a`: Action (a decision node).
* `r`: Reward
* `o`: Observation
* `τ`: Sojourn time (for semi-Markov models)

There may also be up to two indexing variables present:
* `i`: Index over agents.
* `j`: Index over multiple rewards.

This the _standard Markov family_. Due to their ubiquity, Decisions.jl provides a shorthand
for defining these types of networks based on the [relevant traits](@ref "Traits on decision networks").

```@docs
    DecisionNetworks.@markov_alias
    DecisionNetworks.MarkovAmbiguousTraits
```


### Named network types

A few exceptionally important decision graphs have aliases provided by Decisions.jl. They
are all members of the [standard Markov family](@ref "Standard Markov family networks").

```@docs
  MDP_DN
  POMDP_DN
  MG_DN
  DecPOMDP_DN
```

You can use [transformations](@ref "Transformations") to transform these networks into your specific target.


## Defining networks by hand

If the type of decision network you'd like to work with isn't a standard Markov problem, and
can't easily be transformed from one, you may want to define it by hand.

A new type of decision network can be defined with the `DecisionGraph` constructor:

* `nodes` is a list of pairs, each one mapping node inputs (as `ConditioningGroup`s) to an
  output (as a `Plate`). 
* `dynamic_pairs` is a NamedTuple mapping current-iterate to future-iterate node names.
* `ranges` is a NamedTuple mapping indexing variable names to lengths.

For instance, we might want to define a mixed observability Markov decision problem with a
memory node. MOMDP networks aren't standard Markov networks due to the factored state, so we
should just define them manually:

```@example dgs
const MOMDP = DecisionGraph(
  [ # Six regular nodes (:xp, :yp, :r, :o, :mp, :a)
    (Dense(:x), Dense(:y), Dense(:a)) => Joint(:xp),
    (Dense(:x), Dense(:y), Dense(:a), Dense(:xp)) => Joint(:yp),
    (Dense(:x), Dense(:y), Dense(:a)) => Joint(:r),
    (Dense(:x), Dense(:y), Dense(:a)) => Joint(:o),
    (Dense(:x), Dense(:o), Dense(:a), Dense(:m)) => Joint(:mp),
    (Dense(:m),) => Joint(:a),
  ],
  (; # Three dynamic nodes (:x, :y, :m)
    :x => :xp,
    :y => :yp,
    :m => :mp
  ),
  (;) # No ranges
)

# Create a MOMDP with no node implementations at all
my_empty_MOMDP = MOMDP(;)
```

To visually double-check that your new decision graph is correct, use [`dnplot`](@ref) (though be
aware that networks with many nodes may render poorly):

```@example dgs
plot(MOMDP)
```

!!! tip

    For performance reasons, when defining a new decision graph for use later, it's
    recommended to mark it as `const`.

!!! warning

    Use the `DecisionGraph` constructor to get a `Type{<:DecisionNetwork}` rather than using
    `DecisionNetwork{...}` directly. This ensures that `nodes` and other parameters of the
    decision graph can have enforced structures (for instance, order invariance on inputs) to
    prevent ambuguity.