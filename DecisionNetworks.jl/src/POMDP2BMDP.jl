using Pkg
# Pkg.develop(path="d:/Studies/Research/Code/Decisions.jl")
Pkg.activate()
using Decisions
using Random
# using DecisionDomains

Pkg.activate(".")
using POMDPs
using POMDPTools
using RockSample
include("../../DecisionDomains.jl/src/rocksample.jl")



# RockSample Example:
myPOMDP = RockSampleDecisionsPOMDP()
# dnplot(myPOMDP.model)
# Step 1: 
myBMDP = myPOMDP |> Unimplement(:r, :o,:mp)

# Step 2: 
myBMDP = myBMDP |> MergeForward(:s, :sp, :o)
# dnplot(myBMDP.model)


# Step 3: define an updater from memory node m to memory node mp:
function genObs(rng; m, a)
    # Set s in the environment model to a sample from m, and :a to a.
    s = rand(rng, m)
    sp = rand(myPOMDP[:sp]; s, a)
    o = rand(myPOMDP[:o]; s, a, sp)
    
    return o
end


mem_updater = @ConditionalDist Any begin
    function rand(rng; m, a)
        o = genObs(rng; m,a)
        rand(myPOMDP[:mp]; m, a, o)
    end
end

myBMDP = myBMDP |> Implement(;
    mp = mem_updater 
)

# Step 4: recondition r on m, a, mp
myBMDP = myBMDP |> Recondition(; r =(Dense(:a),Dense(:m),Dense(:mp)))
# dnplot(myBMDP.model)

# Step 5: Reimplement reward
calc_reward = @ConditionalDist Float64 begin
    function rand(rng; m, a, mp)
        Ns = 1000
        r = 0.0
        for i in range(1,Ns)    
            s_i = rand(rng, m)
            sp_i = rand(rng, mp)
            r += rand(myPOMDP[:r]; s = s_i, a, sp = sp_i)
        end
        return r /=Ns
    end
end

myBMDP = myBMDP |> Implement(;
    r = calc_reward 
)


# Step 6: Rename m--> s, and mp --> sp
myBMDP = myBMDP |> Rename(; m = :s, mp = :sp)
myBMDP = myBMDP |> SetNodeHints(:sp; is_terminable=true)
# dnplot(myBMDP.model)

# Check that it is now an MDP:
myBMDP isa Decisions.MDP


s = myBMDP.initial.rand()
a = rand(Decisions.support(myBMDP[:a]))
sp =rand(myBMDP[:sp]; s,a)
r = rand(myBMDP[:r]; s, a, sp)

s = myBMDP.initial.rand()
function run_for_N(s, N)
    n = 0
    while n<=N
        a = rand(Decisions.support(myBMDP[:a]))
        sp =rand(myBMDP[:sp]; s,a)
        r = rand(myBMDP[:r]; s, a, sp)
        println(r)
        s = deepcopy(sp)
        n +=1
    end
    
end

N = 100
run_for_N(s,N)