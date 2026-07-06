using Moshi.Match: @match

using CSV
using DataFrames
using ModelingToolkit
using ModelingToolkit: getdefault
using PreallocationTools
using Symbolics
using DyadData
using DataInterpolations: DataInterpolations
using DataInterpolationsND: DataInterpolationsND

function dataset_interpolation(interpolation_type::AbstractString, filepath::AbstractString, dependent_var::String, independent_var::String; kwargs...)
  dataset = DyadTimeseries(filepath; independent_var, dependent_vars=[dependent_var])
  tb = build_table(dataset)
  data = getproperty(tb, Symbol(only(get_dependent_vars(dataset))))
  ivar = getproperty(tb, Symbol(get_independent_var(dataset)))
  itp = getproperty(InterpolationType, Symbol(interpolation_type))()

  dataset_interpolation(itp, data, ivar; kwargs...)
end

function dataset_interpolation(interpolation_type::InterpolationType.Type, data::AbstractArray, independent_var::AbstractVector, extrapolation_type=ExtrapolationType.None(), args...; kwargs...)
  extrapolation = @match extrapolation_type begin
    ExtrapolationType.None() => DataInterpolations.ExtrapolationType.None
    ExtrapolationType.Constant() => DataInterpolations.ExtrapolationType.Constant
    ExtrapolationType.Linear() => DataInterpolations.ExtrapolationType.Linear
    ExtrapolationType.Extension() => DataInterpolations.ExtrapolationType.Extension
    ExtrapolationType.Periodic() => DataInterpolations.ExtrapolationType.Periodic
    ExtrapolationType.Reflective() => DataInterpolations.ExtrapolationType.Reflective
    _ => error("Unsupported extrapolation type: $extrapolation_type")
  end

  @match interpolation_type begin
    InterpolationType.ConstantInterpolation() =>
      DataInterpolations.ConstantInterpolation(data, independent_var; extrapolation, kwargs...)
    InterpolationType.SmoothedConstantInterpolation() =>
      DataInterpolations.SmoothedConstantInterpolation(data, independent_var; extrapolation, kwargs...)
    InterpolationType.LinearInterpolation() =>
      DataInterpolations.LinearInterpolation(data, independent_var; extrapolation, kwargs...)
    InterpolationType.QuadraticInterpolation() =>
      DataInterpolations.QuadraticInterpolation(data, independent_var; extrapolation, kwargs...)
    InterpolationType.LagrangeInterpolation(n) =>
      DataInterpolations.LagrangeInterpolation(data, independent_var, n; extrapolation, kwargs...)
    InterpolationType.QuadraticSpline() =>
      DataInterpolations.QuadraticSpline(data, independent_var; extrapolation, kwargs...)
    InterpolationType.CubicSpline() =>
      DataInterpolations.CubicSpline(data, independent_var; extrapolation, kwargs...)
    InterpolationType.AkimaInterpolation() =>
      DataInterpolations.AkimaInterpolation(data, independent_var; extrapolation, kwargs...)
    _ =>
      error("Unsupported interpolation type: $interpolation_type")
  end
end

function dataset_interpolation(interpolation_dim1::InterpolationDimension.Type, axis1, interpolation_dim2::InterpolationDimension.Type, axis2, values::AbstractMatrix; kwargs...)

  dim1 = @match interpolation_dim1 begin
    InterpolationDimension.LinearInterpolationDimension() => DataInterpolationsND.LinearInterpolationDimension(axis1)
    InterpolationDimension.ConstantInterpolationDimension() => DataInterpolationsND.ConstantInterpolationDimension(axis1)
    InterpolationDimension.BSplineInterpolationDimension(max_derivative_order_eval) => DataInterpolationsND.BSplineInterpolationDimension(axis1; max_derivative_order_eval)
    _ =>
      error("Unsupported interpolation type: $interpolation_dim1")
  end
  dim2 = @match interpolation_dim2 begin
    InterpolationDimension.LinearInterpolationDimension() => DataInterpolationsND.LinearInterpolationDimension(axis2)
    InterpolationDimension.ConstantInterpolationDimension() => DataInterpolationsND.ConstantInterpolationDimension(axis2)
    InterpolationDimension.BSplineInterpolationDimension(max_derivative_order_eval) => DataInterpolationsND.BSplineInterpolationDimension(axis2; max_derivative_order_eval)
    _ =>
      error("Unsupported interpolation type: $interpolation_dim2")
  end
  interp_dims = (dim1, dim2)

  DataInterpolationsND.NDInterpolation(values, interp_dims)
