
# ======================================================================
# material
# ======================================================================

"""
Struct with information of the material.
"""
mutable struct Material{T}
    type::String
    constitutive_params::Vector{T}
    density::Union{Float64,Nothing}
    # define constructor with  no density by default
    function Material(type::String, constitutive_params::Vector{T}, density=nothing::Union{Float64,Nothing}) where {T}
        new{T}(type, constitutive_params, density) # default density: zero
    end
end

# ======================================================================
# geometry
# ======================================================================
abstract type AbstractSection end

struct Rectangle <: AbstractSection
    width_y::Float64
    width_z::Float64
end

struct Circle <: AbstractSection
    dia::Float64
end

struct CrossSection
    section::AbstractSection
    A::Float64
    Ix::Float64
    Iy::Float64
    Iz::Float64
end

function CrossSection() end

function CrossSection(section::Rectangle)
    width_y = section.width_y
    width_z = section.width_z

    A = width_y * width_z

    a = 0.5 * max(width_y, width_z)
    b = 0.5 * min(width_y, width_z)

    Ix = a * b^3 * (16 / 3.0 - 3.36 * b / a * (1.0 - b^4 / (12 * a^4)))
    Iy = width_y * width_z^3 / 12
    Iz = width_z * width_y^3 / 12
    return CrossSection(section, A, Ix, Iy, Iz)
end

function CrossSection(section::Circle)
    dia = section.dia

    A = pi * dia^2 / 4

    Iy = pi * dia^4 / 64
    Iz = pi * dia^4 / 64
    Ix = Iy + Iz

    return CrossSection(section, A, Ix, Iy, Iz)
end

"""
    AbstractElement

Abstract type to define finite element types.\\

Available types:

* `Node`: 
* `Truss`: 
* `Frame`: 
* `Triangle`: 
* `Tetrahedron`: 


"""
abstract type AbstractElement end

struct Node <: AbstractElement end
struct Truss <: AbstractElement end
struct Frame <: AbstractElement end
struct Triangle <: AbstractElement end
struct Tetrahedron <: AbstractElement end

"""
Struct with information of the geometry of the element:
 - element_type: a struct with: `node`, `truss`, `frame``, `triangle` or `tetrahedron`.
"""
struct Geometry
    type::AbstractElement
    cross_section
    # define constructor with no cross section by default
    function Geometry(type::AbstractElement, cross_section=nothing)
        new(type, CrossSection())
    end
end

# ======================================================================
# Loads Boundary Conditions
# ======================================================================
abstract type AbstractLoads end

struct LoadsBoundaryCondition <: AbstractLoads
    loadsBaseVals::Vector
    loadsCoordSystem::String
    loadsTimeFactor::Float64
end
# constructor with missing fields
function LoadsBoundaryCondition(loadsBaseVals::Vector, loadsCoordSystem::String)
    return LoadsBoundaryCondition(loadsBaseVals, loadsCoordSystem, 1.0)
end

function LoadsBoundaryCondition(loadsBaseVals=nothing, loadsCoordSystem=nothing, loadsTimeFactor=nothing)
    return LoadsBoundaryCondition([], "", 1.0)
end

struct UserLoadsBoundaryCondition <: AbstractLoads
    user_load_function::Function
end

# ======================================================================
# Dofs Boundary Conditions - Springs and imposed displacements (zero & nonzero)
# ======================================================================
abstract type AbstractDofs end

struct DispsBoundaryCondition <: AbstractDofs
    imposed_disp_dofs::Vector{Integer}
    imposed_disp_vals::Vector{Float64}
end

struct SpringsBoundaryCondition <: AbstractDofs
    # to do
end

# ======================================================================
# Initial Conditions
# ======================================================================
struct InitialCondition
    dofs::Vector{Integer}
    vals::Vector{Float64}
end


# ======================================================================
# Mesh
# ======================================================================
struct Mesh
    nodal_coords::Matrix{Float64}
    elem_nodal_connec::Vector{Vector{Int64}}
    MGBI_mat::Matrix{Int64}
    MGBI_vec::Vector{Int64}
end


# ======================================================================
# AnalysisSettings
# ======================================================================
"""
    AbstractAlgorithm

Abstract type to define numerical method algorithms.

"""
abstract type AbstractAlgorithm end

"""
    AnalysisSettings

Struct to define convergence tolerances.

"""
struct ConvergenceSettings

    # method::String
    # delta_time::Float64
    # final_time::Float64

    #delta_time > final_time && error("delta_time must be lower than final_time")

    stop_tol_disps::Float64
    stop_tol_force::Float64
    stop_tol_iters::Int

    # function AnalysisSettings(method::String, delta_time::Float64, final_time::Float64,
    #     stop_tol_disps=1e-6::Float64, stop_tol_force=1e-6::Float64, stop_tol_iters=20::Integer)
    #     new(method, delta_time, final_time, stop_tol_disps, stop_tol_force, stop_tol_iters)
    # end

    function ConvergenceSettings(stop_tol_disps=1e-6::Float64, stop_tol_force=1e-6::Float64, stop_tol_iters=20::Int)
        new(stop_tol_disps, stop_tol_force, stop_tol_iters)
    end

end
