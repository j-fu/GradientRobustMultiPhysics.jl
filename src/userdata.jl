abstract type AbstractUserDataType end
abstract type AbstractDataFunction <: AbstractUserDataType end
abstract type AbstractExtendedDataFunction <: AbstractDataFunction end
abstract type AbstractActionKernel <: AbstractUserDataType end
abstract type AbstractNLActionKernel <: AbstractActionKernel end

struct UserData{UST<: AbstractUserDataType,FType,NFType,ndim}
    name::String                      # some name used in info messages etc.
    dependencies::String              # substring of "XTRIL" that masks the dependencies of the user function
    quadorder::Int                    # quadrature order that should be used to evaluate the function (is added to quadrature order of related actions)
    dimensions::SVector{ndim,Int}     # length of result and input arrays
    user_function::FType              # original function by user
    negotiated_function::NFType       # negotiated function (with possibly more XTRIL input arguments to match general interfaces)
end

"""
````
function ActionKernel(
    f::Function,                    # user function with interface f(result, _other dependencies_)
    dimensions::Array{Int,1};       # [length(result), length(input)]
    name = "user action kernel",
    dependencies::String = "",      # substring of "XTRIL" encoding other dependencies in f interface
    quadorder::Int = 0)             # quadrature order added to actions/operators that evaluate this action kernel
````

Provides a negotation interface for some function that can be used in the Action constructor to define a user-defined operator action.
The function has to obey the interface

    f(result, input, [X, T, R, I, L])

where the parameters X (= space coordinates), T ( = time), R (= region number), I (= item number), L (= local coordinates) are optional.
Which of them are used has to be specified in the String dependencies.

The input vector usually provides the FunctionOperator evaluations of (a subset of) the ansatz arguments of the assembly pattern where the action is used.
The array dimensions specifies the expected length of result and input and quadorder determines the additional quadrature order to be used if this
function (or its derived action) is involved in an assembly process.
"""
function ActionKernel(f, dimensions::Array{Int,1}; name = "user action kernel", dependencies::String = "", quadorder::Int = 0)

    nf = (result, input,X,T,R,I,L) -> f(result, input) # no other dependencies
    if dependencies == "X"
        nf = (result, input,X,T,R,I,L) -> f(result, input, X)
    elseif dependencies == "T"
        nf = (result, input,X,T,R,I,L) -> f(result, input, T)
    elseif dependencies == "R"
        nf = (result, input,X,T,R,I,L) -> f(result, input, R)
    elseif dependencies == "I"
        nf = (result, input,X,T,R,I,L) -> f(result, input, I)
    elseif dependencies == "L"
        nf = (result, input,X,T,R,I,L) -> f(result, input, L)
    elseif dependencies == "XR"
        nf = (result, input,X,T,R,I,L) -> f(result, input, X, R)
    elseif dependencies == "XT"
        nf = (result, input,X,T,R,I,L) -> f(result, input, X, T)
    elseif dependencies == "XI"
        nf = (result, input,X,T,R,I,L) -> f(result, input, X, I)
    elseif dependencies == "XL"
        nf = (result, input,X,T,R,I,L) -> f(result, input, X, L)
    elseif dependencies == "TI"
        nf = (result, input,X,T,R,I,L) -> f(result, input, T, I)
    elseif dependencies == "RI"
        nf = (result, input,X,T,R,I,L) -> f(result, input, R, I)
    elseif dependencies == "XTR"
        nf = (result, input,X,T,R,I,L) -> f(result, input, X, T, R)
    elseif dependencies == "XTI"
        nf = (result, input,X,T,R,I,L) -> f(result, input, X, T, I)
    elseif dependencies == "XTL"
        nf = (result, input,X,T,R,I,L) -> f(result, input, X, T, L)
    elseif dependencies == "XRI"
        nf = (result, input,X,T,R,I,L) -> f(result, input, X, R, I)
    elseif dependencies == "XTRI"
        nf = (result, input,X,T,R,I,L) -> f(result, input, X, T, R, I)
    elseif dependencies == "XRIL"
        nf = (result, input,X,T,R,I,L) -> f(result, input, X, R, I, L)
    elseif dependencies == "XTRIL"
        nf = (result, input,X,T,R,I,L) -> f(result, input, X, T, R, I, L)
    end

    return UserData{AbstractActionKernel,typeof(f),typeof(nf),length(dimensions)}(name, dependencies, quadorder, dimensions, f, nf)
end



