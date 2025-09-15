module DecisionAlgorithms

using DecisionProblems
using DecisionNetworks

include("vi.jl")
export ValueIteration, solve!

end # module DecisionAlgorithms
