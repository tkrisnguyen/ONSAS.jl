"""
Module to export ONSAS data structures to `.vtk` files suitable for [Paraview](https://www.paraview.org/).
"""
module VTK

using Reexport
using WriteVTK

using ..Meshes
using ..Nodes
using ..Utils
using ..Entities
using ..Tetrahedrons
using ..Solutions
using ..Structures
using ..StructuralAnalyses

export VTKMeshFile, create_vtk_grid, write_node_data, write_cell_data, write_vtk, to_vtk

"""
Represents a VTK file for mesh data export.
This structure is compatible with the `WriteVTK` library.
"""
struct VTKMeshFile{VTK<:WriteVTK.DatasetFile}
    "`WriteVTK` `VTK` native file."
    vtk::VTK
end
function VTKMeshFile(filename::String, Mesh::AbstractMesh; kwargs...)
    vtk = create_vtk_grid(filename, Mesh; kwargs...)
    VTKMeshFile(vtk)
end
# Functor handler allowing do syntax
function VTKMeshFile(f::Function, args...; kwargs...)
    vtk = VTKMeshFile(args...; kwargs...)
    try
        f(vtk)
    finally
        close(vtk)
    end
    vtk
end
function Base.show(io::IO, ::MIME"text/plain", (; vtk)::VTKMeshFile)
    open_str = isopen(vtk) ? "open" : "closed"
    filename = vtk.path
    ncells = vtk.Ncls
    nnodes = vtk.Npts
    print(io,
          "• VTKMeshFile file \"$(filename)\" is $open_str with $nnodes nodes and $ncells cells.")
end

"""
Create a VTK mesh grid from an `AbstractMesh`.
Initializes the VTK grid with node coordinates and cell connectivity.
"""
function create_vtk_grid(filename::String, mesh::AbstractMesh{dim}; kwargs...) where {dim}
    cls = WriteVTK.MeshCell[]
    for elem in elements(mesh)
        VTK_elem_type = to_vtkcell_type(elem)
        push!(cls, WriteVTK.MeshCell(VTK_elem_type, to_vtk_cell_nodes(elem, mesh)))
    end
    coords = node_matrix(mesh)
    WriteVTK.vtk_grid(filename, coords, cls; kwargs...)
end
function Base.close(vtk::VTKMeshFile)
    WriteVTK.vtk_save(vtk.vtk)
end

"""
Converts element types from `ONSAS` to VTK-compatible cell types for tetrahedral elements.
"""
to_vtkcell_type(::Tetrahedron) = VTKCellTypes.VTK_TETRA

"""
Maps the nodes of an element within a mesh to its VTK cell node indices.
Returns connectivity indices for the specified element in the mesh.
"""
function to_vtk_cell_nodes(e::AbstractElement, msh::AbstractMesh)
    connectivity(msh)[findfirst(==(e), elements(msh))]
end

function _vtk_write_node_data(vtk::WriteVTK.DatasetFile,
                              nodal_data::Vector{<:Real},
                              name::AbstractString;
                              kwargs...)
    WriteVTK.vtk_point_data(vtk, nodal_data, name; kwargs...)
end
function _vtk_write_node_data(vtk::WriteVTK.DatasetFile,
                              nodal_data::Matrix{<:Real},
                              name::AbstractString;
                              kwargs...)
    WriteVTK.vtk_point_data(vtk, nodal_data, name; kwargs...)
end
"""
Write nodal data to a VTK file.
Handles scalar or matrix data for each node in a mesh.
"""
function write_node_data(vtk::VTKMeshFile, nodedata, name; kwargs...)
    _vtk_write_node_data(vtk.vtk, nodedata, name; kwargs...)
    vtk
end

"""
Write cell data to a VTK file.
Handles scalar or matrix data for each cell in a mesh.
"""
function write_cell_data(vtk::VTKMeshFile, celldata, name; kwargs...)
    WriteVTK.vtk_cell_data(vtk.vtk, celldata, name; kwargs...)
    vtk
end

"""
Provides default component labels for matrices of size 3x3 or 2x2.
Used to label stress and strain components for VTK output.
"""
function default_component_labels(x::AbstractMatrix{<:Real})
    if size(x) == (3, 3)
        labels = ["xx", "yy", "zz", "yz", "xz", "xy", "zy", "zx", "yx"]
    elseif size(x) == (2, 2)
        labels = ["xx", "yy", "xy", "yx"]
    else
        error("Unsupported matrix size $(size(x)). Only 3x3 and 2x2 matrices are supported.")
    end
    labels
end

to_vtk(x::Vector) = x
const VTX_VOIGT_ORDER = [1, 6, 5, 9, 2, 4, 8, 7, 3]
to_vtk(x::AbstractMatrix) = view(x, VTX_VOIGT_ORDER)

function write_cell_data(vtk::VTKMeshFile, celldata::Vector{<:Matrix{<:Real}}, name;
                         component_labels=(default_component_labels(first(celldata))),
                         kwargs...)
    labels = component_labels
    transformed_celldata = [to_vtk(celldata[j]) for j in 1:length(celldata)]
    for (label, index) in zip(labels, 1:length(labels))
        component_data = [transformed_celldata[j][index] for j in 1:length(transformed_celldata)]
        write_cell_data(vtk, component_data, "$name" * "_" * "$label"; kwargs...)
    end
    vtk
end

