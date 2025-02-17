
"""
````
abstract type H1P1TEB{edim} <: AbstractH1FiniteElementWithCoefficients where {edim<:Int}
````

vector-valued (ncomponents = edim) element that uses P1 functions + tangential-weighted edge bubbles
as suggested by ["Fortin Operator for the Taylor-Hood Element", 2021, arxiv:2104.13953]

(is inf-sup stable for Stokes if paired with continuous P1 pressure space, less degrees of freedom than MINI)

allowed ElementGeometries:
- Triangle2D
- Tetrahedron3D
"""
abstract type H1P1TEB{edim} <: AbstractH1FiniteElementWithCoefficients where {edim<:Int} end

function Base.show(io::Core.IO, ::Type{<:H1P1TEB{edim}}) where {edim}
    print(io,"H1P1TEB{edim}")
end

get_ncomponents(FEType::Type{<:H1P1TEB}) = FEType.parameters[1]
get_ndofs(::Union{Type{<:ON_FACES}, Type{<:ON_BFACES}}, FEType::Type{<:H1P1TEB{2}}, EG::Type{<:AbstractElementGeometry}) = 1 + nnodes_for_geometry(EG) * FEType.parameters[1]
get_ndofs(::Type{ON_CELLS}, FEType::Type{<:H1P1TEB{2}}, EG::Type{<:AbstractElementGeometry}) = nfaces_for_geometry(EG) + nnodes_for_geometry(EG) * FEType.parameters[1]
get_ndofs(::Union{Type{<:ON_EDGES}, Type{<:ON_BEDGES}}, FEType::Type{<:H1P1TEB{3}}, EG::Type{<:AbstractElementGeometry}) = 1 + nnodes_for_geometry(EG) * FEType.parameters[1]
get_ndofs(::Union{Type{<:ON_FACES}, Type{<:ON_BFACES}}, FEType::Type{<:H1P1TEB{3}}, EG::Type{<:AbstractElementGeometry}) = nedges_for_geometry(EG) + nnodes_for_geometry(EG) * FEType.parameters[1]
get_ndofs(::Type{ON_CELLS}, FEType::Type{<:H1P1TEB{3}}, EG::Type{<:AbstractElementGeometry}) = nedges_for_geometry(EG) + nnodes_for_geometry(EG) * FEType.parameters[1]

get_polynomialorder(::Type{<:H1P1TEB{2}}, ::Type{<:Edge1D}) = 2
get_polynomialorder(::Type{<:H1P1TEB{2}}, ::Type{<:Triangle2D}) = 2
get_polynomialorder(::Type{<:H1P1TEB{3}}, ::Type{<:Edge1D}) = 2
get_polynomialorder(::Type{<:H1P1TEB{3}}, ::Type{<:Triangle2D}) = 2
get_polynomialorder(::Type{<:H1P1TEB{3}}, ::Type{<:Tetrahedron3D}) = 2

get_dofmap_pattern(FEType::Type{<:H1P1TEB{2}}, ::Type{CellDofs}, EG::Type{<:Triangle2D}) = "N1f1"
get_dofmap_pattern(FEType::Type{<:H1P1TEB{2}}, ::Type{FaceDofs}, EG::Type{<:Edge1D}) = "N1i1"
get_dofmap_pattern(FEType::Type{<:H1P1TEB{2}}, ::Type{BFaceDofs}, EG::Type{<:Edge1D}) = "N1i1"
get_dofmap_pattern(FEType::Type{<:H1P1TEB{3}}, ::Type{EdgeDofs}, EG::Type{<:Edge1D}) = "N1i1"
get_dofmap_pattern(FEType::Type{<:H1P1TEB{3}}, ::Type{CellDofs}, EG::Type{<:Tetrahedron3D}) = "N1e1"
get_dofmap_pattern(FEType::Type{<:H1P1TEB{3}}, ::Type{FaceDofs}, EG::Type{<:Triangle2D}) = "N1e1"
get_dofmap_pattern(FEType::Type{<:H1P1TEB{3}}, ::Type{BFaceDofs}, EG::Type{<:Triangle2D}) = "N1e1"

