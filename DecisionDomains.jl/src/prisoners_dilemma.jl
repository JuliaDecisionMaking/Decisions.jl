using DecisionNetworks
using DecisionProblems
using Random

# --- Use isbits enum types instead of Symbols ---
@enum State Live=1
@enum Act   C=0 D=1

# 2-agent MG DN with identity transition and stub reward
dn = DecisionProblems.MG_DN{(; i=2)}(;
    # next state equals current state (typed as `State`)
    sp = (rng; s::State, a) -> s,
    # stub per-agent reward (Float64, isbits)
    r  = (rng; s::State, a, sp::State, i) -> 0.0
)

# Decision distribution for a[i] that returns an `Act` (isbits)
a_pol = @ConditionalDist Act begin
    function rand(rng; s, i)
        rand(rng, (C, D))
    end
end

#=
s = Live  # initial state of type `State`

out = sample(dn, (; a = a_pol), (; s)) do vals
    println(vals)  # vals is a NamedTuple with keys :a, :r, :sp
end

=#