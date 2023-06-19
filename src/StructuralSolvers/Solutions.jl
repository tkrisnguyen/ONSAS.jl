module Solutions

using Reexport

using ..Entities
using ..Meshes
using ..Handlers
using ..Utils
using ..StructuralSolvers
using ..Nodes

@reexport import ..Entities: internal_forces, inertial_forces, strain, stress

export AbstractSolution, StatesSolution, stresses, strains, states, analysis, solver,
       displacements, external_forces, iteration_residuals

"""
Abstract supertype for all structural analysis solutions.

**Abstract Methods**
* [`displacements`](@ref)
* [`external_forces`](@ref)
* [`internal_forces`](@ref)
* [`stress`](@ref)
* [`strain`](@ref)

**Abstract fields**
* analysis
* solver
"""
abstract type AbstractSolution end

"""
Solution that stores all intermediate arrays during the analysis.
"""
struct StatesSolution{ST<:Vector,A,SS<:AbstractSolver} <: AbstractSolution
    states::ST
    analysis::A
    solver::SS
    "Constructor with empty `AbstractStructuralState`s `Vector` and type `S`."
    function StatesSolution(analysis::A, solver::SS) where {A,SS<:AbstractSolver}
        return new{Vector{Any},A,SS}([], analysis, solver)
    end
end

"Return the solved `AbstractStrcturalState`s. "
states(sol::StatesSolution) = sol.states

"Return the `AbstractAnalysis` solved. "
analysis(sol::StatesSolution) = sol.analysis

"Return the `AbstractSolver` solved. "
solver(sol::StatesSolution) = sol.solver

for f in [:displacements, :internal_forces, :external_forces]
    "Return the $f vector Uᵏ at every time step."
    @eval $f(st_sol::StatesSolution) = $f.(states(st_sol))

    "Return the $f of the `Dof` at every time step."
    @eval $f(st_sol::StatesSolution, dof::Dof) = getindex.($f(st_sol), index(dof))

    "Return the a $f `Vector` at a `Vector` of `Dof`s at every time step."
    @eval $f(st_sol::StatesSolution, vdof::Vector{Dof}) = [$f(st_sol, dof) for dof in vdof]

    "Return the $f of a `Node` `n` every time step."
    @eval $f(st_sol::StatesSolution, n::AbstractNode) = $f(st_sol, reduce(vcat, collect(dofs(n))))

    "Return the $f a `Node` `n`  of at component `i` every time step."
    @eval $f(st_sol::StatesSolution, n::AbstractNode, component::Int) = $f(st_sol, n)[component]

    "Return the $f of a `Element` `e` at every time step."
    @eval $f(st_sol::StatesSolution, e::AbstractElement) = [$f(st_sol, n) for n in nodes(e)]
end

"Return the `IterationResidual`s object at every time step."
iteration_residuals(st_sol::StatesSolution) = iteration_residuals.(states(st_sol))

for f in [:stress, :strain]
    "Return the $f at every time step."
    @eval $f(st_sol::StatesSolution) = $f.(states(st_sol))

    "Return the $f of an `Element` `e` every time step."
    @eval function $f(st_sol::StatesSolution, e::AbstractElement)
        return [getindex($f.(states(st_sol))[step], e) for step in 1:length(states(st_sol))]
    end
end

"Return the displacements component `i` solution at the `PointEvalHandler` `peh`."
function displacements(st_sol::StatesSolution, peh::PointEvalHandler, i::Int)
    sol_points = getindex.(displacements(st_sol, peh), i)
    if length(sol_points) == 1
        sol_points[1]
    else
        sol_points
    end
end

# TODO use @eval
"Return the displacements solution at the `PointEvalHandler` `peh`."
function displacements(st_sol::StatesSolution, peh::PointEvalHandler)
    points_interpolators = interpolator(peh)
    vec_points = points(peh)
    num_points = length(vec_points)

    sol_points = Vector{Vector{Vector{Float64}}}(undef, num_points)

    for index_p in 1:num_points
        interpolator_p = node_to_weights(points_interpolators)[index_p]

        # Compute the first node contribution and the sum up
        node_values = [weight * displacements(st_sol, node)
                       for (node, weight) in pairs(interpolator_p)]
        p_values = reduce(+, node_values)
        sol_points[index_p] = p_values
    end
    return sol_points
end

"Return the internal forces solution  at the `PointEvalHandler` `peh`."
function internal_forces(st_sol::StatesSolution, peh::PointEvalHandler)
    interpolators = interpolator(peh)
    vec_points = points(peh)
    num_points = length(vec_points)

    sol_points = Vector{Vector{Vector{Float64}}}(undef, num_points)

    for index_p in 1:num_points
        interpolator_p = node_to_weights(points_interpolators)[index_p]

        # Compute the first node contribution and the sum up
        node_values = [weight * internal_forces(st_sol, node)
                       for (node, weight) in pairs(node_to_weights(interpolator_p))]
        p_values = reduce(+, node_values)
        sol_points[index_p] = p_values
    end
    return sol_points
end

"Return the internal ftorce component `i` solution at the `PointEvalHandler` `peh`."
function internal_forces(st_sol::StatesSolution, peh::PointEvalHandler, i::Int)
    return getindex.(internal_forces(st_sol, peh), i)
end

"Return the external forces solution  at the `PointEvalHandler` `peh`."
function external_forces(st_sol::StatesSolution, peh::PointEvalHandler)
    interpolators = interpolator(peh)
    vec_points = points(peh)
    num_points = length(vec_points)

    sol_points = Vector{Vector{Vector{Float64}}}(undef, num_points)

    for index_p in 1:num_points
        interpolator_p = node_to_weights(points_interpolators)[index_p]

        # Compute the first node contribution and the sum up
        node_values = [weight * external_forces(st_sol, node)
                       for (node, weight) in pairs(interpolator_p)]
        p_values = reduce(+, node_values)
        sol_points[index_p] = p_values
    end
    return sol_points
end

"Return the internal force component `i` solution at the `PointEvalHandler` `peh`."
function external_forces(st_sol::StatesSolution, peh::PointEvalHandler, i::Int)
    return getindex.(external_forces(st_sol, peh), i)
end

"Return the stresses solution  at the `PointEvalHandler` `peh`."
function stress(st_sol::StatesSolution, peh::PointEvalHandler)
    point_to_element_vec = points_to_element(interpolator(peh))
    vec_points = points(peh)
    num_points = length(vec_points)

    sol_points = Vector{Vector{<:AbstractMatrix{Float64}}}(undef, num_points)

    for index_p in 1:num_points
        element_p = point_to_element_vec[index_p]
        sol_points[index_p] = stress(st_sol, element_p)
    end
    return sol_points
end

end # module