"""
````
function NLActionKernel(
    f::Function,
    dimensions::Array{Int,1};
    name = "nonlinear user action kernel",
    dependencies::String = "",
    quadorder::Int = 0)
````

Provides a negotation interface for some function to be used as a nonlinear action kernel that can be used in the
NonlinearOperator constructor without automatic differentiation. The function f has to obey the interface

    f(result, input_current, input_ansatz)

and can be seen as a linearisation of a nonlinearity that can depend on the operator evaluation of the current iterate (input_current)
and, as usual, the operator evaluations of the ansatz function (input_ansatz).

No further dependencies are allowed currently. Note, that this is a work-in-progress feature.
"""
function NLActionKernel(f::Function, dimensions::Array{Int,1}; name = "user nonlinear action kernel", dependencies::String = "", quadorder::Int = 0)
    if length(dimensions) == 2
        push!(dimensions,dimensions[2])
    end
    if dependencies == "X"
        nf = (result, input_current, input_ansatz, X,T,R,I,L) -> f(result, input_current, input_ansatz, X)
    elseif dependencies == "T"
        nf = (result, input_current, input_ansatz, X,T,R,I,L) -> f(result, input_current, input_ansatz, T)
    elseif dependencies == "XT"
        nf = (result, input_current, input_ansatz, X,T,R,I,L) -> f(result, input_current, input_ansatz, X, T)
    elseif dependencies == ""
        nf = (result, input_current, input_ansatz, X,T,R,I,L) -> f(result, input_current, input_ansatz) # no other dependencies
    else
        @error "nonlinear action kernels with dependencies = $dependencies currently not supported"
    end

    return UserData{AbstractNLActionKernel,typeof(f),typeof(nf),length(dimensions)}(name, dependencies, quadorder, dimensions, f, nf)
end


"""
````
function DataFunction(
    f::Function,                    # user function with interface f(result, _other dependencies_)
    dimensions::Array{Int,1};       # [length(result), length(x)]
    name = "user data function",
    dependencies::String = "",      # substring of "XT" encoding other dependencies in f interface
    quadorder::Int = 0)             # quadrature order added to operator's quadorder that evalute f
````

Provides a negotation interface for some user-defined function that 
can be used in integrate! and boundary or right-hand side data assignments.
The function f has to obey the interface

    f(result, [X, T])

where the parameters X (= space coordinates) and T ( = time) are optional. Which of them are used has to be specified in the 
String dependencies. The array dimensions specifies the expected length of result and input and quadorder determines the additional quadrature order to be used if this
function is involved in some quadrature-requireing procedure.
"""
function DataFunction(f::Function, dimensions::Array{Int,1}; name = "user data function", dependencies::String = "", quadorder::Int = 0)
    nf = (result,X,T) -> f(result) # no other dependencies
    if dependencies == "X"
        nf = (result,X,T) -> f(result, X)
    elseif dependencies == "T"
        nf = (result,X,T) -> f(result, T)
    elseif dependencies == "XT"
        nf = (result,X,T) -> f(result, X, T)
    end

    return UserData{AbstractDataFunction,typeof(f),typeof(nf),length(dimensions)}(name, dependencies, quadorder, dimensions, f, nf)
end


"""
````
function DataFunction(c::Array{<:Real,1}; name = "constant user data", quadorder::Int = 0)
````

Directly generates a DataFunction from a given array c, i.e. a DataFunction that is constant and has no dependencies on x or t.
"""
function DataFunction(c::Array{<:Real,1}; name = "auto", quadorder::Int = 0)
    dimensions = [length(c),0]
    function f_from_c(result)
        result .= c
    end
    if name == "auto"
        name = "Constant($c)"
    end

    return DataFunction(f_from_c, dimensions; name = name, dependencies = "", quadorder = quadorder)
end

