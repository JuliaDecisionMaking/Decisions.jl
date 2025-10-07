module DecisionNetworks

using Parameters
using Distributions
using Random
using ExprTools
using StaticArrays


using Graphs
using NetworkLayout

include("terminal.jl")
export Terminal
export terminal
export isterminal

include("hints.jl")
export DecisionsTrait
export Sequentiality
export Sequential
export Simultaneous

export Observability
export FullyObservable
export PartiallyObservable

export Multiagency
export NoAgent
export SingleAgent
export MultiAgent
export DefiniteAgents
export IndefiniteAgents

export Cooperation
export Cooperative
export Competitive
export Individual

export MemoryPresence
export MemoryPresent
export MemoryAbsent

export RewardStyle
export SingleReward
export MultipleRewards
export DefiniteRewards
export IndefiniteRewards
export NoReward

export Centralization
export Centralized
export Decentralized

export Statefulness
export Stateful
export Stateless
export AgentFactored

export TimestepStyle
export SemiMarkov
export FixedTimestep

export AgentCorrelation
export Correlated
export Uncorrelated

include("groups.jl")
export Indep
export JointAndIndep
export Joint
export Parallel
export Dense

export name
export indices
export with_hints

include("spaces.jl")
export Space
export FiniteSpace
export TypeSpace
export RangeSpace
export SingletonSpace

include("conditional_dists.jl")
export ConditionalDist
export AnonymousDist
export UndefinedDist
export CompoundDist
export UniformDist
export CollectDist
export FixedDist
export @ConditionalDist

export support
export pdf
export logpdf
export fix
export conditions


include("network_utils.jl")
include("validity.jl")
include("networks.jl")
export DecisionGraph
export DecisionNetwork

export nodes
export node_names
export children
export dynamic_pairs
export ranges
export implementation
export graph

export sample
export next
export prev
export graph

include("transformations.jl")
export DNTransformation
export transform

export Insert
export Implement
export Unimplement
export Recondition
export IndexExplode
export MergeForward
export Rename
export SetNodeHints

include("show.jl")
include("std_family.jl")
include("std_networks.jl")

export MDP_DN
export POMDP_DN
export MG_DN
export DecPOMDP_DN

include("visualization.jl")
export dnplot
export as_graphs_jl


export @markov_alias
export MarkovAmbiguousTraits


end # module DecisionNetworks
