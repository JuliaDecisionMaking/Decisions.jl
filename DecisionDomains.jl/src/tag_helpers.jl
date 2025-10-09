using StaticArrays, Random

@enum TagAct Left=1 Right=2 Up=3 Down=4 Stay=5
const Pos = SVector{2,Int}

struct TagState
    r1::Pos
    r2::Pos
    t::Pos
end

in_bounds(p::Pos, sz::Pos) = (1 <= p[1] <= sz[1]) & (1 <= p[2] <= sz[2])

# One-step robot move under enum action with bounds/obstacles
function move_robot(sz::Pos, blocked::BitArray{2}, p::Pos, a::TagAct)
    δ = a === Left      ? SVector(0,-1) :
        a === Right     ? SVector(0, 1) :
        a === Up        ? SVector(-1,0) :
        a === Down      ? SVector( 1,0) :
        SVector(0,0)   # Stay ⇒ no movement
    np = p + δ
    (in_bounds(np, sz) && !blocked[np...]) ? np : p
end

# Target candidate positions (lazy random walk: stay/N/E/S/W)
function target_candidates(sz::Pos, blocked::BitArray{2}, t::Pos)
    cands = Pos[t,
                t + SVector(-1,0), t + SVector(1,0),
                t + SVector(0,-1), t + SVector(0,1)]
    [p for p in cands if in_bounds(p, sz) && !blocked[p...]]
end