"""
````
function ExtendedDataFunction(
    f::Function,                    # user function with interface f(result, _other dependencies_)
    dimensions::Array{Int,1};       # [length(result), length(x)]
    name = "user data function",
    dependencies::String = "",      # substring of "XTRIL" encoding other dependencies in f interface
    quadorder::Int = 0)             # quadrature order added to operator's quadorder that evalute f
````

Provides a negotation interface for some data function with extended dependencies
(region number, item number and local coordinates) that can be used in integrate!.
The function f has to obey the interface

    f(result, [X, T, R, I, L])

where the parameters X (= space coordinates) and T ( = time) are optional. Which of them are used has to be specified in the 
String dependencies. The array dimensions specifies the expected length of result and X (if X-depdendent, otherwise will be ignored)
and quadorder determines the additional quadrature order to be used if this function is involved in some quadrature-requireing procedure.
"""
function ExtendedDataFunction(f::Function, dimensions::Array{Int,1}; name = "user data function", dependencies::String = "", quadorder::Int = 0)

    if dependencies == "X"
        nf = (result,X,T,R,I,L) -> f(result, X)
    elseif dependencies == "T"
        nf = (result,X,T,R,I,L) -> f(result, T)
    elseif dependencies == "R"
        nf = (result,X,T,R,I,L) -> f(result, R)
    elseif dependencies == "I"
        nf = (result,X,T,R,I,L) -> f(result, I)
    elseif dependencies == "L"
        nf = (result,X,T,R,I,L) -> f(result, L)
    elseif dependencies == "XR"
        nf = (result,X,T,R,I,L) -> f(result, X, R)
    elseif dependencies == "XT"
        nf = (result,X,T,R,I,L) -> f(result, X, T)
    elseif dependencies == "XI"
        nf = (result,X,T,R,I,L) -> f(result, X, I)
    elseif dependencies == "XL"
        nf = (result,X,T,R,I,L) -> f(result, X, L)
    elseif dependencies == "RI"
        nf = (result,X,T,R,I,L) -> f(result, R, I)
    elseif dependencies == "XTR"
        nf = (result,X,T,R,I,L) -> f(result, X, T, R)
    elseif dependencies == "XTI"
        nf = (result,X,T,R,I,L) -> f(result, X, T, I)
    elseif dependencies == "XTL"
        nf = (result,X,T,R,I,L) -> f(result, X, T, L)
    elseif dependencies == "XRI"
        nf = (result,X,T,R,I,L) -> f(result, X, R, I)
    elseif dependencies == "XIL"
        nf = (result,X,T,R,I,L) -> f(result, X, I, L)
    elseif dependencies == "XTRIL"
        nf = (result,X,T,R,I,L) -> f(result, X, T, R, I, L)
    else
        nf = (result,X,T,R,I,L) -> f(result) # no other dependencies
    end

    return UserData{AbstractExtendedDataFunction,typeof(f),typeof(nf),length(dimensions)}(name, dependencies, quadorder, dimensions, f, nf)
end

"""
````
function ∇(UD::UserData{AbstractDataFunction}; quadorder = UD.quadorder - 1)
````

Provides a DataFunction with the same dependencies that evaluates the gradient of the DataFunction UD. The derivatives are computed by ForwardDiff.
"""
function ∇(UD::UserData{AbstractDataFunction}; quadorder = UD.quadorder - 1)
    argsizes = UD.dimensions
    result_temp::Array{Float64,1} = Vector{Float64}(undef,argsizes[1])
    input_temp::Array{Float64,1} = Vector{Float64}(undef,argsizes[2])
    Dresult = DiffResults.JacobianResult(result_temp,input_temp)
    jac::Array{Float64,2} = DiffResults.jacobian(Dresult)
    if UD.dependencies == "X"
        cfg = ForwardDiff.JacobianConfig(UD.user_function, result_temp, input_temp)
        function data_deriv_x(result, x)
            ForwardDiff.vector_mode_jacobian!(Dresult, UD.user_function, result_temp, x, cfg)
            for j = 1 : argsizes[1], k = 1 : argsizes[2]
                result[(j-1)*argsizes[2] + k] = jac[j,k]
            end
            return nothing
        end
        return DataFunction(data_deriv_x, [argsizes[1]*argsizes[2], argsizes[2]]; name = "∇($(UD.name))", dependencies = "X", quadorder = quadorder)
    elseif UD.dependencies == "XT"
        reduced_function_xt(t) = (result,x) -> UD.user_function(result,x,t)
        cfg = ForwardDiff.JacobianConfig(reduced_function_xt(0.0), result_temp, input_temp)
        function data_deriv_xt(result, x, t)
            ForwardDiff.vector_mode_jacobian!(Dresult, reduced_function_xt(t), result_temp, x, cfg)
            for j = 1 : argsizes[1], k = 1 : argsizes[2]
                result[(j-1)*argsizes[2] + k] = jac[j,k]
            end
            return nothing
        end
        return DataFunction(data_deriv_xt, [argsizes[1]*argsizes[2], argsizes[2]]; name = "∇($(UD.name))", dependencies = "XT", quadorder = quadorder)
    elseif UD.dependencies == "" || UD.dependencies == "T"
        return DataFunction(zeros(Float64, argsizes[1]*argsizes[2]); name = "∇($(UD.name))")
    else
        @error "derivatives of user functions with these dependencies not implemented yet"
    end
end