function default_dof_fields(sol::AbstractSolution)
    ns = nodes(mesh(structure(analysis(sol))))
    nf = collect(keys(dofs(first(ns))))
    push!(nf, :σ)
    push!(nf, :ϵ)
    nf
end

const POINT_FIELDS = [:u, :θ]
const CELL_FIELDS = Dict(:σ => (3, 3), :ϵ => (3, 3))
const FIELD_NAMES = Dict(:u => "Displacement" => ["ux", "uy", "uz"],
                         :θ => "Rotation" => ["θx", "θy", "θz"],
                         :σ => "Stress" => ["σxx", "σyy", "σzz", "τyz", "τxz", "τxy", "τzy", "τzx",
                                            "τyx"],
                         :ϵ => "Strain" => ["ϵxx", "ϵyy", "ϵzz", "γyz", "γxz", "γxy", "γzy", "γzx",
                                            "γyx"])

function _extract_node_data(sol::AbstractSolution, vf::Vector{Field}, msh, time_index::Integer)
    nodal_data = Dict(field => zeros(num_dofs(msh, field))
                      for field in vf if field ∈ POINT_FIELDS)
    for node in nodes(msh)
        for field in vf
            if field ∈ POINT_FIELDS
                ndofs = dofs(node, field)
                node_dof_data = displacements(sol, ndofs, time_index)
                nodal_data[field][ndofs] .= to_vtk(node_dof_data)
            end
        end
    end
    nodal_data
end
function _extract_cell_data(sol::AbstractSolution, vf::Vector{Field},
                            msh::AbstractMesh, time_index::Integer)
    cell_data = Dict(field => zeros(prod(CELL_FIELDS[field]) * num_elements(msh))
                     for field in vf if field ∈ keys(CELL_FIELDS))

    for (i, elem) in enumerate(elements(msh))
        for field in vf
            if haskey(CELL_FIELDS, field)
                num_field_comps = prod(CELL_FIELDS[field])
                start = (i - 1) * num_field_comps + 1
                finish = start + num_field_comps - 1
                if field == :σ
                    σ = stress(sol, elem, time_index)
                    cell_data[field][start:finish] .= to_vtk(σ)
                elseif field == :ϵ
                    ϵ = strain(sol, elem, time_index)
                    cell_data[field][start:finish] .= to_vtk(ϵ)
                end
            end
        end
    end
    cell_data
end

"""
Generate a VTK file from a solution structure, exporting simulation data such as displacements, strain, and stress.

The `write_vtk` function creates a VTK file that captures nodal and elemental data at a specified time step, making it suitable for visualization in ParaView or other compatible tools. This function is part of the export pipeline for `ONSAS` solutions, allowing users to analyze and visualize time-dependent results in a structured format.

The exported data typically includes:
- **Displacements** (`:u`): Vector field data representing nodal displacements, with components labeled `ux`, `uy`, `uz`.
- **Strain** (`:ϵ`): Second-order tensor field data for each element, representing deformation with components such as `ϵxx`, `ϵyy`, `ϵzz`, and shear components.
- **Stress** (`:σ`): Second-order tensor field data for each element, representing internal forces with components such as `σxx`, `σyy`, `σzz`, and shear components.

**DISCLAIMER:** The user is responsible for inspecting which strain and stress tensors are exported for each element formulation. It is essential to verify compatibility with the desired output before proceeding.
"""
function write_vtk(sol::AbstractSolution, filename::String,
                   time_index::Integer;
                   fields::Vector{Field}=default_dof_fields(sol))
    msh = mesh(structure(analysis(sol)))

    # Extract node and cell data using helper functions
    nodal_data = _extract_node_data(sol, fields, msh, time_index)
    cell_data = _extract_cell_data(sol, fields, msh, time_index)

    # Write VTK file
    @info "VTK output written to $filename"
    VTKMeshFile(filename, msh) do vtx
        for (field, data) in nodal_data
            field_name, component_names = FIELD_NAMES[field]
            write_node_data(vtx, data, field_name; component_names)
        end
        for (field, data) in cell_data
            field_name, component_names = FIELD_NAMES[field]
            write_cell_data(vtx, data, field_name; component_names)
        end
    end
end

function WriteVTK.collection_add_timestep(pvd::WriteVTK.CollectionFile, datfile::VTKMeshFile,
                                          time::Real)
    WriteVTK.collection_add_timestep(pvd, datfile.vtk, time)
end
function Base.setindex!(pvd::WriteVTK.CollectionFile, datfile::VTKMeshFile, time::Real)
    WriteVTK.collection_add_timestep(pvd, datfile, time)
end

"""
Generate a time-series of VTK files for a solution struct and organize them into a ParaView collection.
Each time step's VTK file is added to the collection for seamless visualization of the simulation over time.
Returns the path to the generated ParaView collection file.
"""
function write_vtk(sol::AbstractSolution, base_filename::String;
                   fields::Vector{Field}=default_dof_fields(sol))
    times_vector = times(analysis(sol))  # Extract the times from the solution analysis
    pvd = paraview_collection(base_filename)

    # Loop over each time index and generate VTK files
    for (time_index, time) in enumerate(times_vector)
        vtk_filename = "$(base_filename)_timestep_$time_index.vtu"
        vtk = write_vtk(sol, vtk_filename, time_index; fields)
        pvd[time] = vtk
    end

    # Close the ParaView collection file
    close(pvd)

    @info "ParaView collection file and time series data written to $base_filename.pvd"
    return "$base_filename.pvd"
end

end
