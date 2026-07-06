# FMUGeneration Julia API

## Specify the FMU dynamics and the metadata

`FMUGeneration.JuliaFMU` --- Type

```julia
function JuliaFMU(
    name::String,
    fmi_version::FMIEnums.FMIVersion,
    fmi_types::AbstractVector{<:FMIEnums.ModelType};
    default_tspan = nothing,
    default_stepsize = nothing,
    default_tolerance = nothing,
    parameters = NamedTuple[],
    inputs = NamedTuple[],
    states = NamedTuple[],
    outputs = NamedTuple[],
    dependencies = (Pkg.Types.PackageSpec[], Pkg.Types.PackageSpec[]),
    deserialization_utils = Expr[],
    objects = String[],
    dynamics_utils = Expr[],
    ode_function = nothing,
    state_initializer = :((u, in, p, t) -> u),
    observables_function = nothing,
    cosimulator = nothing,
    cosimulator_solver=:(OrdinaryDiffEq.AutoTsit5(OrdinaryDiffEq.FBDF())),
    cosimulator_integrator_options = (;),
    n_octavian_threads = 4,
)
```

Constructor for the metadata and dynamics of a Functional Mockup Unit
(FMU) which can be used to generate a FMU Julia package and compile it
into a FMU binary.

**Arguments**

-   `name::String`: Name of the FMU

-   `fmi_version::FMIEnums.FMIVersion`: Version of the FMI standard

-   `fmi_types::AbstractVector{<:FMIEnums.ModelType}`: Types of the FMU
    (e.g. Model Exchange, Co-simulation)

-   `default_tspan::Union{Nothing, Tuple{Float64, Float64}}`: Default
    time span for the simulation. Defaults to nothing.

-   `default_stepsize::Union{Nothing, Float64}`: Default step size for
    the simulation. Defaults to nothing.

-   `default_tolerance::Union{Nothing, Float64}`: Default tolerance for
    the simulation. Defaults to nothing.

-   `parameters::NamedTuple[]`: Parameters of the FMU. Ex.
    `(name="p1", description="Parameters description", start=0.0)`.
    Defaults to an empty array.

-   `inputs::NamedTuple[]`: Inputs of the FMU. Ex.
    `(name="x1", description="Input 1", start=0.0)`. Defaults to an
    empty array.

-   `states::NamedTuple[]`: States of the FMU. Ex.
    `(name="u1", description="State 1", start=0.0)`. Defaults to an
    empty array.

-   `outputs::NamedTuple[]`: Outputs of the FMU. Ex.
    `(name="o1", description="Output 1")`. Defaults to an empty array.

-   `dependencies::Tuple{Pkg.Types.PackageSpec[], Pkg.Types.PackageSpec[]}`:
    Dependencies of the FMU. Ex. `@deps [OrdinaryDiffEq]`. Defaults to
    an empty array.

-   `deserialization_utils::Expr[]`: Utilities required for
    deserialization. Defaults to an empty array.

-   `objects::String[]`: Paths of the serialized objects. Ex.
    `@objects [test_obj]`. Defaults to an empty array.

-   `dynamics_utils::Expr[]`: Utilities which require deserialized
    objects and are needed for the dynamics. Defaults to an empty array.

-   `ode_function::Union{Nothing, Expr}`: Expression of an in-place ODE
    function for the FMU of the form
    `ode_function!(derivatives, states, inputs, parameters, time)`.
    Defaults to nothing.

-   `state_initializer::Union{Nothing, Expr}`: State initializer for the
    FMU. Expression of out-of-place function of the form
    `state_initializer(states, inputs, parameters, time) -> initialized_states`.
    Defaults to nothing.

-   `observables_function::Union{Nothing, Expr}`: Observables function
    for the FMU. Expression of out-of-place function of the form
    `observables_function(states, inputs, parameters, time) -> outputs`.
    Defaults to nothing.

-   `cosimulator::Union{Nothing, Expr}`: Co-simulator for the FMU.
    Defaults to nothing. Expression of out-of-place function of the form
    `cosimulator(states, inputs, parameters, time) -> states`.

-   `cosimulator_solver::Union{Nothing,Expr}`: Expression of solver for
    the co-simulator. Defaults to nothing.

-   `cosimilator_odefunction_options::Union{Nothing, Expr, NamedTuple}`:
    `ODEFunction` options for the co-simulator solver. Defaults to an
    empty `NamedTuple`.

-   `cosimulator_integrator_options::Union{Nothing,Expr,NamedTuple}`:
    Integrator options for the co-simulator solver. Defaults to an empty
    NamedTuple.

-   `n_octavian_threads::Int`: Number of threads to use for Octavian for
    matrix ops acceleration. Defaults to 4.

-   `build::Bool`: Automatically generate code and compile the FMU.
    Defaults to `true`.

## Miscellaneous

`FMUGeneration.@deps` --- Macro

```julia
macro deps(deps)
```

This macro is used to define the dependencies that is needed to be
available in the FMU.

**Arguments**

-   `deps::AbstractVector`: A vector of package modules

`FMUGeneration.@objects` --- Macro

```julia
macro objects(objs, backend=:jls)
```

This macro is used to define the objects that is needed to be available
in the FMU.

We default to the Base.Serialization backend, but the user can specify a
different backend.

-   :jls - Base.Serialization
-   :bson - BSON.jl

**Arguments**

-   `objs::AbstractVector`: A vector of objects to be serialized
-   `backend::Symbol`: The backend to use for serialization.