function curl3D(UD::UserData{AbstractDataFunction}; quadorder = UD.quadorder - 1)
    argsizes = UD.dimensions
    @assert argsizes[1] == 3 && argsizes[2] == 3 "curl3D needs dimensions [3,3]"
    result_temp::Array{Float64,1} = Vector{Float64}(undef,argsizes[1])
    input_temp::Array{Float64,1} = Vector{Float64}(undef,argsizes[2])
    Dresult = DiffResults.JacobianResult(result_temp,input_temp)
    jac::Array{Float64,2} = DiffResults.jacobian(Dresult)
    if UD.dependencies == "X"
        cfg = ForwardDiff.JacobianConfig(UD.user_function, result_temp, input_temp)
        function data_deriv_x(result, x)
            ForwardDiff.vector_mode_jacobian!(Dresult, UD.user_function, result_temp, x, cfg)
            result[1] = jac[3,2] - jac[2,3]
            result[2] = jac[1,3] - jac[3,1]
            result[3] = jac[2,1] - jac[1,2]
            return nothing
        end
        return DataFunction(data_deriv_x, [1, 2]; name = "curl($(UD.name))", dependencies = "X", quadorder = quadorder)
    elseif UD.dependencies == "XT"
        reduced_function_xt(t) = (result,x) -> UD.user_function(result,x,t)
        cfg = ForwardDiff.JacobianConfig(reduced_function_xt(0.0), result_temp, input_temp)
        function data_deriv_xt(result, x, t)
            ForwardDiff.vector_mode_jacobian!(Dresult, reduced_function_xt(t), result_temp, x, cfg)
            result[1] = jac[3,2] - jac[2,3]
            result[2] = jac[1,3] - jac[3,1]
            result[3] = jac[2,1] - jac[1,2]
            return nothing
        end
        return DataFunction(data_deriv_xt, [1,2]; name = "curl($(UD.name))", dependencies = "XT", quadorder = quadorder)
    elseif UD.dependencies == "" || UD.dependencies == "T"
        return DataFunction(zeros(Float64, 1); name = "curl($(UD.name))")
    else
        @error "derivatives of user functions with these dependencies not implemented yet"
    end
end

function curl2D(UD::UserData{AbstractDataFunction}; quadorder = UD.quadorder - 1)
    argsizes = UD.dimensions
    @assert argsizes[1] == 2 && argsizes[2] == 2 "curl2D needs dimensions [2,2]"
    result_temp::Array{Float64,1} = Vector{Float64}(undef,argsizes[1])
    input_temp::Array{Float64,1} = Vector{Float64}(undef,argsizes[2])
    Dresult = DiffResults.JacobianResult(result_temp,input_temp)
    jac::Array{Float64,2} = DiffResults.jacobian(Dresult)
    if UD.dependencies == "X"
        cfg = ForwardDiff.JacobianConfig(UD.user_function, result_temp, input_temp)
        function data_deriv_x(result, x)
            ForwardDiff.vector_mode_jacobian!(Dresult, UD.user_function, result_temp, x, cfg)
            result[1] = jac[1,2] - jac[2,1]
            return nothing
        end
        return DataFunction(data_deriv_x, [1, 2]; name = "curl($(UD.name))", dependencies = "X", quadorder = quadorder)
    elseif UD.dependencies == "XT"
        reduced_function_xt(t) = (result,x) -> UD.user_function(result,x,t)
        cfg = ForwardDiff.JacobianConfig(reduced_function_xt(0.0), result_temp, input_temp)
        function data_deriv_xt(result, x, t)
            ForwardDiff.vector_mode_jacobian!(Dresult, reduced_function_xt(t), result_temp, x, cfg)
            result[1] = jac[1,2] - jac[2,1]
            return nothing
        end
        return DataFunction(data_deriv_xt, [1,2]; name = "curl($(UD.name))", dependencies = "XT", quadorder = quadorder)
    elseif UD.dependencies == "" || UD.dependencies == "T"
        return DataFunction(zeros(Float64, 1); name = "curl($(UD.name))")
    else
        @error "derivatives of user functions with these dependencies not implemented yet"
    end
end


function curl_scalar(UD::UserData{AbstractDataFunction}; quadorder = UD.quadorder - 1)
    argsizes = UD.dimensions
    @assert argsizes[1] == 1 && argsizes[2] == 2 "curl_scalar needs dimensions [1,2]"
    result_temp::Array{Float64,1} = Vector{Float64}(undef,argsizes[1])
    input_temp::Array{Float64,1} = Vector{Float64}(undef,argsizes[2])
    Dresult = DiffResults.JacobianResult(result_temp,input_temp)
    jac::Array{Float64,2} = DiffResults.jacobian(Dresult)
    if UD.dependencies == "X"
        cfg = ForwardDiff.JacobianConfig(UD.user_function, result_temp, input_temp)
        function data_deriv_x(result, x)
            ForwardDiff.vector_mode_jacobian!(Dresult, UD.user_function, result_temp, x, cfg)
            result[1] = -jac[1,2]
            result[2] = jac[1,1]
            return nothing
        end
        return DataFunction(data_deriv_x, [2, 2]; name = "curl($(UD.name))", dependencies = "X", quadorder = quadorder)
    elseif UD.dependencies == "XT"
        reduced_function_xt(t) = (result,x) -> UD.user_function(result,x,t)
        cfg = ForwardDiff.JacobianConfig(reduced_function_xt(0.0), result_temp, input_temp)
        function data_deriv_xt(result, x, t)
            ForwardDiff.vector_mode_jacobian!(Dresult, reduced_function_xt(t), result_temp, x, cfg)
            result[1] = -jac[1,2]
            result[2] = jac[1,1]
            return nothing
        end
        return DataFunction(data_deriv_xt, [2,2]; name = "curl($(UD.name))", dependencies = "XT", quadorder = quadorder)
    elseif UD.dependencies == "" || UD.dependencies == "T"
        return DataFunction(zeros(Float64, 2); name = "curl($(UD.name))")
    else
        @error "derivatives of user functions with these dependencies not implemented yet"
    end
