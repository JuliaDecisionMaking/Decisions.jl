#Define MOMDP Type - Move to std_family?
const MOMDP_DN = DecisionGraph(
  [ # Six regular nodes (:xp, :yp, :r, :o, :mp, :a)
    (Dense(:x), Dense(:y), Dense(:a)) => Joint(:xp),
    (Dense(:x), Dense(:y), Dense(:a), Dense(:xp)) => Joint(:yp),
    (Dense(:x), Dense(:y), Dense(:a), Dense(:xp), Dense(:yp)) => Joint(:r),
    (Dense(:x), Dense(:y), Dense(:a), Dense(:xp), Dense(:yp)) => Joint(:o),
    (Dense(:x), Dense(:o), Dense(:a), Dense(:m)) => Joint(:mp),
    (Dense(:m),) => Joint(:a),
  ],
  (; # Three dynamic nodes (:x, :y, :m)
    :x => :xp,
    :y => :yp,
    :m => :mp
  ),
  (;) # No ranges
)

#POMDP to MOMDP
struct PartialToMixedObs{X,Y} <: DNTransformation
    fully::X
    partially::Y
    PartialToMixedObs(x, y) = isa(x,Tuple) && isa(y,Tuple) ? new{typeof(x),typeof(y)}(x,y) : error("Use Tuples")
end

function get_components(s,idx)
    if all(x -> x isa Symbol, idx)
        xp = Tuple(getfield(s,i) for i in idx)
    elseif all(x -> x isa Int, idx)
        xp = Tuple(s[i] for i in idx)
    else
        error("Use either all Symbols or all Ints for specifying indicies.")
    end
    return xp
end

function marginal_pdf(model,x,s,a,x_idx)
    supp = support(model[:sp];s=s,a=a)
    prob = 0.0
    for sp in supp
        sprob = pdf(model[:sp],sp;s=s,a=a)
        if x == get_components(sp,x_idx)
            prob += sprob
        end
    end
    return prob
end

function marginal_support(model,s,a,x_idx)
    supp = support(model[:sp];s=s,a=a)
    x = get_components(supp[1],x_idx)
    x_list = [x]
    for sp in supp[2:end]
        x = get_components(sp,x_idx)
        inner_idx = findfirst(v->v==x,x_list)
        if isnothing(inner_idx)
            push!(x_list,x)
        end
    end
    return x_list
end

function marginal_pdfy(model,yp,xp,s,a,y_idx,x_idx)
    supp = support(model[:sp];s=s,a=a)
    prob = 0.0
    for sp in supp
        sprob = pdf(model[:sp],sp;s=s,a=a)
        if yp == get_components(sp,y_idx) && xp == get_components(sp,x_idx)
            prob += sprob
        end
    end
    return prob
end

function marginal_supporty(model,xp,s,a,y_idx,x_idx)
    supp = support(model[:sp];s=s,a=a)
    yp = get_components(supp[1],y_idx)
    y_list = typeof(yp)[]
    for sp in supp
        yp = get_components(sp,y_idx)
        inner_idx = findfirst(v->v==yp,y_list)
        if isnothing(inner_idx) && get_components(sp,x_idx) == xp
            push!(y_list,yp)
        end
    end
    return y_list
end

function transform(components::PartialToMixedObs, model::POMDP_DN)
    sup = support(model[:s])
    sup_size = length(sup)
    x_type = typeof(get_components(sup[1],components.fully))
    y_type = typeof(get_components(sup[1],components.partially))

    xs = Vector{x_type}(undef, sup_size)
    ys = Vector{y_type}(undef, sup_size)
    xys_dict = Dict{Tuple{x_type,y_type},typeof(sup[1])}()

    for (i,s_i) in enumerate(sup)
        x_i = get_components(s_i,components.fully)
        y_i = get_components(s_i,components.partially)
        xs[i] = x_i
        ys[i] = y_i
        push!(xys_dict,(x_i,y_i)=>s_i)
    end
    xs = unique(xs)
    ys = unique(ys)

    obs_type = typeof(support(model[:o])[1])

    xtransition = @ConditionalDist x_type begin
        function support(;x,y,a)
            if isnothing(x) || isnothing(a) || isnothing(y)
                xs
            else
                s = xys_dict[(x,y)]
                marginal_support(model,s,a,components.fully)
            end
        end

        function rand(rng;x,y,a) #rand! (?)
            s = xys_dict[(x,y)]
            if isterminal(s)
                Terminal()
            else
                get_components(model[:sp].rand(rng;s=s,a=a),components.fully)
            end
        end

        function pdf(xp;x,y,a)
            s = xys_dict[(x,y)]
            marginal_pdf(model,xp,s,a,components.fully)
        end
    end

    ytransition = @ConditionalDist y_type begin
        function support(;x,y,a,xp)
            if isnothing(x) || isnothing(a) || isnothing(y) || isnothing(xp)
                ys
            else
                s = xys_dict[(x,y)]
                marginal_supporty(model,xp,s,a,components.partially,components.fully)
            end
        end

        function rand(rng;x,y,a,xp) #rand! (?)
            s = xys_dict[(x,y)]
            if isterminal(s)
                Terminal()
            else
                yp_support = marginal_supporty(model,xp,s,a,components.partially,components.fully)
                yp_probs = [marginal_pdfy(model,yp,xp,s,a,components.partially,components.fully) for yp in yp_support]
                yp_support[rand(rng,Categorical(yp_probs))] #Make Cleaner
            end
        end

        function pdf(yp;x,y,a,xp)
            s = xys_dict[(x,y)]
            marginal_pdfy(model,yp,xp,s,a,components.partially,components.fully)
        end
    end

    mom_observation = @ConditionalDist obs_type begin
        function support(;x,y,a,xp,yp)
            if isnothing(x) || isnothing(y) || isnothing(a) ||  isnothing(xp) || isnothing(yp)
                support(model[:o])
            else
                s = xys_dict[(x,y)]
                sp = xys_dict[(xp,yp)]
                support(model[:o];s=s,a=a,sp=sp)
            end
        end

        function rand(rng;x,y,a,xp,yp)
            s = xys_dict[(x,y)]
            sp = xys_dict[(xp,yp)]
            model[:o].rand(rng;s=s,a=a,sp=sp)
        end

        function pdf(o;x,y,a,xp,yp)
            s = xys_dict[(x,y)]
            sp = xys_dict[(xp,yp)]
            pdf(model[:o],o;s=s,a=a,sp=sp)
        end
    end

    mom_reward = @ConditionalDist Float64 begin
        function rand(rng;x,y,a,xp,yp)
            s = xys_dict[(x,y)]
            sp = xys_dict[(xp,yp)]
            model[:r].rand(rng;a=a,s=s,sp=sp)
        end
    end

    mom_belief = @ConditionalDist typeof(model[:mp]).parameters[2] begin #Return pomdp memory for now #FIX Typing here
        function support(;a,m,o,x)
            support(model[:mp];a=a,m=m,o=o)
        end

        function rand(rng;a,m,o,x)
            model[:mp].rand(rng;a=a,m=m,o=o)
        end

        function pdf(mp;a,m,o,x)
            pdf(model[:mp],mp;a=a,m=m,o=o)
        end
    end

    return MOMDP_DN(;xp = xtransition,
    yp = ytransition,
    r = mom_reward,
    o = mom_observation,
    mp = mom_belief,
    a = model[:a])
end
