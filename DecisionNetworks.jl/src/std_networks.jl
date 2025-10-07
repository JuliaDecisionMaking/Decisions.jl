# Defining all these problems gets to be a headache without a lot of sugar
# Let's heavily macro this internally end
macro NoAgents():(Multiagency => NoAgent()) end
macro OneAgent():(Multiagency => SingleAgent()) end
macro NAgents() :(Multiagency => IndefiniteAgents()) end

macro FObs()    :(Observability => FullyObservable()) end
macro PObs()    :(Observability => PartiallyObservable()) end

macro Centr()   :(Centralization => Centralized()) end
macro DeCentr() :(Centralization => Decentralized()) end

macro YesMem()  :(MemoryPresence => MemoryPresent()) end
macro NoMem()   :(MemoryPresence => MemoryAbsent()) end

macro NoRwd()   :(RewardStyle => NoReward()) end
macro SRwd()    :(RewardStyle => SingleReward(:s), SingleReward(:s, :sp)) end
macro ARwd()    :(RewardStyle => SingleReward(:a)) end
macro SARwd()   :(RewardStyle => SingleReward(:s, :a, :sp)) end
macro MARwd()   :(RewardStyle => SingleReward(:m, :a, :mp)) end

macro NSRwds()  :(RewardStyle => (IndefiniteRewards(:s), IndefiniteRewards(:s, :sp))) end
macro NARwds()  :(RewardStyle => IndefiniteRewards(:a)) end
macro NSARwds() :(RewardStyle => (IndefiniteRewards(:s), IndefiniteRewards(:s, :a), IndefiniteRewards(:s, :a, :sp))) end
macro NMARwds() :(RewardStyle => (IndefiniteRewards(:m), IndefiniteRewards(:m, :a), IndefiniteRewards(:m, :a, :mp))) end

macro HasS()    :(Statefulness => Stateful()) end

macro Coop()    :(Cooperation => Cooperative()) end
macro Comp()    :(Cooperation => Competitive()) end
macro Indv()    :(Cooperation => Individual()) end

macro UnCorr()  :(AgentCorrelation => Uncorrelated()) end

macro Semi()    :(TimestepStyle => SemiMarkov()) end

const _Traits = MarkovAmbiguousTraits

# Trivial networks
# @markov_alias Empty_DN _Traits()
# @markov_alias MC_DN    _Traits(@HasS) # "in the beginning there was state. and state iterated"

# Agentless networks
# @markov_alias HMM_DN       _Traits(@HasS, @PObs)
# @markov_alias MRwP_DN      _Traits(@HasS, @SRwd)
# @markov_alias MRnP_DN      _Traits(@HasS, @Semi)

# Stateless networks (game theory)
# @markov_alias NFG_DN          _Traits(@NAgents, @UnCorr, @Comp, @ARwd)
# @markov_alias CorrNFG_DN      _Traits(@NAgents, @Comp, @ARwd)
# @markov_alias RG_DN           _Traits(@NAgents, @UnCorr, @Comp, @ARwd, @YesMem)




"""
    MDP_DN

Canonical decision network underlying a Markov decision process.

Assumes the memory node is not present and the reward is conditioned on `(:s, :a, :sp)`.
"""
@markov_alias MDP_DN       _Traits(@HasS, @OneAgent, @NoMem, @SARwd)

"""
    POMDP_DN

Canonical decision network underlying a partially observable Markov decision process.

Assumes the memory node is present and the reward is conditioned on `(:s, :a, :sp)`.
"""
@markov_alias POMDP_DN     _Traits(@HasS, @OneAgent, @YesMem, @SARwd, @PObs)




# @markov_alias SMDP_DN      _Traits(@HasS, @OneAgent, @AnyMem, @SARwd, @Semi)
# @markov_alias POSMDP_DN    _Traits(@HasS, @OneAgent, @YesMem, @SARwd, @PObs, @Semi)
# @markov_alias RhoPOMDP_DN  _Traits(@HasS, @OneAgent, @YesMem, @MARwd, @PObs)
# @markov_alias RhoPOSMDP_DN _Traits(@HasS, @OneAgent, @YesMem, @MARwd, @PObs, @Semi)

# # # Multi agent fully observable problems
# @markov_alias MMDP_DN        _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @SARwd)
# @markov_alias MSMDP_DN       _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @SARwd, @Semi)
# @markov_alias DecMMDP_DN     _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @DeCentr, @SARwd)
# @markov_alias DecMSMDP_DN    _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @DeCentr, @SARwd, @Semi)


