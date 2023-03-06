using ..Elements: AbstractNode, AbstractFace, AbstractElement
using ..Meshes: AbstractMesh, Mesh, MshFile
using ..BoundaryConditions: FixedDofBoundaryCondition, _apply
using ..StructuralModel: AbstractStructure, StructuralMaterials, StructuralBoundaryConditions, StructuralEntities


"""
An `Structure` object facilitates the process of assembling and creating the structural analysis. 
### Fields:
- `mesh`      -- Stores the structural mesh. 
- `materials` -- Stores the structural materials of the structure. 
- `elements`  -- Stores the structural elements of the structure.
- `bcs`       -- Stores the structural boundary conditions of the structure.
- `free_dofs` -- Stores the free degrees of freedom.
"""
struct Structure{dim,MESH,MAT,E,NB,LB} <: AbstractStructure{dim,MAT,E}
    mesh::MESH
    materials::StructuralMaterials{MAT,E}
    bcs::StructuralBoundaryConditions{NB,LB}
    free_dofs::Vector{Dof}
    function Structure(
        mesh::MESH,
        materials::StructuralMaterials{MAT,E},
        bcs::StructuralBoundaryConditions{NB,LB},
        free_dofs::Vector{Dof}
    ) where {dim,MESH<:AbstractMesh{dim},MAT,E,NB,LB}
        return new{dim,MESH,MAT,E,NB,LB}(mesh, materials, bcs, free_dofs)
    end
end

"Constructor with  `StructuralMaterials` `materials`,  `StructuralBoundaryConditions` `bcs` 
and `AbstractMesh` `mesh` seting fixed dofs with `FixedDofBoundaryCondition` defined in `bcs`"
function Structure(
    mesh::AbstractMesh{dim},
    materials::StructuralMaterials{M,E},
    bcs::StructuralBoundaryConditions{NB,LB},
) where {dim,M,E,NB,LB}

    default_free_dofs = Vector{Dof}()
    for node_dofs in dofs(mesh)
        [push!(default_free_dofs, vec_dof...) for vec_dof in collect(values(node_dofs))]
    end

    fixed_dofs = _apply(bcs, fixed_dof_bcs(bcs))

    deleteat!(default_free_dofs, findall(x -> x in fixed_dofs, default_free_dofs))

    return Structure(mesh, materials, bcs, default_free_dofs)
end


"Constructor of a `Structure` given a `MshFile` `msh_file`, `StructuralMaterials` `materials`,  `StructuralBoundaryConditions` `bcs`."

function Structure(msh_file::MshFile, materials::StructuralMaterials, bcs::StructuralBoundaryConditions, s_entities::StructuralEntities)

    nodes = msh_file.vec_nodes
    mesh = Mesh(nodes)

    for (index_entity, entity_nodes_indexes) in enumerate(msh_file.connectivity)

        # Find physical entities index
        physical_entity_index = msh_file.physical_indexes[index_entity]

        # Create entity and push it into the mesh
        nodes_entity = view(nodes, entity_nodes_indexes)
        entity_type_label = msh_file.entities_labels[physical_entity_index]
        entity_type = s_entities[entity_type_label]
        entity = create_entity(entity_type, nodes_entity)
        push!(mesh, entity)

        # Find material and push 
        material_type_label = msh_file.material_labels[physical_entity_index]
        # If has material defined is an element not a surface
        if ~isempty(material_type_label)
            material_type = materials[material_type_label]
            push!(materials[material_type], entity)
        end

        # Find boundary conditions 
        bc_type_label = msh_file.bc_labels[physical_entity_index]
        if ~isempty(bc_type_label)
            bc_type = bcs[bc_type_label]
            # Push the entity in the corresponding node, face or element dict in bcs
            if entity isa AbstractNode
                push!(node_bcs(bcs)[bc_type], entity)
            elseif entity isa AbstractFace
                push!(face_bcs(bcs)[bc_type], entity)
            elseif entity isa AbstractElement
                push!(element_bcs(bcs)[bc_type], entity)
            end
        end

    end

    dof_dim = dimension(mesh)
    add!(mesh, :u, dof_dim)


    return Structure(mesh, materials, bcs)
end
