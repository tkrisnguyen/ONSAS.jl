using ..StaticAnalyses
using ...StructuralSolvers: AbstractSolver, NewtonRaphson, StatesSolution, tolerances
using ...StructuralModel: AbstractStructure

import ...StructuralSolvers: _solve, _step!

export LinearStaticAnalysis

""" LinearStaticAnalysis struct.
A `LinearStaticAnalysis` is a collection of parameters for defining the static analysis of the structure. 
In the static analysis, the structure is analyzed at a given load factor (this variable is analog to time).
As this analysis is linear the stiffness of the structure remains constant at each displacements iteration step. 
### Fields:
- `s`             -- stores the structure to be analyzed.
- `state`         -- stores the structural state.
- `λᵥ`            -- stores the load factors vector of the analysis
- `current_step`  -- stores the current load factor step
"""
mutable struct LinearStaticAnalysis{S<:AbstractStructure,LFV<:AbstractVector{<:Real}} <: AbstractStaticAnalysis
    s::S
    state::StaticState
    λᵥ::LFV
    current_step::Int
    function LinearStaticAnalysis(s::S, λᵥ::LFV; initial_step::Int=1) where {S<:AbstractStructure,LFV<:AbstractVector{<:Real}}
        new{S,LFV}(s, StaticState(s), λᵥ, initial_step)
    end
end

"Constructor for `LinearStaticAnalysis` given a final time (or load factor) `t₁` and the number of steps `NSTEPS`."
function LinearStaticAnalysis(s::AbstractStructure, t₁::Real=1.0; NSTEPS=10, initial_step::Int=1)
    t₀ = t₁ / NSTEPS
    λᵥ = LinRange(t₀, t₁, NSTEPS) |> collect
    LinearStaticAnalysis(s, λᵥ, initial_step=initial_step)
end

"Solves an `LinearStaticAnalysis` `sa`."
function _solve(sa::LinearStaticAnalysis)

    s = structure(sa)

    # Initialize solution
    sol = StatesSolution(sa, NewtonRaphson())

    # load factors iteration 
    while !is_done(sa)

        _apply!(sa, load_bcs(s)) # Compute Fext

        @debug external_forces(current_state(sa))

        _assemble!(s, sa)

        # Show internal, and residual forces and tangent matrix
        @debug view(internal_forces(current_state(sa)), index.(free_dofs(s)))
        @debug residual_forces(current_state(sa))
        @debug tangent_matrix(current_state(sa))[index.(free_dofs(s)), index.(free_dofs(s))]

        # Increment U 
        _step!(sa)

        # Save current state
        push!(sol, current_state(sa))

        _next!(sa)

    end

    return sol
end

"Computes ΔU for solving the `LinearStaticAnalysis`."
function _step!(sa::LinearStaticAnalysis)

    # Extract state info
    c_state = current_state(sa)
    f_dofs_indexes = index.(free_dofs(c_state))

    # Compute Δu
    fₑₓₜ_red = view(external_forces(c_state), f_dofs_indexes)
    K = view(tangent_matrix(c_state), f_dofs_indexes, f_dofs_indexes)
    ΔU = cg(K, fₑₓₜ_red)

    # Update displacements into the state
    _update!(c_state, ΔU)

end