"""
    MG_DN

Canonical decision network underlying a Markov game.

"""
@markov_alias MG_DN          _Traits(@HasS, @NAgents, @UnCorr, @NoMem, @DeCentr, @Comp, @SARwd)


"""
    DecPOMDP_DN

Canonical decision network underlying a decentralized partially observable Markov decision
process.
"""
@markov_alias DecPOMDP_DN    _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @SARwd)


# @markov_alias SMG_DN         _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @DeCentr, @Comp, @SARwd, @Semi)
# @markov_alias IndMDP_DN      _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @DeCentr, @Indv, @SARwd)
# @markov_alias IndSMDP_DN     _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @DeCentr, @Indv, @SARwd, @Semi)


# # # # Multi agent partially observable problems
# @markov_alias MPOMDP_DN      _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @SARwd)
# @markov_alias MPOSMDP_DN     _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @SARwd, @Semi)
# @markov_alias DecPOSMDP_DN   _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @SARwd, @Semi)
@markov_alias POMG_DN        _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @Comp, @SARwd)
# @markov_alias POSMG_DN       _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @Comp, @SARwd, @Semi)
# @markov_alias IndPOMDP_DN    _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @Indv, @SARwd)
# @markov_alias IndPOSMDP_DN   _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @Indv, @SARwd, @Semi)

# # # ... and everything again with multiple rewards

# # # Single agent problems
# @markov_alias CMDP_DN       _Traits(@HasS, @OneAgent, @AnyMem, @NSARwds)
# @markov_alias CSMDP_DN      _Traits(@HasS, @OneAgent, @AnyMem, @NSARwds, @Semi)
# @markov_alias CPOMDP_DN     _Traits(@HasS, @OneAgent, @YesMem, @NSARwds, @PObs)
# @markov_alias CPOSMDP_DN    _Traits(@HasS, @OneAgent, @YesMem, @NSARwds, @PObs, @Semi)
# @markov_alias CRhoPOMDP_DN  _Traits(@HasS, @OneAgent, @YesMem, @NMARwds, @PObs)
# @markov_alias CRhoPOSMDP_DN _Traits(@HasS, @OneAgent, @YesMem, @NMARwds, @PObs, @Semi)

# # # # Multi agent fully observable problems
# @markov_alias CMMDP_DN        _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @NSARwds)
# @markov_alias CMSMDP_DN       _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @NSARwds, @Semi)
# @markov_alias CDecMMDP_DN     _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @DeCentr, @NSARwds)
# @markov_alias CDecMSMDP_DN    _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @DeCentr, @NSARwds, @Semi)
# @markov_alias CMG_DN          _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @DeCentr, @Comp, @NSARwds)
# @markov_alias CSMG_DN         _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @DeCentr, @Comp, @NSARwds, @Semi)
# @markov_alias CIndMDP_DN      _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @DeCentr, @Indv, @NSARwds)
# @markov_alias CIndSMDP_DN     _Traits(@HasS, @NAgents, @UnCorr, @AnyMem, @DeCentr, @Indv, @NSARwds, @Semi)


# # # # Multi agent partially observable problems
# @markov_alias CMPOMDP_DN      _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @NSARwds)
# @markov_alias CMPOSMDP_DN     _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @NSARwds, @Semi)
# @markov_alias CDecPOMDP_DN    _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @NSARwds)
# @markov_alias CDecPOSMDP_DN   _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @NSARwds, @Semi)
# @markov_alias CPOMG_DN        _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @Comp, @NSARwds)
# @markov_alias CPOSMG_DN       _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @Comp, @NSARwds, @Semi)
# @markov_alias CIndPOMDP_DN    _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @Indv, @NSARwds)
# @markov_alias CIndPOSMDP_DN   _Traits(@HasS, @NAgents, @UnCorr, @PObs, @YesMem, @DeCentr, @Indv, @NSARwds, @Semi)

# Missing from DecisionMaking.jl's list:
# - Classical Planning
#     - A\*
# - Multi-Armed Bandit (MAB)
# - Motion and Trajectory Planning
#     - Rapidly-Exploring Random Trees (RRT) Planning
#     - Probabilistic Roadmap (PRM) Planning
# - Multi-Agent Pathfinding (MAPF)
# - Stochastic Shortest Path (SSP) Problem