isdefined(FEType::Type{<:H1P1TEB}, ::Type{<:Triangle2D}) = true
isdefined(FEType::Type{<:H1P1TEB}, ::Type{<:Tetrahedron3D}) = true


function interpolate!(Target::AbstractArray{<:Real,1}, FE::FESpace{FEType}, ::Type{AT_NODES}, exact_function!; items = [], time = 0) where {FEType <: H1P1TEB}
    nnodes = size(FE.xgrid[Coordinates],2)
    point_evaluation!(Target, FE, AT_NODES, exact_function!; items = items, component_offset = nnodes, time = time)
end

function interpolate!(Target::AbstractArray{<:Real,1}, FE::FESpace{FEType}, ::Type{ON_EDGES}, exact_function!; items = [], time = 0) where {FEType <: H1P1TEB}
    # delegate edge nodes to node interpolation
    subitems = slice(FE.xgrid[EdgeNodes], items)
    interpolate!(Target, FE, AT_NODES, exact_function!; items = subitems, time = time)
end

function interpolate!(Target::AbstractArray{T,1}, FE::FESpace{FEType}, ::Type{ON_FACES}, exact_function!; items = [], time = 0) where {T<:Real, FEType <: H1P1TEB{3}}
    # delegate edges to edge interpolation
    subitems = slice(FE.xgrid[FaceEdges], items)
    interpolate!(Target, FE, ON_EDGES, exact_function!; items = subitems, time = time)
end

function interpolate!(Target::AbstractArray{T,1}, FE::FESpace{FEType}, ::Type{ON_FACES}, exact_function!; items = [], time = 0) where {T<:Real, FEType <: H1P1TEB{2}}
    # delegate face nodes to node interpolation
    subitems = slice(FE.xgrid[FaceNodes], items)
    interpolate!(Target, FE, AT_NODES, exact_function!; items = subitems, time = time)

    # preserve face means in tangential direction
    xItemVolumes = FE.xgrid[FaceVolumes]
    xItemNodes = FE.xgrid[FaceNodes]
    xItemGeometries = FE.xgrid[FaceGeometries]
    xFaceNormals = FE.xgrid[FaceNormals]
    xItemDofs = FE[FaceDofs]
    ncomponents = get_ncomponents(FEType)
    nnodes = size(FE.xgrid[Coordinates],2)
    nitems = num_sources(xItemNodes)
    offset = ncomponents*nnodes
    if items == []
        items = 1 : nitems
    end

    # compute exact face means
    facemeans = zeros(Float64,ncomponents,nitems)
    integrate!(facemeans, FE.xgrid, ON_FACES, exact_function!; items = items, time = time)
    P1flux::T = 0
    value::T = 0
    itemEG = Edge1D
    nitemnodes::Int = 0
    for item in items
        itemEG = xItemGeometries[item]
        nitemnodes = nnodes_for_geometry(itemEG)
        # compute normal flux (minus linear part)
        value = 0
        for c = 1 : ncomponents
            P1flux = 0
            for dof = 1 : nitemnodes
                P1flux += Target[xItemDofs[(c-1)*nitemnodes + dof,item]] * xItemVolumes[item] / nitemnodes
            end
            if c == 1
                value -= (facemeans[c,item] - P1flux)*xFaceNormals[2,item]
            else
                value += (facemeans[c,item] - P1flux)*xFaceNormals[1,item]
            end
        end
        # set face bubble value
        Target[offset+item] = value / xItemVolumes[item]
    end
end


