"""
````
abstract type HDIVRT1{edim} <: AbstractHdivFiniteElement where {edim<:Int}
````

Hdiv-conforming vector-valued (ncomponents = edim) Raviart-Thomas space of order 1.

allowed ElementGeometries:
- Triangle2D
- Tetrahedron3D
"""
abstract type HDIVRT1{edim} <: AbstractHdivFiniteElement where {edim<:Int} end

function Base.show(io::Core.IO, FEType::Type{<:HDIVRT1{edim}}) where {edim}
    print(io,"HDIVRT1{$edim}")
end

get_ncomponents(FEType::Type{<:HDIVRT1}) = FEType.parameters[1]
get_ndofs(::Union{Type{<:ON_FACES}, Type{<:ON_BFACES}}, FEType::Type{<:HDIVRT1}, EG::Type{<:AbstractElementGeometry1D}) = 2
get_ndofs(::Union{Type{<:ON_FACES}, Type{<:ON_BFACES}}, FEType::Type{<:HDIVRT1}, EG::Type{<:Triangle2D}) = 3
get_ndofs(::Type{ON_CELLS}, FEType::Type{<:HDIVRT1}, EG::Type{<:Triangle2D}) = 2*nfaces_for_geometry(EG) + 2
get_ndofs(::Type{ON_CELLS}, FEType::Type{<:HDIVRT1}, EG::Type{<:Tetrahedron3D}) = 3*nfaces_for_geometry(EG) + 3
get_ndofs_all(::Type{ON_CELLS}, FEType::Type{<:HDIVRT1}, EG::Type{<:Tetrahedron3D}) = 4*nfaces_for_geometry(EG) + 3 # in 3D only 3 of 4 face dofs are used depending on orientation

get_polynomialorder(::Type{<:HDIVRT1{2}}, ::Type{<:AbstractElementGeometry1D}) = 1;
get_polynomialorder(::Type{<:HDIVRT1{3}}, ::Type{<:AbstractElementGeometry2D}) = 1;
get_polynomialorder(::Type{<:HDIVRT1{2}}, ::Type{<:AbstractElementGeometry2D}) = 2;
get_polynomialorder(::Type{<:HDIVRT1{3}}, ::Type{<:AbstractElementGeometry3D}) = 2;

get_dofmap_pattern(FEType::Type{<:HDIVRT1{2}}, ::Type{CellDofs}, EG::Type{<:Triangle2D}) = "f2i2"
get_dofmap_pattern(FEType::Type{<:HDIVRT1{2}}, ::Type{FaceDofs}, EG::Type{<:AbstractElementGeometry1D}) = "i2"
get_dofmap_pattern(FEType::Type{<:HDIVRT1{2}}, ::Type{BFaceDofs}, EG::Type{<:AbstractElementGeometry1D}) = "i2"

get_dofmap_pattern(FEType::Type{<:HDIVRT1{3}}, ::Type{CellDofs}, EG::Type{<:Tetrahedron3D}) = "f3i3"
get_dofmap_pattern(FEType::Type{<:HDIVRT1{3}}, ::Type{FaceDofs}, EG::Type{<:Triangle2D}) = "i3"
get_dofmap_pattern(FEType::Type{<:HDIVRT1{3}}, ::Type{BFaceDofs}, EG::Type{<:Triangle2D}) = "i3"

isdefined(FEType::Type{<:HDIVRT1}, ::Type{<:Triangle2D}) = true
isdefined(FEType::Type{<:HDIVRT1}, ::Type{<:Tetrahedron3D}) = true


