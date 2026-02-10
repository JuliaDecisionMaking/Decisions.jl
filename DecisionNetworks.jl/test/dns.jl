@testset "Node definitions are order invariant" begin
    dn_1 = DecisionNetwork([(:b, :c) => :a, (:b, :a) => :z])
    dn_2 = DecisionNetwork([(:b, :a) => :z, (:b, :c) => :a])
    @test typeof(dn_1) == typeof(dn_2)
end

@testset "Node conditionings are order invariant" begin
    dn_1 = DecisionNetwork([(:b, :c) => :a, (:b, :a) => :z])
    dn_2 = DecisionNetwork([(:c, :b) => :a, (:b, :a) => :z])
    @test typeof(dn_1) == typeof(dn_2)
end

@testset "Symbols are automatically parsed as default node types" begin
    dn_1 = DecisionNetwork([(Dense(:b), Dense(:c)) => Joint(:a)])
    dn_2 = DecisionNetwork([(:b, :c) => :a])
    @test typeof(dn_1) == typeof(dn_2)
end

@testset "Nodes are order invariant wrt their iterates" begin
    dn_1 = DecisionNetwork([(Parallel(:b, :i, :j),) => Indep(:a, :i, :j)])
    dn_2 = DecisionNetwork([(Parallel(:b, :j, :i),) => Indep(:a, :i, :j)])
    dn_3 = DecisionNetwork([(Parallel(:b, :j, :i),) => Indep(:a, :j, :i)])

    @test typeof(dn_1) == typeof(dn_2)
    @test typeof(dn_2) == typeof(dn_3)

end

