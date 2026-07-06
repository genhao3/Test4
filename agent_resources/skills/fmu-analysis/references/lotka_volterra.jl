# Deploying a Lotka-Volterra FMU model
# In this example we will demonstrate how to deploy a Lotka-Volterra model as a FMU using `FMUGeneration.jl`.
# We start by loading `FMUGeneration` and `OrdinaryDiffEq` into our environment.

using FMUGeneration
using OrdinaryDiffEq

# For the tutorial, we chose a [Lotka Volterra](https://en.wikipedia.org/wiki/Lotka%E2%80%93Volterra_equations) system with controls. This system is a pair of non-linear differential equations used to describe the dynamics of a biological system.
# The system has a set of parameters `α`, `β`, `γ`, `δ` and `u₁` , `u₂` are time-dependent controls.

# ```math
# \frac{dx₁}{dt} = \alpha x₁ - \beta x₁x₂  + u₁
# ```
# ```math
# \frac{dx₂}{dt} = \delta x₁x₂ - \gamma x₂ - u₂
# ```

# FMUGeneration.jl first creates a package for the FMU containing the necessary functions, models, and variables, then builds a sysimage.

# We define the above system as an expression to be packaged into an FMU as follows:

lv_expr = :(function (dx, x, u, p, t)
    x₁, x₂ = x
    u₁, u₂ = u
    α, β, γ, δ = p
    dx₁ = α * x₁ - β * x₁ * x₂ + u₁
    dx₂ = δ * x₁ * x₂ - γ * x₂ - u₂
    dx = [dx₁, dx₂]
end);

# Once we have defined our system and continuous model, we need to define some defaults for the system. These include initial states, initial inputs, default parameters, and the timespan.

initial_states = [1.0, 1.0]
initial_inputs = [0.01, 0.01]
default_parameters = [2.0, 1.875, 2.0, 1.875]
tspan = (0.0, 10.0)
param_names = ["α", "β", "γ", "δ"]
input_names = ["u_1", "u_2"]
state_names = ["x_1", "x_2"]

# We then instantiate a `JuliaFMU` object which comines the meradata, dependencies and dynamics which make up the FMU. This implicitly generates the metadata.

fmu = JuliaFMU(
    # REQUIRED ARGUMENTS

    # We specify the FMU name
    "lotka-volterra",
    # We specify the FMI version
    FMI_V3, # or v2,
    # We specify the FMU operating types supported
    [FMI_MODELEXCHANGE, FMI_COSIMULATION];

    # OPTIONAL ARGUMENTS

    # We optionally specify the default time-space of the FMU operation
    default_tspan=tspan,
    # We optionally specify the recommended step size
    # default_stepsize = 1e-3,
    # We optionally specify the recommended solver tolerance
    # default_tolerance = 1e-6,


    # Metadata: inputs, parameters and states respectively
    inputs=[
        (name=input_names[i], start=initial_inputs[i]) for i in 1:length(input_names)
    ],
    parameters=[
        (name=param_names[i], start=default_parameters[i]) for i in 1:length(param_names)
    ],
    states=[
        (name=state_names[i], start=initial_states[i]) for i in 1:length(state_names)
    ],

    # We define the dependencies required for the FMU. Here, we need OrdinaryDiffEq for the solver used to run the FMU in CS mode.
    dependencies=@deps([OrdinaryDiffEq]),
    # We define the ODE function expression with the signature `(dx, u, p, t) -> begin ... end` where the function is expected to be inplace. Here, it is the `double_pendulum_expr` defined earlier. This is an essential kwarg for all ME FMUs.
    ode_function=lv_expr,
    # We optionally define function to compute the outputs with the signature `(x, u, p, t) -> outs`.
    # observables_function = observable_expr,
    # We specify which solver to use for cosimulation. We default to `OrdinaryDiffEq.AutoTsit5(OrdinaryDiffEq.FBDF())` if not provided.
    cosimulator_solver=:(OrdinaryDiffEq.AutoTsit5(OrdinaryDiffEq.FBDF())),
    # If we had inputs, we would also had to specify it like below:
    # inputs = [
    #   (name="input_1", start=1.0),
    #   ...
    # ],

    # If we had to initialize out states in a specific manner, we could also that like below:
    # state_initializer = :((x, u, p, t) -> initialize_x)

    # We could also optionally provide integrator options:
    # cosimulator_integrator_options=(abstol=1e-6, reltol=1e-6),

    # We could also optionally provide objects from user space needed for the FMU dynamics to operate
    # objects=@objects([test_obj]),

    # We optionally define the number of threads to start the FMU with to capitalize on multi-threaded acceleration of matmul operations. This is only relevant if your computation is heavy on matrix operations.
    # n_octavian_threads = 4
)