end

"""
````
function curl(UD::UserData{AbstractDataFunction}; quadorder = UD.quadorder - 1)
````

Provides a DataFunction with the same dependencies that evaluates the curl of the DataFunction UD. The derivatives are computed by ForwardDiff.
Depending on the dimensions of UD, either CurlScalar (UD.dimensions == [1,2]), Curl2D (UD.dimensions == [2,2]) or Curl3D (UD.dimensions == [3,3])
is generated.
"""
function curl(UD::UserData{AbstractDataFunction}; quadorder = UD.quadorder - 1)
    argsizes = UD.dimensions
    if argsizes[1] == 1 # 2D curl of scalar-function curl(f: R^2 --> R^1) : R^2 --> R^2 = [-df/dy, df/dx]
        curl_scalar(UD; quadorder = quadorder)
    elseif argsizes[1] == 2 # 2D curl of vector-valued function curl(f: R^2 --> R^2) : R^2 --> R^1 = -df1/dy + df2/dx
        curl2D(UD; quadorder = quadorder)
    elseif argsizes[1] == 3 # 3D curl of vector-valued function curl(f: R^3 --> R^3) : R^2 --> R^1 = ∇ × f
        curl3D(UD; quadorder = quadorder)
    else
        @error "curl for these function dimensions not known/implemented"
    end
end

"""
````
function div(UD::UserData{AbstractDataFunction}; quadorder = UD.quadorder - 1)
````

Provides a DataFunction with the same dependencies that evaluates the divergence of the DataFunction UD. The derivatives are computed by ForwardDiff.
"""
function Base.div(UD::UserData{AbstractDataFunction}; quadorder = UD.quadorder - 1)
    argsizes = UD.dimensions
    @assert argsizes[1] == argsizes[2] "div needs equal dimensions"
    result_temp::Array{Float64,1} = Vector{Float64}(undef,argsizes[1])
    input_temp::Array{Float64,1} = Vector{Float64}(undef,argsizes[2])
    Dresult = DiffResults.JacobianResult(result_temp,input_temp)
    jac::Array{Float64,2} = DiffResults.jacobian(Dresult)
    if UD.dependencies == "X"
        cfg = ForwardDiff.JacobianConfig(UD.user_function, result_temp, input_temp)
        function data_deriv_x(result, x)
            ForwardDiff.vector_mode_jacobian!(Dresult, UD.user_function, result_temp, x, cfg)
            result[1] = 0
            for j = 1 : argsizes[2]
                result[1] += jac[j,j]
            end
            return nothing
        end
        return DataFunction(data_deriv_x, [1, argsizes[2]]; name = "div($(UD.name))", dependencies = "X", quadorder = quadorder)
    elseif UD.dependencies == "XT"
        reduced_function_xt(t) = (result,x) -> UD.user_function(result,x,t)
        cfg = ForwardDiff.JacobianConfig(reduced_function_xt(0.0), result_temp, input_temp)
        function data_deriv_xt(result, x, t)
            ForwardDiff.vector_mode_jacobian!(Dresult, reduced_function_xt(t), result_temp, x, cfg)
            result[1] = 0
            for j = 1 : argsizes[2]
                result[1] += jac[j,j]
            end
            return nothing
        end
        return DataFunction(data_deriv_xt, [1, argsizes[2]]; name = "div($(UD.name))", dependencies = "XT", quadorder = quadorder)
    elseif UD.dependencies == "" || UD.dependencies == "T"
        return DataFunction(zeros(Float64, 1); name = "div($(UD.name))")
    else
        @error "derivatives of user functions with these dependencies not implemented yet"
    end
end

@inline function eval_data!(result, UD::UserData{AbstractActionKernel}, input, X, T, R, I, L)
    UD.negotiated_function(result, input, X, T, R, I, L)
end

@inline function eval_data!(result, UD::UserData{AbstractNLActionKernel}, input, input2, X, T, R, I, L)
    UD.negotiated_function(result, input, input2, X, T, R, I, L)
end

