using Reexport

using ..Elements
using ..Meshes
using ..BoundaryConditions
using ..StructuralModel

@reexport import ..Meshes: PointEvalHandler

"""
An `Structure` object facilitates the process of assembling and creating the structural analysis. 
### Fields:
- `mesh`      -- stores the structural mesh. 
- `materials` -- stores the structural materials of the structure. 
- `elements`  -- stores the structural elements of the structure.
- `bcs`       -- stores the structural boundary conditions of the structure.
- `free_dofs` -- stores the free degrees of freedom.
"""
struct Structure{dim,MESH,MAT,E,NB,LB} <: AbstractStructure{dim,MAT,E}
    mesh::MESH
    materials::StructuralMaterials{MAT,E}
    bcs::StructuralBoundaryConditions{NB,LB}
    free_dofs::Vector{Dof}
    function Structure(mesh::MESH,
                       materials::StructuralMaterials{MAT,E},
                       bcs::StructuralBoundaryConditions{NB,LB},
                       free_dofs::Vector{Dof}) where {dim,MESH<:AbstractMesh{dim},MAT,E,NB,LB}
        return new{dim,MESH,MAT,E,NB,LB}(mesh, materials, bcs, free_dofs)
    end
end

"Constructor with  `StructuralMaterials` `materials`,  `StructuralBoundaryConditions` `bcs` 
and `AbstractMesh` `mesh` seting fixed dofs with `FixedDofBoundaryCondition` defined in `bcs`"
function Structure(mesh::AbstractMesh{dim},
                   materials::StructuralMaterials{M,E},
                   bcs::StructuralBoundaryConditions{NB,LB}) where {dim,M,E,NB,LB}
    default_free_dofs = Vector{Dof}()
    for node_dofs in dofs(mesh)
        [push!(default_free_dofs, vec_dof...) for vec_dof in collect(values(node_dofs))]
    end

    fixed_dofs = _apply(bcs, fixed_dof_bcs(bcs))

    deleteat!(default_free_dofs, findall(x -> x in fixed_dofs, default_free_dofs))

    return Structure(mesh, materials, bcs, default_free_dofs)
end

"Constructor of a `Structure` given a `MshFile` `msh_file`, `StructuralMaterials` `materials`,  `StructuralBoundaryConditions` `bcs`."
function Structure(msh_file::MshFile,
                   materials::StructuralMaterials, bcs::StructuralBoundaryConditions,
                   s_entities::StructuralEntities,
                   dofs_to_dim::Dictionary{Symbol,<:Integer}=dictionary([:u => 3]))
    nodes = msh_file.vec_nodes
    mesh = Mesh(nodes)

    # Loop over all physical entities
    for (entity_index, entity_nodes_indexes) in enumerate(msh_file.connectivity)

        # Create entity and push it into the mesh
        nodes_entity = view(nodes, entity_nodes_indexes)
        entity_type_label = entity_label(msh_file, entity_index)
        # Check if the entity is a node, if not add it to the mesh
        # Main.@infiltrate

        if entity_type_label == "node"
            entity = nodes_entity[]
        else
            entity_type = s_entities[entity_type_label]
            entity = create_entity(entity_type, nodes_entity)
            push!(mesh, entity)
        end

        # Find material and push 
        material_type_label = material_label(msh_file, entity_index)
        # If has material defined is an element not a surface
        if ~isempty(material_type_label)
            material_type = materials[material_type_label]
            push!(materials[material_type], entity)
        end

        # Find boundary conditions 
        bc_type_label = bc_label(msh_file, entity_index)
        if ~isempty(bc_type_label)
            bc_type = bcs[bc_type_label]
            push!(bcs, bc_type, entity)
        end
    end

    for (dof_symbol, dof_dim) in pairs(dofs_to_dim)
        apply!(mesh, dof_symbol, dof_dim)
    end

    return Structure(mesh, materials, bcs)
end

"Constructor of a `PointEvalHandler` from a `Structure` and a `AbstractVector` of `Point`s ."
function PointEvalHandler(s::Structure, vec_points::AbstractVector{P}) where {T,P<:Point{T}}
    return PointEvalHandler(mesh(s), vec_points)
end