function interpolate!(Target::AbstractArray{<:Real,1}, FE::FESpace{FEType}, ::Type{ON_FACES}, exact_function!; items = [], time = 0) where {FEType <: HDIVRT1}
    ncomponents = get_ncomponents(FEType)
    if items == []
        items = 1 : num_sources(FE.xgrid[FaceNodes])
    end

   # integrate normal flux of exact_function over edges
   xFaceNormals = FE.xgrid[FaceNormals]
   nfaces = num_sources(xFaceNormals)
   function normalflux_eval()
       temp = zeros(Float64,ncomponents)
       function closure(result, x, face)
            eval!(temp, exact_function!, x, time)
            result[1] = 0
            for j = 1 : ncomponents
               result[1] += temp[j] * xFaceNormals[j,face]
            end 
       end   
   end   
   edata_function = ExtendedDataFunction(normalflux_eval(), [1, ncomponents]; dependencies = "XI", quadorder = exact_function!.quadorder)
   integrate!(Target, FE.xgrid, ON_FACES, edata_function; items = items)
   
   # integrate first moment of normal flux of exact_function over edges
   function normalflux2_eval()
       temp = zeros(Float64,ncomponents)
       function closure(result, x, face, xref)
            eval!(temp, exact_function!, x, time)
            result[1] = 0.0
            for j = 1 : ncomponents
               result[1] += temp[j] * xFaceNormals[j,face]
            end
            result[1] *= (xref[1] - 1//ncomponents)
       end   
   end   
   edata_function2 = ExtendedDataFunction(normalflux2_eval(), [1, ncomponents]; dependencies = "XIL", quadorder = exact_function!.quadorder + 1)
   integrate!(Target, FE.xgrid, ON_FACES, edata_function2; items = items, index_offset = nfaces)

    if ncomponents == 3
        function normalflux3_eval()
            temp = zeros(Float64,ncomponents)
            function closure(result, x, face, xref)
                eval!(temp, exact_function!, x, time)
                result[1] = 0.0
                for j = 1 : ncomponents
                    result[1] += temp[j] * xFaceNormals[j,face]
                end
                result[1] *= (xref[2] - 1//ncomponents)
            end   
        end   
        edata_function3 = ExtendedDataFunction(normalflux3_eval(), [1, ncomponents]; dependencies = "XIL", quadorder = exact_function!.quadorder + 1)
        integrate!(Target, FE.xgrid, ON_FACES, edata_function3; items = items, time = time, index_offset = 2*nfaces)
    end
end

function interpolate!(Target::AbstractArray{<:Real,1}, FE::FESpace{FEType}, ::Type{ON_CELLS}, exact_function!; items = [], time = 0) where {FEType <: HDIVRT1}
    # delegate cell faces to face interpolation
    subitems = slice(FE.xgrid[CellFaces], items)
    interpolate!(Target, FE, ON_FACES, exact_function!; items = subitems)

    # set values of interior RT1 functions by integrating over cell
    # they are chosen such that integral mean of exact function is preserved on each cell
    ncomponents = get_ncomponents(FEType)
    ncells = num_sources(FE.xgrid[CellNodes])
    xCellVolumes = FE.xgrid[CellVolumes]
    xCellDofs = FE[CellDofs]
    means = zeros(Float64,ncomponents,ncells)
    integrate!(means, FE.xgrid, ON_CELLS, exact_function!)
    EG = (ncomponents == 2) ? Triangle2D : Tetrahedron3D
    qf = QuadratureRule{Float64,EG}(2)
    FEB = FEBasisEvaluator{Float64,eltype(FE),EG,Identity,ON_CELLS}(FE, qf)
    if items == []
        items = 1 : ncells
    end

    basisval = zeros(Float64,ncomponents)
    IMM = zeros(Float64,ncomponents,ncomponents)
    interiordofs = zeros(Int,ncomponents)
    interior_offset::Int = (ncomponents == 2) ? 6 : 12
    for cell in items
        update!(FEB,cell)
        # compute mean value of facial RT1 dofs
        for dof = 1 : interior_offset
            for i = 1 : length(qf.w)
                eval!(basisval,FEB, dof, i)
                for k = 1 : ncomponents
                    means[k,cell] -= basisval[k] * Target[xCellDofs[dof,cell]] * xCellVolumes[cell] * qf.w[i]
                end
            end
        end
        # compute mss matrix of interior dofs
        fill!(IMM,0)
        for dof = 1:ncomponents
            for i = 1 : length(qf.w)
                eval!(basisval,FEB, interior_offset + dof, i)
                for k = 1 : ncomponents
                    IMM[k,dof] += basisval[k] * xCellVolumes[cell] * qf.w[i]
                end
            end
            interiordofs[dof] = xCellDofs[interior_offset + dof,cell] 
        end
        Target[interiordofs] = IMM\means[:,cell]
    end
end


# only normalfluxes on faces
function get_basis(::Union{Type{<:ON_FACES}, Type{<:ON_BFACES}}, ::Type{<:HDIVRT1{2}}, ::Type{<:AbstractElementGeometry1D})
    function closure(refbasis,xref)
        refbasis[1,1] = 1                # normal-flux of RT0 function on single face
        refbasis[2,1] = 12*(xref[1]-1//2) # linear normal-flux of RT1 function
    end
end

# only normalfluxes on faces
function get_basis(::Union{Type{<:ON_FACES}, Type{<:ON_BFACES}}, ::Type{<:HDIVRT1{3}}, ::Type{<:Triangle2D})
    function closure(refbasis,xref)
        refbasis[1,1] = 1                # normal-flux of RT0 function on single face
        refbasis[2,1] = 12*(2*xref[1]+xref[2]-1) # 1st linear normal-flux RT1 function (normal flux weighted with (phi_1 - 1/3))
        refbasis[3,1] = 12*(2*xref[2]+xref[1]-1) # 2nd linear normal-flux RT1 function (normal flux weighted with (phi_2 - 1/3))
    end
end


function get_basis(::Type{ON_CELLS}, ::Type{HDIVRT1{2}}, ::Type{<:Triangle2D})
    function closure(refbasis,xref)
        temp = 1//2 - xref[1] - xref[2]
        # RT0 basis
        refbasis[1,:] .= [xref[1], xref[2]-1];
        refbasis[3,:] .= [xref[1], xref[2]];
        refbasis[5,:] .= [xref[1]-1, xref[2]];
        # additional RT1 face basis functions
        refbasis[2,:] .= -12*temp .* refbasis[1,:];
        refbasis[4,:] .= -(12*(xref[1] - 1//2)) .* refbasis[3,:];
        refbasis[6,:] .= -(12*(xref[2] - 1//2)) .* refbasis[5,:];
        # interior functions
        refbasis[7,:] .= 12*xref[2] .* refbasis[1,:];
        refbasis[8,:] .= 12*xref[1] .* refbasis[5,:];
    end
end

function get_basis(::Type{ON_CELLS}, ::Type{HDIVRT1{3}}, ::Type{<:Tetrahedron3D})
    function closure(refbasis,xref)
        temp = 1 - xref[1] - xref[2] - xref[3]
        # RT0 basis
        refbasis[1,:] .= 2*[xref[1], xref[2], xref[3]-1]
        refbasis[5,:] .= 2*[xref[1], xref[2]-1, xref[3]]
        refbasis[9,:] .= 2*[xref[1], xref[2], xref[3]]
        refbasis[13,:] .= 2*[xref[1]-1, xref[2], xref[3]]

        # additional RT1 face basis functions (2 per face)       # Test with (phi_1-1/3,phi_3-1/3,phi_2-1/3)
        refbasis[2,:] .= -12*(2*temp+xref[2]-1) .* refbasis[1,:]; # [1,0,-1]
        refbasis[3,:] .= -12*(2*xref[2]+xref[1]-1) .* refbasis[1,:]; # [-1,1,0]
        refbasis[4,:] .= 12*(2*xref[2]+temp-1) .* refbasis[1,:]; # [0,-1,1]

        refbasis[6,:] .= -12*(2*temp+xref[1]-1)  .* refbasis[5,:];
        refbasis[7,:] .= -12*(2*xref[1]+xref[3]-1) .* refbasis[5,:];
        refbasis[8,:] .= 12*(2*xref[1]+temp-1) .* refbasis[5,:];

        refbasis[10,:] .= -12*(2*xref[1]+xref[2]-1)  .* refbasis[9,:];
        refbasis[11,:] .= -12*(2*xref[2]+xref[3]-1)  .* refbasis[9,:];
        refbasis[12,:] .= 12*(2*xref[2]+xref[1]-1)  .* refbasis[9,:];

        refbasis[14,:] .= -12*(2*temp+xref[3]-1) .* refbasis[13,:];
        refbasis[15,:] .= -12*(2*xref[3]+xref[2]-1) .* refbasis[13,:];
        refbasis[16,:] .= 12*(2*xref[3]+temp-1) .* refbasis[13,:];

        # interior functions
        refbasis[17,:] .= 12*xref[3] .* refbasis[1,:];
        refbasis[18,:] .= 12*xref[2] .* refbasis[5,:];
        refbasis[19,:] .= 12*xref[1] .* refbasis[13,:];
    end
end

function get_coefficients(::Type{ON_CELLS}, FE::FESpace{<:HDIVRT1{2}}, EG::Type{<:Triangle2D})
    xCellFaceSigns = FE.xgrid[CellFaceSigns]
    nfaces = nfaces_for_geometry(EG)
    function closure(coefficients, cell)
        fill!(coefficients,1.0)
        # multiplication with normal vector signs (only RT0)
        for j = 1 : nfaces,  k = 1 : size(coefficients,1)
            coefficients[k,2*j-1] = xCellFaceSigns[j,cell];
        end
        return nothing
    end
end    

function get_coefficients(::Type{ON_CELLS}, FE::FESpace{<:HDIVRT1{3}}, EG::Type{<:Tetrahedron3D})
    xCellFaceSigns = FE.xgrid[CellFaceSigns]
    nfaces = nfaces_for_geometry(EG)
    function closure(coefficients, cell)
        fill!(coefficients,1.0)
        # multiplication with normal vector signs (only RT0)
        for j = 1 : nfaces,  k = 1 : size(coefficients,1)
            coefficients[k,3*j-2] = xCellFaceSigns[j,cell]; # RT0
            coefficients[k,3*j-1] = -1;
            coefficients[k,3*j] = 1;
        end
       # @show coefficients
        return nothing
    end
end    


# subset selector ensures that for every cell face
# the RT0 and those two BDM1 face functions are chosen
# such that they reflect the two moments with respect to the second and third node
# of the global face enumeration
function get_basissubset(::Type{ON_CELLS}, FE::FESpace{<:HDIVRT1{3}}, EG::Type{<:Tetrahedron3D})
    xCellFaceOrientations = FE.xgrid[CellFaceOrientations]
    nfaces::Int = nfaces_for_geometry(EG)
    orientation = xCellFaceOrientations[1,1]
    shift4orientation1::Array{Int,1} = [1,0,1,2]
    shift4orientation2::Array{Int,1} = [2,2,0,1]
    function closure(subset_ids, cell)
        for j = 1 : nfaces
            subset_ids[3*j-2] = 4*j-3; # always take the RT0 function
            orientation = xCellFaceOrientations[j,cell]
            subset_ids[3*j-1] = 4*j-shift4orientation1[orientation]
            subset_ids[3*j  ] = 4*j-shift4orientation2[orientation]
        end
        for j = 1 : 3
            subset_ids[12+j] = 16 + j # interior functions
        end
       # @show subset_ids
        return nothing
    end
end  
 