@inline function eval_data!(result, UD::UserData{AbstractExtendedDataFunction}, X, T, R, I, L)
    UD.negotiated_function(result, X, T, R, I, L)
end

@inline function eval_data!(result, UD::UserData{AbstractDataFunction}, X, T)
    UD.negotiated_function(result, X, T)
end

@inline function eval_data!(result, UD::UserData{AbstractDataFunction})
    UD.negotiated_function(result, nothing, nothing)
end

@inline function eval_data!(result, UD::UserData{AbstractDataFunction}, X, T, R, I, L)
    UD.negotiated_function(result, X, T)
end

@inline function is_xdependent(UD::UserData)
    return occursin("X", UD.dependencies)
end

@inline function is_timedependent(UD::UserData)
    return occursin("T", UD.dependencies)
end

@inline function is_itemdependent(UD::UserData)
    return occursin("I", UD.dependencies)
end

@inline function is_regiondependent(UD::UserData)
    return occursin("R", UD.dependencies)
end

@inline function is_ldependent(UD::UserData)
    return occursin("L", UD.dependencies)
end


"""
````
function nodevalues(nodevals, xgrid::ExtendableGrid{Tv,Ti}, UD::UserData; time = 0) where {Tv,Ti}
````

Returns a 2D array with the node values of the data function for the given grid.
"""
function nodevalues(xgrid::ExtendableGrid{Tv,Ti}, UD::UserData; T = Float64, time = 0) where {Tv,Ti}
    xCoordinates::Array{Tv,2} = xgrid[Coordinates]
    nnodes::Int = size(xCoordinates,2)

    if is_xdependent(UD)
        @assert UD.dimensions[2] == size(xCoordinates,1) "UserData input dimension expected to match dimension of coordinates of grid"
    end

    result = zeros(T,UD.dimensions[1])
    nodevals = zeros(T,UD.dimensions[1],nnodes)
    for j = 1 : nnodes
        eval_data!(result,UD,view(xCoordinates,:,j),time)
        for k = 1 : UD.dimensions[1]
            nodevals[k,j] = result[k]
        end
    end
    return nodevals
end


###########################################
## STUFF USED BY NONLINEAR FORM ASSEMBLY ##
###########################################


abstract type AbstractNonlinearFormHandler end

mutable struct OperatorWithUserJacobian{T,dx,dt,dr,ndim,OType,JType} <: AbstractNonlinearFormHandler
    operator::OType
    jacobian::JType
    argsizes::SVector{ndim,Int}
    x::Vector{T}
    region::Int
    item::Int
    time::T
    bonus_quadorder::Int
    jac::Array{T,2}
    val::Array{T,1}
end

function OperatorWithUserJacobian(o, j, argsizes; dependencies = "", quadorder = 0, sparse_jacobian::Bool = false)
    dx = dependencies in ["X","XT","XR","XTR"]
    dt = dependencies in ["T","XT","TR","XTR"]
    dr = dependencies in ["R","XR","TR","XTR"]
    if sparse_jacobian
        result_temp::Array{Float64,1} = Vector{Float64}(undef,argsizes[1])
        input_temp::Array{Float64,1} = Vector{Float64}(undef,argsizes[3])

        if dependencies == "X" # x-dependent
            o_x(x) = (result,input) -> o(result,input,x)
            config_eval = o_x([1.0,1.0,1.0])
        elseif dependencies == "T" # time-dependent
            o_t(t) = (result,input) -> o(result,input,t)
            config_eval = o_t(0.0)
        elseif dependencies == "R" # region-dependent
            o_r(r) = (result,input) -> o(result,input,r)
            config_eval = o_r(0)
        elseif dependencies == "XT" # xt-dependent
            o_xt(x,t) = (result,input) -> o(result,input,x,t)
            config_eval = o_xt([1.0,1.0,1.0],0.0)
        elseif dependencies == "XR" # xr-dependent
            o_xr(x,r) = (result,input) -> o(result,input,x,r)
            config_eval = o_xr([1.0,1.0,1.0],0)
        elseif dependencies == "TR" # tr-dependent
            o_tr(t,r) = (result,input) -> o(result,input,t,r)
            config_eval = o_tr(0.0,0)
        elseif dependencies == "XTR" # xtr-dependent
            o_xtr(x,t,r) = (result,input) -> o(result,input,x,t,r)
            config_eval = o_xtr([1.0,1.0,1.0],0.0,0)
        else
            config_eval = o
        end
        sparsity_pattern = jacobian_sparsity(config_eval,result_temp,input_temp)
        jac = Float64.(sparse(sparsity_pattern))
    else
        jac = zeros(Float64,argsizes[1],argsizes[2])
    end
    return OperatorWithUserJacobian{Float64,dx,dt,dr,length(argsizes),typeof(o),typeof(j)}(o,j,argsizes,zeros(Float64,3),0,0,0.0,quadorder,jac,zeros(Float64,argsizes[1]))
