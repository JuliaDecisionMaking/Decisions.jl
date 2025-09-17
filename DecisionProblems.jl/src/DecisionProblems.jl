module DecisionProblems

using DecisionNetworks
using StaticArrays
import POMDPs
import POMDPTools

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
export solve
export simulate!
export DecisionAlgorithm

include("named_problems.jl")
export MDP
export POMDP
export MG

include("pomdps_glue.jl")

end
