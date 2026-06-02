# Decisions.jl
## Definitive decision problems in Julia
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliadecisionmaking.github.io/Decisions.jl/dev)

Decisions.jl is an ecosystem for canonical representations of decision problems, from the
most basic Markov decision processes, to rich and expressive multi-agent, semi-Markov,
multi-objective extensions, unifying decision-, control-, and game-theoretic models.

> [!WARNING] 
> Decisions.jl is under active development.
>

## Features
Decisions.jl represents decision problems using their underlying decision networks. A very broad and useful class of problems can be represented in this way. 
![](https://i.ibb.co/7LjCF13/ddns.png)

Decisions.jl provides transformations to change problem classes with minimal disruption to the domain or solver implementation. Common transformations from adding agents to belief spacing - which usually require a frustrating amount of code rewriting in a bespoke framework - can be deployed to Decisions.jl problems in just a few lines. Using these transformations, it's easy to intuitively navigate the space of problem classes by iteratively adding or removing components.

![](https://i.ibb.co/MKjz7zq/transforms.png)

Decisions.jl supports problem classes from the very common to the niche to the yet-unnamed. When possible, meaningful traits (like "partially observable" or "multiagent") relate these classes, forming a natural scaffold that can be traversed with transformations. 

![](https://i.ibb.co/5Ws5FXF6/problem-tree.png)

By leveraging Julia's just-in-time compilation, standard frameworking (sampling, rollouts, and so on) is automatically built for any decision problem that can be represented with a DDN. No more hand-writing simulator code for slight problem variations.


## Package structure
Decisions.jl is factored into three framework packages:

* **DecisionNetworks.jl** (closed beta) provides fundamental tools for the
  ecosystem: decision networks, conditional distributions, support
  spaces, and visualizations.
* **DecisionProblems.jl** (closed alpha) introduces objectives over decision
  networks and formal definitions of decision problems.
* **DecisionSettings.jl** (closed alpha) introduces real-world decision making
  scenarios, surgically defining concepts of agents, training loops, and environment
  interactions to permit truly exact comparisons between algorithms.

... and two implementation packages:

* **DecisionDomains.jl** provides implementations of common baseline decision
  making domains for benchmarking.
* **DecisionAlgorithms.jl** provides off-the-shelf implementations of classic
  decision-making algorithm.

If you're contributing to Decisions.jl, or you don't mind some unnecessary
dependencies, the package `Decisions` itself reexports all names from the packages listed
above, so you can just write `using Decisions`.

## Installation
Decisions.jl is not (yet) a registered Julia package. To use it, clone the repo and do:
```
julia --project
] dev path_to_repo
```
(in your desired Julia environment) to add it in development mode. Of course, if you're working
on Decisions.jl itself, no need to do this.

If you'd like a local copy of the Decisions.jl docs for development purposes, do:
```
cd ./docs
julia --project
include("make.jl")
```
