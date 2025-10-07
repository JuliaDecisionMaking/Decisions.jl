using Pkg
# Pkg.develop(path="d:/Studies/Research/Code/Decisions.jl")

using Decisions
# using .DecisionAlgorithms
# using .DecisionNetworks
# using .DecisionProblems
# using .DecisionSettings
# using .DecisionDomains


my_dn = MDP_DN(;
    sp = (rng; s, a) -> rand(rng),
    r = (rng; s, a, sp) -> s + a
)

my_decpomdp = DecPOMDP_DN((; i=4);
           o = (; s, a, i) -> "obs",
           r = (; s, a, sp,i) -> "rwd",
           sp = (; s, a,i) -> "successor state"
       )


my_decpomdp2 = DecPOMDP_DN()



DecPOMDP_traits = DecisionNetworks.MarkovAmbiguousTraits(
   Statefulness => AgentFactored(),
   Multiagency => IndefiniteAgents(),
   AgentCorrelation => Uncorrelated(),
   MemoryPresence => MemoryPresent(),
   Centralization => Decentralized(),
   Observability => PartiallyObservable(),
   RewardStyle => IndefiniteRewards(:s, :a, :sp)
)

DecisionNetworks.@markov_alias DecPOMDP_DN DecPOMDP_traits

DecMDP_traits = DecisionNetworks.MarkovAmbiguousTraits(
   Statefulness => AgentFactored(),
   Multiagency => IndefiniteAgents(),
   AgentCorrelation => Uncorrelated(),
   MemoryPresence => MemoryAbsent(),
   Centralization => Decentralized(),
   Observability => FullyObservable(),
   RewardStyle => IndefiniteRewards(:s, :a, :sp)
)

DecisionNetworks.@markov_alias DecMDP_DN2 DecMDP_traits

# DecisionNetworks.@markov_node :o Observability Multiagency Centralization begin
#     (PartiallyObservable, MultiAgent) => Joint(:o, :i; is_terminable=false)
#     (PartiallyObservable, Any)        => Joint(:o    ; is_terminable=false)
#     (FullyObservable,     Any)        => nothing
#     (PartiallyObservable, MultiAgent, Decentralized) => Indep(:o, :i; is_terminable=false)
# end


# DecisionNetworks.@markov_alias myDecPOMDP_DN2   _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @MARwd)
# DecisionNetworks.@markov_alias myDecPOMDP_DN3   _Traits(@SFac, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @MARwd)
# DecisionNetworks.@markov_alias myDecPOMDP_DN5   _Traits(@SFac, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @MARwd)


# DecisionNetworks.@markov_alias DecMDP_DN   _Traits(@SFac, @NAgents, @UnCorr, @FObs, @NoMem, @DeCentr, @MARwd)


my_decpomdp = DecPOMDP_DN((; i=4);
           o = (; s, a, i) -> "obs",
           r = (; s, a, sp,i) -> "rwd",
           sp = (; s, a,i) -> "successor state"
       )

# my_decpomdp3 = myDecPOMDP_DN3((; i=4);
#            o = (; s, a, i) -> "obs",
#            r = (; s, a, sp,i) -> "rwd",
#            sp = (; s, a,i) -> "successor state"
#        )

# my_decpomdp4 = myDecPOMDP_DN5((; i=4);
#            o = (; s, a, i) -> "obs",
#            r = (; s, a, sp,i) -> "rwd",
#            sp = (; s, a,i) -> "successor state"
    #    )

my_decmdp = DecMDP_DN2((; i=4);  
        r = (; s, a, sp,i) -> "rwd",
        sp = (; s, a,i) -> "successor state"   
       )

my_decmdp |> IndexExplode(:i)

My_DN = POMDP_DN |> MergeForward(:m, :mp, :o) |> Recondition(; a=(Dense(:s),))