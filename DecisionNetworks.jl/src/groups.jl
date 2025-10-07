"""
    abstract type RVGroup{id, idxs}

Abstract base type representing a group of random variables, named `id`, over axes with
indices `idxs`.
"""
abstract type RVGroup{id, idxs} end


"""
    indices(::RVGroup)

Give the names of the indexing variables for a group of random variables.
"""
function indices(::RVGroup{id, idx_vars}) where {id, idx_vars} 
    _sorted_tuple(filter((idx) -> idx != :_, idx_vars))
end


"""
    name(::RVGroup)

Give the name of a group of random variables.
"""
name(::RVGroup{id}) where {id} = id


"""
    expr(::RVGroup)

Give an indexing expression for a group of random variables that specifies single variables
in the group.
"""
function expr(::RVGroup{id, idx_vars}) where {id, idx_vars}
    if length(idx_vars) == 0
        id
    else
        idxs_with_colon = map(idx_vars) do idx
            # interestingly I think this statement uses colon in every possible way:
            #   literal symbol, literal expression, Colon(), separator in ternary operator
            (idx == :_) ? :(:) : idx
        end
        :($id[$(idxs_with_colon...)])
    end
end


"""
    abstract type Plate <: RVGroup

Abstract base type for sampleable groups of random variables, specified over given axes,
which is itself a random variable.

There can be various independence relationships between the nodes in the group. See `Indep`,
`Joint`, and `JointAndIndep`.
"""
abstract type Plate{id, idxs, hints} <: RVGroup{id, idxs} end

hints(::Plate{id, idxs, H}) where {id, idxs, H} = H

"""
    with_hints(p::Plate; hints...)

Alter the node hints for a Plate, producing a new Plate.
"""
with_hints(p::Plate; hints...) = p


function Terminality(::Plate{id, idxs, hints}) where {id, idxs, hints} 
    if :is_terminable ∉ keys(hints) 
        MaybeTerminable()
    elseif hints[:is_terminable]
        Terminable() 
    else 
        NotTerminable()
    end
end

"""
    Indep

A group of random variables that are all (conditionally) independent.
"""
struct Indep{id, idxs, hints} <: Plate{id, idxs, hints}
    Indep(id, idxs; hints...) = new{id, _sorted_tuple(idxs), NamedTuple(hints)}()
    Indep(id, idxs...; hints...) = new{id, _sorted_tuple(idxs), NamedTuple(hints)}()
end

with_hints(::Indep{id, idxs, hints}; new_hints...) where {id, idxs, hints} = Indep(id, idxs; new_hints...)


"""
    Joint

A group of random variables that are jointly related to each other (that is, are not
independent).
"""
struct Joint{id, idxs, hints} <: Plate{id, idxs, hints}
    Joint(id, idxs; hints...) = new{id, _sorted_tuple(idxs), NamedTuple(hints)}()
    Joint(id, idxs...; hints...) = new{id, _sorted_tuple(idxs), NamedTuple(hints)}()
end

with_hints(::Joint{id, idxs, hints}; new_hints...) where {id, idxs, hints} = Joint(id, idxs; new_hints...)


"""
    JointAndIndep

A group of random variables that are jointly related on some axes and independently related
on the rest.
"""
struct JointAndIndep{id, idxs, n_joint, hints} <: Plate{id, idxs, hints} end

function JointAndIndep(ids, joint_idxs, indep_idxs, hints=false)
    new{ids, _sorted_tuple((joint_idxs..., indep_idxs...)), length(joint_idxs), hints}
end

with_hints(::JointAndIndep{id, idxs, n, hints}; new_hints...) where {id, idxs, n, hints} = JointAndIndep{id, idxs, n, NamedTuple(new_hints)}()

"""
    abstract type Condition <: RVGroup
    
A group of random variables specified as conditioning variables on another random variable.
Cannot be sampled on its own. 
"""
abstract type ConditioningGroup{id, idxs} <: RVGroup{id, idxs} end


"""
    Parallel

A group of conditioning variables that condition only random variables at matching
indices in any group they condition (which need not be every index in either group).
"""
struct Parallel{id, idxs} <: ConditioningGroup{id, idxs}
    Parallel(id, idxs) = new{id, _sorted_tuple(idxs)}()
    Parallel(id, idxs...) = new{id, _sorted_tuple(idxs)}()
end


"""
    Dense

A group of conditioning variables that condition every random variable in any group they
condition.
"""
struct Dense{id} <: ConditioningGroup{id, ()}
    Dense(id) = new{id}()
end


Base.convert(::Type{ConditioningGroup}, s::Symbol) = Dense(s)
Base.convert(::Type{Plate}, s::Symbol) = Joint(s, ())
Base.convert(::Type{ConditioningGroup}, expr::Expr) = _from_expr(Indep, expr)
Base.convert(::Type{Plate}, expr::Expr) = _from_expr(Parallel, expr)

function _from_expr(node_type, expr)
    if expr.head == :ref
        idxs = map(expr.args[2:end]) do idx
            (idx == :(:)) ? :_ : idx
        end
        node_type(expr[1], idxs...)
    else
        throw(ArgumentError("Cannot parse expression $expr as a node or node group"))
    end
end


# is there a more idomatic way to do this?
rename(::Dense{id}, id2) where {id} = Dense(id2)
rename(::Parallel{id, idxs}, id2) where {id, idxs} = Parallel(id2, idxs...)
rename(::Joint{id, idxs, hints}, id2) where {id, idxs, hints} = Joint(id2, idxs...; hints...)
rename(::Indep{id, idxs, hints}, id2) where {id, idxs, hints} = Indep(id2, idxs...; hints...)

# TODO: Nothing works on JointAndIndep
# rename(::JointAndIndep{id, idxs, n_joint, hints}) where {id, idxs, n_joint, hints} = JointAndIndep{id2, idxs, n_joint, hints}()