end

# Source of the code: https://github.com/SciML/ModelingToolkitStandardLibrary.jl/blob/e3a049ed8857b5f79587ab2268e5fdb022870661/src/Blocks/sources.jl#L774-L872C4
# The license: https://github.com/SciML/ModelingToolkitStandardLibrary.jl/blob/e3a049ed8857b5f79587ab2268e5fdb022870661/LICENSE#L1-L21
#
# The arg. names and concerned docstrings are updated to suit this library.

"""
    CachedInterpolation

This callable struct caches the calls to an interpolation object via PreallocationTools.
"""
struct CachedInterpolation{T,I,U,X,C,K}
  interpolation_type::I
  prev_u::U
  prev_x::X
  cache::C
  kwargs::K

  function CachedInterpolation(interpolation_type, u, x, args; kwargs...)
    # we need to copy the inputs to avoid aliasing
    prev_u = DiffCache(copy(u))
    # Interpolation points can be a range, but we want to be able
    # to update the cache if needed (and setindex! is not defined on ranges)
    # with a view from MTKParameters, so we collect to get a vector
    prev_x = DiffCache(collect(copy(x)))
    stored_kwargs = NamedTuple(kwargs)
    cache = GeneralLazyBufferCache() do (u, x)
      interpolation_type(get_tmp(prev_u, u), get_tmp(prev_x, x), args...; kwargs...)
    end
    T = typeof(cache[(get_tmp(prev_u, u), get_tmp(prev_x, x))])
    I = typeof(interpolation_type)
    U = typeof(prev_u)
    X = typeof(prev_x)
    C = typeof(cache)
    K = typeof(stored_kwargs)

    new{T,I,U,X,C,K}(interpolation_type, prev_u, prev_x, cache, stored_kwargs)
  end
end

function (f::CachedInterpolation{T})(u, x, args) where {T}
  (; prev_u, prev_x, cache, interpolation_type, kwargs) = f

  interp = @inbounds if (u, x) ≠ (get_tmp(prev_u, u), get_tmp(prev_x, x))
    get_tmp(prev_u, u) .= u
    get_tmp(prev_x, x) .= x
    cache.bufs[(u, x)] = interpolation_type(
      get_tmp(prev_u, u), get_tmp(prev_x, x), args...; kwargs...)
  else
    cache[(u, x)]
  end

  return interp
end

Base.nameof(::CachedInterpolation) = :CachedInterpolation

@register_symbolic (f::CachedInterpolation)(u::AbstractArray, x::AbstractArray, args::Tuple)::SymbolicUtils.FnType{Tuple{Real}, Real, Nothing}

