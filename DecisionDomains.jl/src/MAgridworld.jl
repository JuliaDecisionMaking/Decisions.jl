using Pkg


using Decisions
using DecisionNetworks
using DecisionProblems
using DecisionDomains
using StaticArrays
using Distributions
using POMDPTools

struct GridPointSpace <: Space{Tuple{Int, Int}}
    nrows::Int
    ncols::Int
end

Base.in(p::Tuple{Int, Int}, g::GridPointSpace) =
    (p[1] <= g.nrows) && (p[2] <= g.ncols) && (p[1] > 0) && (p[2] > 0)

Base.length(g::GridPointSpace) = g.nrows * g.ncols
Base.iterate(g::GridPointSpace) = iterate(Iterators.product(1:g.nrows, 1:g.ncols))
Base.iterate(g::GridPointSpace, state) = iterate(Iterators.product(1:g.nrows, 1:g.ncols), state)

function Base.:(==)(s1::Tuple{Int,Int}, s2::Tuple{Int,Int})
    return s1[1] == s2[1] && s1[2] == s2[2]
end

@enum RobotAction begin
    Stay
    Forward
    TurnLeft
    TurnRight
end

@enum RobotHeading North East South West

function is_in_bounds(p, nrows, ncols)
    (p[1] <= nrows) && (p[2] <= ncols) && (p[1] > 0) && (p[2] > 0)
end

"""
Cooperative box pushing - based on the problem introduced by Kube and Zhang
Modelling in Collective Robotics. Autonomous Robots,4:53–72, 1997.
Here we assume a DEC-POMDP formulation, with no communication between the robots
"""

abstract type Box end

struct SmallBox <: Box
    pos::Tuple{Int,Int}   # single-cell position
end

struct LargeBox
    pos::SVector{2, Tuple{Int,Int}}  # must be adjacent
end

struct Robot
    pos::Tuple{Int,Int}
    head::RobotHeading
end

struct BoxPushingState{N,M,K}
    robots::SVector{N, Robot}    
    smallBoxes::SVector{M, SmallBox}
    largeBoxes::SVector{K, LargeBox}

    function BoxPushingState(robots, smallBoxes, largeBoxes)
        new{length(robots), length(smallBoxes), length(largeBoxes)}(
            SVector(robots...),
            SVector(smallBoxes...),
            SVector(largeBoxes...)
        )
    end
end


# Helper functions:
# heading vectors
dirvec(h::RobotHeading) = h == North ? (-1,0) :
                     h == East  ? (0,1)  :
                     h == South ? (1,0)  :
                                   (0,-1)

left(h::RobotHeading)  = RobotHeading((UInt8(h) + 3) % 4)   # get new heading when turning left
right(h::RobotHeading) = RobotHeading((UInt8(h) + 1) % 4)   # get new heading when turning right

front(r::Robot) = r.pos .+ dirvec(r.head)
pushBox(b::SmallBox, r::Robot) = b.pos .+ dirvec(r.head)
pushBox(B::LargeBox, r::Robot) = (B.pos[1] .+ dirvec(r.head), B.pos[2] .+ dirvec(r.head) )

inbounds((r,c), g::GridPointSpace) = 1 ≤ r ≤ g.nrows && 1 ≤ c ≤ g.ncols

adjacent(a::Tuple{Int,Int}, b::Tuple{Int,Int}) =
    abs(a[1]-b[1]) + abs(a[2]-b[2]) == 1

function freecell(cell::Tuple{Int,Int}, s::BoxPushingState)
    for r in s.robots
        if cell == r
            return false
        end
    end
    
    for b in s.smallBoxes
        if cell == b
            return false
        end
    end

    for B in s.largeBoxes
        if cell == B.pos[1] || cell == B.pos[2]
            return false
        end
    end

    return true
end


# all individual actions
acts = instances(RobotAction)   # (Stay, Forward, TurnLeft, TurnRight)

# build the joint space for N robots
function joint_actions(N::Int)
    Iterators.product(ntuple(_ -> acts, N)...)
end

const JointAction{N} = SVector{N, RobotAction}

# example:
# s = BoxPushingState(
#     [(2,1), (3,1)],                     # plain Vector of robot positions
#     [SmallBox((1,1)), SmallBox((2,2))], # Vector of small boxes
#     [LargeBox((3,3),(3,4))]             # Vector of large boxes
# )
# )
CBP_parameters = (transition_prob = 0.9,)



function CoopBoxPushing(g::GridPointSpace, params::NamedTuple)
    # transition = CBP_transition(g, params)
    


    reward = @ConditionalDist Float64 begin
        function rand(rng; s, a, sp)
            5
        end
    end

    initial_state = @ConditionalDist @NamedTuple{s::BoxPushingState} begin
        function rand(rng)
            # robots
            r1 = Robot((3,1), East)
            r2 = Robot((3,3), North)

            # small boxes
            sb1 = SmallBox((2,1))
            sb2 = SmallBox((2,4))

            # large box (two adjacent cells)
            lb1 = LargeBox(SVector((2,2), (2,3)))

            # build state
            
            (;s=BoxPushingState((r1, r2), (sb1, sb2), (lb1,)))
        end
    end

    

    MDP(DiscountedReward(0.99), initial_state;
        sp = CBP_transition(g, params),
        r = reward,
        a = FiniteSpace(collect(joint_actions(2)))
    )


end



