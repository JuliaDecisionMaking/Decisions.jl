module DecisionProblems

using DecisionNetworks
using StaticArrays

include("metrics.jl")
export DecisionMetric

export aggregate!
export output
export reset!

export Discounted
export DiscountedReward
export Trace
export NIters

include("problems.jl")
export DecisionProblem
export model
export objective
export graph
export initial

include("algorithms.jl")
export DecisionAlgorithm
export solve
export simulate!

include("named_problems.jl")
export MDP
export POMDP
export MG

end