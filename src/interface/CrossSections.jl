"""
Module defining geometric entities interface.
"""
module CrossSections

export AbstractCrossSection, area, Ixx, Iyy, Izz, Ixy, Iyz, I_tensor_xyz
export Rectangle, Square, Circle, GenericCrossSection
# ======================
# Abstract Cross Section
# ======================

""" Abstract supertype for all elements corss-section.

The following methods are provided by the interface:
- `area (cs)`        -- returns the cross-section area.
- `Ixx (cs)`         -- returns the moment of inertia with respect to `x` axis.
- `Iyy (cs)`         -- returns the moment of inertia with respect to `y` axis.
- `Izz (cs)`         -- returns the moment of inertia with respect to `z` axis.
- `Ixy (cs)`         -- returns the product moment of area respect to the `x-y` axes.
- `Ixz (cs)`         -- returns the product moment of area respect to the `x-z` axes.
- `Iyz (cs)`         -- returns the product moment of area respect to the `y-z` axes.
- `I_tensor_xyz(cs)` -- returns the inertia tensor in the system of coordinates `x-y-z`.
"""

abstract type AbstractCrossSection end

const ERROR_CS = :("This method is not available for this cross-section type. Please implement it")

"Returns the cross-section area"
area(::AbstractCrossSection) = error(ERROR_CS)

"Returns the moment of inertia with respect to `x` axis."
Ixx(::AbstractCrossSection) = error(ERROR_CS)

"Returns the moment of inertia with respect to `y` axis."
Iyy(::AbstractCrossSection) = error(ERROR_CS)

"Returns the moment of inertia with respect to `z` axis."
Izz(::AbstractCrossSection) = error(ERROR_CS)

"Returns the product moment of area respect to the `x-y` axes."
Ixy(::AbstractCrossSection) = error(ERROR_CS)

"Returns the product moment of area respect to the `x-z` axes."
Ixz(::AbstractCrossSection) = error(ERROR_CS)

"Returns the product moment of area respect to the `y-z` axes."
Iyz(::AbstractCrossSection) = error(ERROR_CS)

"Returns the inertia tensor in the system of coordinates `x-y-z`"
I_tensor_xyz(cs::AbstractCrossSection) = [
    Ixx(cs) -Ixy(cs) -Ixz(cs)
    -Ixy(cs) Iyy(cs) -Iyz(cs)
    -Ixz(cs) -Iyz(cs) Izz(cs)
]

#########################################
# AbstractCrossSection implementations #
########################################


""" Rectangle cross-section.
### Fields:
- `width_y` -- width in `y` axis.
- `width_z` -- width in `z` axis.
"""
struct Rectangle <: AbstractCrossSection
    width_y::Number
    width_z::Number
end

area(r::Rectangle) = r.width_y * r.width_z
function Ixx(r::Rectangle)
    #  torsional constant from table 10.1 from Roark's Formulas for Stress and Strain 7th ed.
    a = 0.5 * max([r.width_y, r.width_z])
    b = 0.5 * min([r.width_y, r.width_z])

    Ixx = a * b^3 * (16 / 3 - 3.36 * b / a * (1 - b^4 / (12 * a^4)))
    return Ixx
end
Iyy(r::Rectangle) = r.width_z^3 * r.width_y / 12
Izz(r::Rectangle) = r.width_y^3 * r.width_z / 12
Ixy(r::Rectangle) = 0.0
Ixz(r::Rectangle) = 0.0
Iyz(r::Rectangle) = 0.0


""" Square cross-section.
### Fields:
- `width` -- width in `y` and `z` axes.
"""
struct Square <: AbstractCrossSection
    width::Number
end

area(s::Square) = s.width^2
Ixx(s::Square) = (0.5 * s.width)^3 * (16 / 3 - 3.36 * (1 - (0.5 * s.width)^4 / (12 * (0.5 * s.width)^4)))
Iyy(s::Square) = s.width^4 / 12
Izz(s::Square) = s.width^4 / 12
Ixy(s::Square) = 0.0
Ixz(s::Square) = 0.0
Iyz(s::Square) = 0.0

""" Circle cross-section.
### Fields:
- `d` -- circle diameter.
"""
struct Circle <: AbstractCrossSection
    d::Number
end

area(c::Circle) = c.d^2 / 4
Ixx(c::Circle) = c.d^4 / 32
Iyy(c::Circle) = c.d^4 / 64
Izz(c::Circle) = c.d^4 / 64
Ixy(c::Circle) = 0.0
Ixz(c::Circle) = 0.0
Iyz(c::Circle) = 0.0


""" Generic cross-section.

This generic cross-section struct can be used to define a cross-section not belonging to the existing categories. 

### Fields:
- `A` -- area.
- `Ixx` -- moment of inertia respect to `x` axis.
- `Iyy` -- moment of inertia respect to `y` axis.
- `Izz` -- moment of inertia respect to `z` axis.
- `Ixy` -- product moment of area respect to the `x-y` axes.
- `Ixz` -- product moment of area respect to the `x-z` axes.
- `Iyz` -- product moment of area respect to the `y-z` axes.
"""
struct GenericCrossSection <: AbstractCrossSection
    A::Number
    Ixx::Number
    Iyy::Number
    Izz::Number
    Ixy::Number
    Ixz::Number
    Iyz::Number
end

"Constructor for cross-sections in the principal axes system."
GenericCrossSection(A, Ixx, Iyy, Izz) = GenericCrossSection(A, Ixx, Iyy, Izz, 0.0, 0.0, 0.0)

# Create accessors methods
for f in fieldnames(GenericCrossSection)
    @eval $f(gcs::GenericCrossSection) = gcs.$f
end

end # module