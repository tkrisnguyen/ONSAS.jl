using .Materials: _DEFAULT_LABEL, AbstractMaterial
using ..Utils: label

import .Materials: parameters

export SVK, lame_parameters

""" SVK material struct.
### Fields:
- `E` -- Elasticity modulus.
- `ν` -- Poisson's ratio.
- `ρ` -- Density (`nothing` for static cases).
- `label` -- Label of the material

"""
struct SVK{T<:Real} <: AbstractMaterial
    E::T
    ν::T
    ρ::Union{T,Nothing}
    label::Symbol
    function SVK(E::T, ν::T, ρ=nothing, label=_DEFAULT_LABEL) where {T<:Real}
        return new{T}(E, ν, ρ, Symbol(label))
    end
end

"Constructor with lamé parameters λ and G"
function SVK(; λ::Real, G::Real, ρ::Real, label)

    # Compute E and ν given Lamé parameters λ and μ (μ = G)
    E = G * (3λ + 2G) / (λ + G)
    ν = λ / (2(λ + G))

    return SVK(E, ν, ρ, Symbol(label))
end


"Returns SVK parameters tuple."
parameters(m::SVK) = (m.E, m.ν)

" Convert svk material parameters to lamé nomenclature"
function lame_parameters(svk::SVK)

    E = svk.E
    ν = svk.ν

    # Compute Lamé parameters λ and G
    G = E / (2(1 + ν))
    λ = E * ν / ((1 + ν) * (1 - 2 * ν))

    return λ, G
end
