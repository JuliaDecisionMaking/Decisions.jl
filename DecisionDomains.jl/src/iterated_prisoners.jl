@enum PrisonerChoice SILENT BETRAY
const ChoicePair = Tuple{PrisonerChoice, PrisonerChoice}
function IteratedPrisoners()
    transition = @ConditionalDist ChoicePair begin
        function rand(rng; s, a)
            Tuple(a)
        end
    end
    reward = @ConditionalDist Float64 begin
        function rand(rng; s, i, a, sp)
            if sp == (SILENT, SILENT)
                -1.0
            elseif sp == (BETRAY, SILENT)
                (i == 1) ? 0.0 : -3.0
            elseif sp == (SILENT, BETRAY)
                (i == 1) ? -3.0 : 0.0
            else
                -2.0
            end
        end
    end
    DecisionNetworks.MG_DN((; i=2); sp=transition, r=reward, 
        a=FiniteSpace([SILENT, BETRAY]))
end
action = @ConditionalDist PrisonerChoice begin
    function rand(rng; s, i)
        rand([SILENT, BETRAY])
    end
end
# behavior = (; a=action)

# mg = IteratedPrisoners()
# sample(mg, behavior, (; s=(SILENT, SILENT))) do output
#     println(output)
#     return (output[:a][1] == BETRAY) && (output[:a][2] == BETRAY)
# end 