function CBP_transition(g::GridPointSpace, params::NamedTuple)
    transition = @ConditionalDist BoxPushingState begin
        function support(; s, a)
            
            if isnothing(s) && isnothing(a)
                g
            else
                jointTransition(s,a)
            end
        end
    end
    function jointTransition(s,a)
        tp = params.transition_prob  # Transition probability

        # Get marginal distributions for all robots
        pi = Vector{}(undef,2)
        for i in (1,length(s.robots)) 
            push!(pi, singleAgentTransition(s,a[i],i))
        end

        return pi
        
    end

    function singleAgentTransition(s,a,i)
        
        tp = params.transition_prob  # Transition probability

        if ai == TurnLeft
            rp = setindex(s.robots, Robot(s.robots[i].pos, left(s.robots[i].head)), i)
            sp = BoxPushingState(rp, sp.smallBoxes, sp.largeBoxes)
            return SparseCat([sp, s], [tp, 1-tp])
        elseif ai == TurnRight
            sp.robots[i] = Robot(s.robots[i].pos, right(s.robots[i].head)) 
            return SparseCat([sp, s], [tp, 1-tp])
        elseif ai == Stay
            return SparseCat( s, 1.0)
        elseif ai == Forward
            # Here we ignore the large box, and will reason about it in the joint transition
            sp.robots[i].pos = Robot(front(s.robots[i]), s.robots[i].head) 
            if ~inbounds(sp.robots[i].pos, g) # hit a wall
                return SparseCat( s, 1.0)
            end

            # Check if it pushes a small box
            for (j, b) in pairs(sp.smallBoxes)
                if b.pos == sp.robots[i]
                    sb = pushBox(b, sp.robots[i])
                    if freecell(sb, s)
                        sp.smallBoxes[j].pos = sb 
                    end
                    return SparseCat([sp, s], [tp, 1-tp])
                    
                end
            end
            return SparseCat([sp, s], [tp, 1-tp])
        
        end
    end

    # return (; singleAgentTransition)
end

g = GridPointSpace(3,4)
CoBoPu = CoopBoxPushing(g, CBP_parameters)
s = initial(CoBoPu)[1]
a = (TurnLeft, Forward)

@run support(CoBoPu.model.implementation.sp; s = s, a = a)

@run support(CoBoPu.model.implementation.sp)

support(ice.model.implementation.sp)

prob = DecisionDomains.Iceworld(p_slip=0.5, nrows = 5, ncols = 5, holes = (2,2) ,target = (1,1))
# sample an action
rand([Decisions.support(prob[:a])...])

function jointTransition(s,a,g,params)
        tp = params.transition_prob  # Transition probability
        Nr = length(s.robots)
        # Get marginal distributions for all robots
        pi = Vector{SparseCat}(undef, Nr)
        for i in (1,Nr) 
            pi[i] = singleAgentTransition(s,a[i],i,g,params)
        end

        return pi
        
    end

function singleAgentTransition(s,ai,i,g,params)
        
        tp = params.transition_prob  # Transition probability
        # sp = deepcopy(s)
        if ai == TurnLeft
            rp = setindex(s.robots, Robot(s.robots[i].pos, left(s.robots[i].head)), i)
            sp = BoxPushingState(rp, s.smallBoxes, s.largeBoxes)
            return SparseCat([sp, s], [tp, 1-tp])
        elseif ai == TurnRight
            rp = setindex(s.robots, Robot(s.robots[i].pos, right(s.robots[i].head)), i)
            sp = BoxPushingState(rp, s.smallBoxes, s.largeBoxes)
            return SparseCat([sp, s], [tp, 1-tp])
        elseif ai == Stay
            return SparseCat( s, 1.0)
        elseif ai == Forward
            # Here we ignore the large box, and will reason about it in the joint transition
            rp = setindex(s.robots, Robot(front(s.robots[i]), s.robots[i].head), i)
            
            if ~inbounds(rp[i].pos, g) # hit a wall
                return SparseCat( s, 1.0)
            end

            # Check if it pushes a small box
            for (j, b) in pairs(s.smallBoxes)
                if b.pos == rp[i].pos
                    sb = pushBox(b, rp[i])
                    if freecell(sb, s)
                        bp = setindex(s.smallBoxes, SmallBox(sb), j)
                        sp = BoxPushingState(rp, bp, s.largeBoxes)
                    else
                        sp = BoxPushingState(rp, s.smallBoxes, s.largeBoxes)
                    end
                    return SparseCat([sp, s], [tp, 1-tp])
                    
                end
            end

            # Check if it pushes a large box - assume other robot also pushes
            for (j, B) in pairs(s.largeBoxes)
                if B.pos[1] == rp[i].pos || B.pos[2] == rp[i].pos
                    sB = pushBox(B, rp[i])
                    if freecell(sB[1], s) && freecell(sB[2], s)
                        bp = setindex(s.largeBoxes, LargeBox(sB), j)
                        sp = BoxPushingState(rp, s.smallBoxes, bp)
                    else
                        sp = BoxPushingState(rp, s.smallBoxes, s.largeBoxes)
                    end
                    return SparseCat([sp, s], [tp, 1-tp])
                    
                end
            end

            sp = BoxPushingState(rp, s.smallBoxes, s.largeBoxes)
            return SparseCat([sp, s], [tp, 1-tp])
        
        end
end

@run jointTransition(s,a,g,CBP_parameters)