"""
    ParameterizedInterpolation(; interpolation_type, dependent_var, independent_var, name, kwargs...)

Represent function interpolation symbolically as a block component, with the interpolation data represented parametrically.
By default interpolation types from [`DataInterpolations.jl`](https://github.com/SciML/DataInterpolations.jl) are supported,
but in general any callable type that builds the interpolation object via `itp = interpolation_type(u, x, args...)` and calls
the interpolation with `itp(t)` should work. This does not need to represent an interpolation, it can be any type that satisfies
the interface, such as lookup tables.
# Arguments:
  - `interpolation_type`: the type of the interpolation. For `DataInterpolations`,
these would be any of [the available interpolations](https://github.com/SciML/DataInterpolations.jl?tab=readme-ov-file#available-interpolations),
such as `LinearInterpolation`, `ConstantInterpolation` or `CubicSpline`.
  - `extrapolation_type`: the type of the extrapolation (defaults to `ExtrapolationType.None()`)
  - `data`: dependent value - the data used for interpolation. For `DataInterpolations` this will be an `AbstractVector`
  - `independent_var`: independent value - the values that each data points correspond to, usually the times corresponding to each value in `u`.
# Keyword arguments:
  - `name`: the name of the component

# Parameters:
  - `data`: the symbolic representation of the data passed at construction time via `dependent_var`.
  - `independent_var`: the symbolic representation of independent variable corresponding to the data passed at construction time via `independent_var`.

# Connectors:
  - `u`: This connector represents a real signal as an input from a component ([`RealInput`](@ref))
  - `y`: This connector represents a real signal as an output from a component ([`RealOutput`](@ref))
"""
function ParameterizedInterpolation(; interpolation_type, extrapolation_type=ExtrapolationType.None(), dataset, name, kwargs...)
  extrapolation = @match extrapolation_type begin
    ExtrapolationType.None() => DataInterpolations.ExtrapolationType.None
    ExtrapolationType.Constant() => DataInterpolations.ExtrapolationType.Constant
    ExtrapolationType.Linear() => DataInterpolations.ExtrapolationType.Linear
    ExtrapolationType.Extension() => DataInterpolations.ExtrapolationType.Extension
    ExtrapolationType.Periodic() => DataInterpolations.ExtrapolationType.Periodic
    ExtrapolationType.Reflective() => DataInterpolations.ExtrapolationType.Reflective
    _ => error("Unsupported extrapolation type: $extrapolation_type")
  end

  data, independent_var = dataset[only(get_dependent_vars(dataset))], dataset[get_independent_var(dataset)]
  @match interpolation_type begin
    InterpolationType.ConstantInterpolation() =>
      ParameterizedInterpolation(DataInterpolations.ConstantInterpolation, data, independent_var; name, extrapolation, kwargs...)
    InterpolationType.SmoothedConstantInterpolation() =>
      ParameterizedInterpolation(DataInterpolations.SmoothedConstantInterpolation, data, independent_var; name, extrapolation, kwargs...)
    InterpolationType.LinearInterpolation() =>
      ParameterizedInterpolation(DataInterpolations.LinearInterpolation, data, independent_var; name, extrapolation, kwargs...)
    InterpolationType.QuadraticInterpolation() =>
      ParameterizedInterpolation(DataInterpolations.QuadraticInterpolation, data, independent_var; name, extrapolation, kwargs...)
    InterpolationType.LagrangeInterpolation(n) =>
      ParameterizedInterpolation(DataInterpolations.LagrangeInterpolation, data, independent_var, n; name, extrapolation, kwargs...)
    InterpolationType.QuadraticSpline() =>
      ParameterizedInterpolation(DataInterpolations.QuadraticSpline, data, independent_var; name, extrapolation, kwargs...)
    InterpolationType.CubicSpline() =>
      ParameterizedInterpolation(DataInterpolations.CubicSpline, data, independent_var; name, extrapolation, kwargs...)
    InterpolationType.AkimaInterpolation() =>
      ParameterizedInterpolation(DataInterpolations.AkimaInterpolation, data, independent_var; name, extrapolation, kwargs...)
    _ =>
      error("Unsupported interpolation type: $interpolation_type")
  end
end

function ParameterizedInterpolation(
  interp_type::T, dvalue::AbstractVector, ivalue::AbstractVector, args...;
  name, extrapolation) where {T}

  concrete_dvalue = extract_concrete_value(dvalue)
  concrete_ivalue = extract_concrete_value(ivalue)

  build_interpolation = CachedInterpolation(interp_type, concrete_dvalue, concrete_ivalue, args; extrapolation)

  @parameters data[1:length(concrete_dvalue)] = concrete_dvalue
  @parameters independent_var[1:length(concrete_ivalue)] = concrete_ivalue
  @parameters interpolation_type::T = interp_type [tunable = false]
  @parameters (interpolator::typeof(build_interpolation))(..)::eltype(concrete_dvalue)

  vars = @variables begin
    u(t), [input = true]
    y(t), [output = true]
  end

  eqs = [
    y ~ interpolator(u)
  ]

  bindings = [
    interpolator => build_interpolation(data, independent_var, args)
  ]

  System(eqs, ModelingToolkit.t_nounits, vars,
    [data, independent_var, interpolation_type, interpolator];
    name, bindings)
end

# Helper function to extract concrete values from symbolic or concrete inputs
# Recursively extracts defaults until a concrete value is found
function extract_concrete_value(x::AbstractVector; maxiters=100)
  # If it's already concrete, return it
  if Symbolics.symbolic_type(x) === Symbolics.NotSymbolic()
    return x
  end

  # Recursively extract defaults using a fixpoint iteration
  current = x
  for _ in 1:maxiters
    default = getdefault(current)

    if default === nothing
      error("Cannot extract default value from symbolic array $current. Please provide a default value.")
    end

    # If we've reached a concrete value, return it
    if Symbolics.symbolic_type(default) === Symbolics.NotSymbolic()
      return default
    end

    # Check if we're making progress (value changed)
    if isequal(current, default)
      error("Circular default detected for $x. Cannot extract concrete value.")
    end

    current = default
  end

  error("Could not extract concrete value from $x after $maxiters iterations. Check for deep nesting or circular defaults.")
end