function interpolate!(Target::AbstractArray{T,1}, FE::FESpace{FEType}, ::Type{ON_EDGES}, exact_function!; items = [], time = 0) where {T<:Real, FEType <: H1P1TEB{3}}
    # delegate face nodes to node interpolation
    subitems = slice(FE.xgrid[EdgeNodes], items)
    interpolate!(Target, FE, AT_NODES, exact_function!; items = subitems, time = time)

    # preserve edge means in tangential direction
    xItemVolumes = FE.xgrid[EdgeVolumes]
    xItemNodes = FE.xgrid[EdgeNodes]
    xItemGeometries = FE.xgrid[EdgeGeometries]
    xEdgeTangents = FE.xgrid[EdgeTangents]
    xItemDofs = FE[EdgeDofs]
    nnodes = size(FE.xgrid[Coordinates],2)
    nitems = num_sources(xItemNodes)
    ncomponents = get_ncomponents(FEType)
    offset = ncomponents*nnodes
    if items == []
        items = 1 : nitems
    end

    # compute exact face means
    edgemeans = zeros(Float64,ncomponents,nitems)
    integrate!(edgemeans, FE.xgrid, ON_EDGES, exact_function!; items = items, time = time)
    P1flux::T = 0
    value::T = 0
    itemEG = Edge1D
    nitemnodes::Int = 0
    for item in items
        itemEG = xItemGeometries[item]
        nitemnodes = nnodes_for_geometry(itemEG)
        # compute normal flux (minus linear part)
        value = 0
        for c = 1 : ncomponents
            P1flux = 0
            for dof = 1 : nitemnodes
                P1flux += Target[xItemDofs[(c-1)*nitemnodes + dof,item]] * xItemVolumes[item] / nitemnodes
            end
            value += (edgemeans[c,item] - P1flux)*xEdgeTangents[c,item]
        end
        # set face bubble value
        Target[offset+item] = value / xItemVolumes[item]
    end
end

function interpolate!(Target::AbstractArray{<:Real,1}, FE::FESpace{FEType}, ::Type{ON_CELLS}, exact_function!; items = [], time = 0) where {FEType <: H1P1TEB}
    # delegate cell faces to face interpolation
    subitems = slice(FE.xgrid[CellFaces], items)
    interpolate!(Target, FE, ON_FACES, exact_function!; items = subitems, time = time)
end


############
# 2D basis #
############

function get_basis(AT::Union{Type{<:ON_FACES}, Type{<:ON_BFACES}}, FEType::Type{H1P1TEB{2}}, EG::Type{<:Edge1D})
    ncomponents = get_ncomponents(FEType)
    refbasis_P1 = get_basis(AT, H1P1{ncomponents}, EG)
    offset = get_ndofs(AT, H1P1{ncomponents}, EG)
    function closure(refbasis, xref)
        refbasis_P1(refbasis, xref)
        # add face bubble to P1 basis
        refbasis[offset+1,:] .= 6 * xref[1] * refbasis[1,1]
    end
end

function get_basis(AT::Type{ON_CELLS}, FEType::Type{H1P1TEB{2}}, EG::Type{<:Triangle2D})
    ncomponents = get_ncomponents(FEType)
    refbasis_P1 = get_basis(AT, H1P1{ncomponents}, EG)
    offset = get_ndofs(AT, H1P1{ncomponents}, EG)
    function closure(refbasis, xref)
        refbasis_P1(refbasis, xref)
        # add face bubbles to P1 basis
        refbasis[offset+1,:] .= 6 * xref[1] * refbasis[1,1]
        refbasis[offset+2,:] .= 6 * xref[2] * xref[1]
        refbasis[offset+3,:] .= 6 * refbasis[1,1] * xref[2]
    end
end

function get_coefficients(::Type{ON_CELLS}, FE::FESpace{H1P1TEB{2}}, ::Type{<:Triangle2D})
    xFaceNormals::Array{Float64,2} = FE.xgrid[FaceNormals]
    xCellFaces = FE.xgrid[CellFaces]
    function closure(coefficients::Array{<:Real,2}, cell)
        fill!(coefficients,1.0)
        coefficients[1,7] = -xFaceNormals[2, xCellFaces[1,cell]];
        coefficients[2,7] = xFaceNormals[1, xCellFaces[1,cell]];
        coefficients[1,8] = -xFaceNormals[2, xCellFaces[2,cell]];
        coefficients[2,8] = xFaceNormals[1, xCellFaces[2,cell]];
        coefficients[1,9] = -xFaceNormals[2, xCellFaces[3,cell]];
        coefficients[2,9] = xFaceNormals[1, xCellFaces[3,cell]];
    end