end

set_region!(J::OperatorWithUserJacobian, region) = (J.region = region)
set_time!(J::OperatorWithUserJacobian, time) = (J.time = time)
is_xdependent(J::OperatorWithUserJacobian{T,dx,dt,dr,ndim}) where {T,dx,dt,dr,ndim} = dx
is_timedependent(J::OperatorWithUserJacobian{T,dx,dt,dr,ndim}) where {T,dx,dt,dr,ndim} = dt
is_regiondependent(J::OperatorWithUserJacobian{T,dx,dt,dr,ndim}) where {T,dx,dt,dr,ndim} = dr

function eval_jacobian!(J::OperatorWithUserJacobian{T,false,false,false}, input_current) where {T}
    J.jacobian(J.jac, input_current)
    J.operator(J.val, input_current)
    return nothing
end
function eval_jacobian!(J::OperatorWithUserJacobian{T,true,false,false}, input_current, x) where {T}
    J.jacobian(J.jac, input_current, x)
    J.operator(J.val, input_current, x)
    return nothing
end
function eval_jacobian!(J::OperatorWithUserJacobian{T,true,false,true}, input_current, x) where {T}
    J.jacobian(J.jac, input_current, x, C.region)
    J.operator(J.val, input_current, x, C.region)
    return nothing
end
function eval_jacobian!(J::OperatorWithUserJacobian{T,false,true,false}, input_current) where {T}
    J.jacobian(J.jac, input_current, C.time)
    J.operator(J.val, input_current, C.time)
    return nothing
end
function eval_jacobian!(J::OperatorWithUserJacobian{T,false,true,true}, input_current) where {T}
    J.jacobian(J.jac, input_current, C.time, C.region)
    J.operator(J.val, input_current, C.time, C.region)
    return nothing
end
function eval_jacobian!(J::OperatorWithUserJacobian{T,false,false,true}, input_current) where {T}
    J.jacobian(J.jac, input_current, C.region)
    J.operator(J.val, input_current, C.region)
    return nothing
end
function eval_jacobian!(J::OperatorWithUserJacobian{T,true,true,true}, input_current, x) where {T}
    J.jacobian(J.jac, input_current, x, C.time, C.region)
    J.operator(J.val, input_current, x, C.time, C.region)
    return nothing
end


mutable struct OperatorWithADJacobian{T,dx,dt,dr,sparse,ndim,OType,JType,JacType} <: AbstractNonlinearFormHandler
    operator::OType
    jacobian::JType
    argsizes::SVector{ndim,Int}
    x::Vector{T}
    region::Int
    item::Int
    time::T
    bonus_quadorder::Int # modifies the number generated from operators and FEspaces of NonlinearForm
    Dresult::DiffResults.DiffResult
    cfg::Union{ForwardDiff.JacobianConfig,SparseDiffTools.ForwardColorJacCache}
    jac::JacType
    val::Array{T,1}
end

function OperatorWithADJacobian(o, argsizes; dependencies = "", quadorder = 0, sparse_jacobian::Bool = false)
    result_temp::Array{Float64,1} = Vector{Float64}(undef,argsizes[1])
    input_temp::Array{Float64,1} = Vector{Float64}(undef,argsizes[3])

    dx = dependencies in ["X","XT","XR","XTR"]
    dt = dependencies in ["T","XT","TR","XTR"]
    dr = dependencies in ["R","XR","TR","XTR"]

    if dependencies == "X" # x-dependent
        o_x(x) = (result,input) -> o(result,input,x)
        config_eval = o_x([1.0,1.0,1.0])
        negotiated_o = o_x
    elseif dependencies == "T" # time-dependent
        o_t(t) = (result,input) -> o(result,input,t)
        config_eval = o_t(0.0)
        negotiated_o = o_t
    elseif dependencies == "R" # region-dependent
        o_r(r) = (result,input) -> o(result,input,r)
        config_eval = o_r(0)
        negotiated_o = o_r
    elseif dependencies == "XT" # xt-dependent
        o_xt(x,t) = (result,input) -> o(result,input,x,t)
        config_eval = o_xt([1.0,1.0,1.0],0.0)
        negotiated_o = o_xt
    elseif dependencies == "XR" # xr-dependent
        o_xr(x,r) = (result,input) -> o(result,input,x,r)
        config_eval = o_xr([1.0,1.0,1.0],0)
        negotiated_o = o_xr
    elseif dependencies == "TR" # tr-dependent
        o_tr(t,r) = (result,input) -> o(result,input,t,r)
        config_eval = o_tr(0.0,0)
        negotiated_o = o_tr
    elseif dependencies == "XTR" # xtr-dependent
        o_xtr(x,t,r) = (result,input) -> o(result,input,x,t,r)
        config_eval = o_xtr([1.0,1.0,1.0],0.0,0)
        negotiated_o = o_xtr
    else
        negotiated_o = o
        config_eval = o
    end

    Dresult = DiffResults.JacobianResult(result_temp,input_temp)
    temp::Array{Float64,1} = DiffResults.value(Dresult)
    if sparse_jacobian
        sparsity_pattern = jacobian_sparsity(config_eval,result_temp,input_temp)
        jac = Float64.(sparse(sparsity_pattern))
        colors = matrix_colors(jac)
        cfg = ForwardColorJacCache(config_eval,input_temp,nothing;
                    dx = nothing,
                    colorvec = colors,
                    sparsity = nothing)
    else
        jac::Array{Float64,2} = DiffResults.jacobian(Dresult)
        colors = nothing
        cfg = ForwardDiff.JacobianConfig(config_eval, result_temp, input_temp, ForwardDiff.Chunk{argsizes[3]}())
    end

    return OperatorWithADJacobian{Float64,dx,dt,dr,sparse_jacobian,length(argsizes),typeof(negotiated_o),typeof(NothingFunction),typeof(jac)}(negotiated_o,NothingFunction,argsizes,zeros(Float64,3),0,0,0.0,quadorder,Dresult,cfg,jac,temp)
