# Algorithms

A _decision algorithm_ takes in a `DecisionProblem` and outputs conditional distributions
for action nodes in the problem model based on the problem objective.

## A warning about decision environments 

In DecisionProblems.jl, no distinction is made between the model of an environment
(expressed by `model(::DecisionProblem)`) and the environment itself. As such, agents are
free to use the problem model in any way they choose, but there is no guarantee that the
provided `DecisionProblem` is reflective of a "real" environment. More specifically, there
is no structure defining the way in which an algorithm would get data from the real
environment, as they would in a traditional learning pipeline. Relatedly, in multi-agent
settings, complex interactions between agents that may differ in the training and execution
stages affect the problem significantly, and `DecisionProblems` alone does not specify how
agents receive information about other agents.

For algorithm design and prototyping purposes it's typically fine to just use
`DecisionProblems` and wrap it in your preferred setup for dealing with the ground truth
environment. However, if you'd like to make totally exact comparisons that ensure algorithms
are being used in identical settings, or you're just tired of writing this sort of
boilerplate code, you may wish to additionally use `DecisionSettings.jl`.

!!! todo

    DecisionSettings is still undergoing initial development. It is not yet suitable for use.

## Using decision algorithms

Algorithms have a sole method to define, `solve`:

```@docs
solve
```

`solve` should return a NamedTuple, where each name is a random variable for an action node
and each value is an implementation for that node. 


With this defined, an algorithm's performance can be simulated:

```@docs
simulate!
```

`simulate!` allows one to pass through additional metrics other than the objective of the
problem, which can be useful in monitoring side considerations or tracing the path of the
agent. Note that `simulate!` is not a pure function: it calls `reset!` and `aggregate!` on
the provided metrics.

## Multiagency in solvers

You may notice that in a multiagent situation (for instance an [`MG`](@ref)), there is only
a single action node to implement (which has an agent index). This makes it somewhat
confusing to write a solver for only a single agent. In other words, a single `solve!` is
expected to provided _all_ the missing agent behavior in the model.

Here it is important to differentiate _algorithms_ from _agents_. A decision algorithm just
fills in nodes in a model according to an objective. An _agent_, on the other hand, has
complex interactions with and about other agents. Since these interactions aren't specified
in a decision algorithm alone, decision algorithms don't have an identity: there is no "ego"
agent to a decision algorithm. As such, decision algorithms make assumptions about the
relationship between players: For instance, in a game-theoretic setting it is assumed all
agents act mutually rationally, and when one "solves" a game (i.e., for a Nash equilibrium),
distributions for all players are given.