end

function get_coefficients(::Type{<:ON_FACES}, FE::FESpace{H1P1TEB{2}}, ::Type{<:Edge1D})
    xFaceNormals::Array{Float64,2} = FE.xgrid[FaceNormals]
    function closure(coefficients::Array{<:Real,2}, face)
        # multiplication of face bubble with normal vector of face
        fill!(coefficients,1.0)
        coefficients[1,5] = -xFaceNormals[2, face];
        coefficients[2,5] = xFaceNormals[1, face];
    end
end    



############
# 3D basis #
############

function get_basis(AT::Union{Type{<:ON_FACES}, Type{<:ON_BFACES}}, FEType::Type{H1P1TEB{3}}, EG::Type{<:Triangle2D})
    ncomponents = get_ncomponents(FEType)
    refbasis_P1 = get_basis(AT, H1P1{ncomponents}, EG)
    offset = get_ndofs(AT, H1P1{ncomponents}, EG)
    function closure(refbasis, xref)
        refbasis_P1(refbasis, xref)
        # add edge bubbles to P1 basis
        refbasis[offset+1,:] .= 6 * xref[1] * refbasis[1,1]
        refbasis[offset+2,:] .= 6 * xref[2] * xref[1]
        refbasis[offset+3,:] .= 6 * refbasis[1,1] * xref[2]
    end
end

function get_basis(AT::Type{ON_CELLS}, FEType::Type{H1P1TEB{3}}, EG::Type{<:Tetrahedron3D})
    ncomponents = get_ncomponents(FEType)
    refbasis_P1 = get_basis(AT, H1P1{ncomponents}, EG)
    offset = get_ndofs(AT, H1P1{ncomponents}, EG)
    function closure(refbasis, xref)
        refbasis_P1(refbasis, xref)
        # add edge bubbles to P1 basis
        refbasis[offset+1,:] .= 6 * xref[1] * refbasis[1,1]
        refbasis[offset+2,:] .= 6 * xref[2] * refbasis[1,1]
        refbasis[offset+3,:] .= 6 * xref[3] * refbasis[1,1]
        refbasis[offset+4,:] .= 6 * xref[1] * xref[2]
        refbasis[offset+5,:] .= 6 * xref[1] * xref[3]
        refbasis[offset+6,:] .= 6 * xref[2] * xref[3]
        return nothing
    end
end

function get_coefficients(::Type{ON_CELLS}, FE::FESpace{H1P1TEB{3}}, ::Type{<:Tetrahedron3D})
    xEdgeTangents::Array{Float64,2} = FE.xgrid[EdgeTangents]
    xCellEdges = FE.xgrid[CellEdges]
    function closure(coefficients::Array{<:Real,2}, cell)
        fill!(coefficients,1.0)
        for e = 1 : 6, k = 1 : 2
            coefficients[k,8+e] = xEdgeTangents[k,xCellEdges[e,cell]]
        end
        return nothing
    end
end

function get_coefficients(::Type{<:ON_FACES}, FE::FESpace{H1P1TEB{3}}, ::Type{<:Triangle2D})
    xEdgeTangents::Array{Float64,2} = FE.xgrid[EdgeTangents]
    xFaceEdges = FE.xgrid[FaceEdges]
    function closure(coefficients::Array{<:Real,2}, face)
        fill!(coefficients,1.0)
        for e = 1 : 3, k = 1 : 2
            coefficients[k,6+e] = xEdgeTangents[k,xFaceEdges[e,face]]
        end
        return nothing
    end
end    