end

set_time!(J::OperatorWithADJacobian, time) = (J.time = time)
set_region!(J::OperatorWithADJacobian, region) = (J.region = region)
is_xdependent(J::OperatorWithADJacobian{T,dx,dt,dr,ndim}) where {T,dx,dt,dr,ndim} = dx
is_timedependent(J::OperatorWithADJacobian{T,dx,dt,dr,ndim}) where {T,dx,dt,dr,ndim} = dt
is_regiondependent(J::OperatorWithADJacobian{T,dx,dt,dr,ndim}) where {T,dx,dt,dr,ndim} = dr

function eval_jacobian!(J::OperatorWithADJacobian{T,false,false,false,false}, input_current) where {T}
    J.Dresult = ForwardDiff.chunk_mode_jacobian!(J.Dresult, J.operator, J.val, input_current, J.cfg)
    return nothing
end
function eval_jacobian!(J::OperatorWithADJacobian{T,false,false,false,true}, input_current) where {T}
    forwarddiff_color_jacobian!(J.jac, J.operator, input_current, J.cfg)
    J.operator(J.val, input_current)
    return nothing
end

function eval_jacobian!(J::OperatorWithADJacobian{T,true,false,false,false}, input_current, x) where {T}
    J.Dresult = ForwardDiff.chunk_mode_jacobian!(J.Dresult, J.operator(x), J.val, input_current, J.cfg)
    return nothing
end
function eval_jacobian!(J::OperatorWithADJacobian{T,true,false,false,true}, input_current, x) where {T}
    forwarddiff_color_jacobian!(J.jac, J.operator(x), input_current, J.cfg)
    J.operator(x)(J.val, input_current)
    return nothing
end

function eval_jacobian!(J::OperatorWithADJacobian{T,false,true,false,false}, input_current) where {T}
    J.Dresult = ForwardDiff.chunk_mode_jacobian!(J.Dresult, J.operator(J.time), J.val, input_current, J.cfg)
    return nothing
end
function eval_jacobian!(J::OperatorWithADJacobian{T,false,true,false,true}, input_current) where {T}
    forwarddiff_color_jacobian!(J.jac, J.operator(J.time), input_current, J.cfg)
    J.operator(J.time)(J.val, input_current)
    return nothing
end

function eval_jacobian!(J::OperatorWithADJacobian{T,false,false,true,false}, input_current) where {T}
    J.Dresult = ForwardDiff.chunk_mode_jacobian!(J.Dresult, J.operator(J.region), J.val, input_current, J.cfg)
    return nothing
end
function eval_jacobian!(J::OperatorWithADJacobian{T,false,false,true,true}, input_current) where {T}
    forwarddiff_color_jacobian!(J.jac, J.operator(J.region), input_current, J.cfg)
    J.operator(J.region)(J.val, input_current)
    return nothing
end

function eval_jacobian!(J::OperatorWithADJacobian{T,true,true,true,false}, input_current, x) where {T}
    J.Dresult = ForwardDiff.chunk_mode_jacobian!(J.Dresult, J.operator(J.region), J.val, input_current, J.cfg)
    return nothing
end
function eval_jacobian!(J::OperatorWithADJacobian{T,true,true,true,true}, input_current, x) where {T}
    forwarddiff_color_jacobian!(J.jac, J.operator(x, J.time, J.region), input_current, J.cfg)
    J.operator(x, J.time, J.region)(J.val, input_current)
    return nothing
end