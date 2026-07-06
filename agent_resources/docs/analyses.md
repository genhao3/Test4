# Dyad Analysis Reference

In Dyad, an analysis is a way to operate on or run a model.
A typical workflow in Dyad is to create a set of components, and then create an
analysis that runs on the entry point to that set of components. It produces a
solution object that provides information about the model, and can be used to
build various visualizations.

The typical user flow is to extend some partial analysis or built-in analysis and provide the model and whatever parameters are necessary in Dyad.

For example, here's how you would create a first order component and then simulate it:

```dyad
"""
Minimal first-order lag block with transfer function k/(sT + 1).
Matches standard BlockComponents.Continuous.FirstOrder patterns.
"""
component SimpleFirstOrder
  "Output signal port"
  y = RealOutput()
  "State variable representing filtered value"
  variable x::Real
  "Time constant and gain"
  parameter T::Real = 1.0
  parameter k::Real = 1.0
relations
  der(x) = (k - x)/T
  y = x
end

analysis SimpleFirstOrderTransient
  extends TransientAnalysis(stop = 10.0)
  model = SimpleFirstOrder()
end
```

You can also override parameters in the model via the analysis:

```dyad
analysis SimpleFirstOrderTransient
  extends TransientAnalysis(stop = 10.0)
  model = SimpleFirstOrder(T = Tconst, k = 2.0)
  parameter Tconst::Real = 1.0
end
```

The way to run these analyses is to invoke them in Julia.

```julia
using MyLibrary
result = SimpleFirstOrderTransient()
```

You can also pass parameters as keyword arguments to the analysis:
```julia
result = SimpleFirstOrderTransient(Tconst = 2.0)
```

## How analyses run under the hood

When an analysis runs, **two separate systems are compiled**, each with its own balance check:

1. **Main system** — `mtkcompile(model)` compiles the equations of motion. Checks that the number of equations matches the number of unknowns. Failure here means a structural issue (missing equations, unconnected ports, etc.).

2. **Initialization system** — A separate nonlinear system is built from your `initial` and `guess` statements, then compiled with `mtkcompile(init_system; fully_determined=true)`. Checks that initialization equations exactly match initialization unknowns. Failure here means wrong number of initial conditions (too many or too few).

Both throw `ExtraVariablesSystemException` or `ExtraEquationsSystemException` with "The system is unbalanced." The error message does not say which system failed, but the stacktrace will show `InitializationProblem` for initialization failures vs `get_simplified_model` for structural failures.

**Default solvers:**

| Analysis | Default `alg` | Resolves to |
|----------|--------------|-------------|
| TransientAnalysis | `ODEAlg.Auto()` | `DefaultODEAlgorithm(autodiff = AutoForwardDiff())` |
| TransientAnalysis with `alg=AutoImplicit` | `ODEAlg.AutoImplicit()` | `DefaultImplicitODEAlgorithm()` |
| SteadyStateAnalysis | `NonlinearSolveAlg.Auto()` | `FastShortcutNonlinearPolyalg()` |

**Note:** the default above is what the Dyad kernel emits for `extends TransientAnalysis(...)`. If `DyadInterface.TransientAnalysis` is invoked directly from Julia (without going through Dyad), the field default in DyadInterface's `TransientAnalysisSpec` is `ODEAlg.AutoImplicit()`, which resolves to `DefaultImplicitODEAlgorithm()`.

**To emulate the full Dyad analysis pipeline in Julia:**

```julia
using ProjectName
using ModelingToolkit

# @named is required for all MTK constructors
@named m = TestHarness()
sys = mtkcompile(m)

# After mtkcompile, use sys. to reference variables
prob = ODEProblem(sys, [sys.x => 0.0, sys.y => 0.0], (0.0, 10.0); fully_determined=true)

# solve() auto-selects algorithm — no solver import needed
sol = solve(prob)
```

If step 1 passes but step 2 fails, the issue is initialization — not structural. Adjust the number of initial conditions, not the model equations.

## Accessing Solution Data in Julia

Once you run an analysis, you can access the solution data using symbolic indexing. This works for any analysis result that implements `SymbolicIndexingInterface.symbolic_container`:

```julia
using DyadInterface: symbolic_container

result = MyAnalysis()
sol = result.sol
model = symbolic_container(result)

# Direct component.variable access (recommended)
temperature = sol[model.heat_capacitor.T]
voltage = sol[model.resistor.v]

# String-based variable access (convenient for plotting)
plot(sol, idxs = sol."heat_capacitor.T")
plot(sol, idxs = sol."resistor.v")              # works with nested component paths

# Using Symbol with ₊ separator
temperature = sol[Symbol("heat_capacitor₊T")]

# Time points and interpolation
times = sol.t                    # All time points
state_at_50s = sol(50.0)         # Interpolated state at t=50
value_at_50s = sol(50.0)[1]      # First state variable at t=50

# Plotting multiple variables
using Plots
plot(sol.t, sol[model.component1.x], label="Component 1")
plot!(sol.t, sol[model.component2.x], label="Component 2")
```

The solution preserves your model's hierarchical structure, allowing intuitive access to variables using the same component.variable syntax from your Dyad model.

The string-based access (`sol."variable_name"`) returns the symbolic variable, which is useful for passing to `plot(sol, idxs=...)` without needing to extract the model separately via `symbolic_container`.

DyadInterface v7 (shipped with Dyad 3.0.0) extends the same string-dot syntax to the **analysis result itself**, so you can skip the `result.sol` unwrapping:

```julia
result = MyAnalysis()

# v7 — string-dot syntax works directly on the analysis result
sym = result."heat_capacitor.T"               # symbolic variable for heat_capacitor.T
plot(result, idxs = result."heat_capacitor.T")
plot(result, idxs = result."cars.engine.flange_a.s")   # nested paths
```

This works for any analysis whose author has implemented `SymbolicIndexingInterface.symbolic_container(::MyAnalysisSolution)` — every built-in analysis does.

You can also retrieve the model directly from the result using `get_model`:

```julia
using DyadInterface: get_model

result = MyAnalysis()
model = get_model(result)  # returns the compiled model from the solution
```

Note that `result.spec.model` is the original model *before* structural simplification. If you need the simplified system (e.g., to inspect which variables were eliminated), use the `:SimplifiedSystem` artifact or `symbolic_container(result)`.

## Artifacts

Every analysis result supports the `artifacts` API, which provides structured outputs like plots, DataFrames, and downloadable files. This is the primary way to extract results from any analysis.

### Querying Available Artifacts

```julia
result = MyAnalysis()

# List all available artifact names
artifacts(result)
# => [:SimulationSolutionPlot, :SimulationSolutionTable, :ObservablesTable, :RawSolution, ...]

# Generate a specific artifact
table = artifacts(result, :SimulationSolutionTable)   # Returns a DataFrame
plot = artifacts(result, :SimulationSolutionPlot)      # Returns a Plots.jl plot
raw = artifacts(result, :RawSolution)                  # Returns the underlying solver result
```

### Artifact Types

Each artifact has a type that determines what it returns:

| Type | Returns | Description |
|------|---------|-------------|
| `PlotlyPlot` | Plots.jl plot | Visualizations rendered with the Plotly backend |
| `DataFrame` | DataFrames.jl table | Tabular data for inspection or export |
| `Download` | Downloadable blob | Files like CSV exports, FMU binaries, etc. |
| `Native` | Julia object | Raw solver objects for advanced usage |

### Solution Metadata

Use `AnalysisSolutionMetadata` to inspect what an analysis result provides:

```julia
metadata = AnalysisSolutionMetadata(result)

# Available artifacts with their types and descriptions
metadata.artifacts              # Vector{ArtifactMetadata}
metadata.artifacts[1].name      # :SimulationSolutionPlot
metadata.artifacts[1].type      # ArtifactType.PlotlyPlot
metadata.artifacts[1].title     # "Solution plot"

# Symbol groups — which variables are available
metadata.symbol_groups          # Dict{Symbol, Vector{Symbol}}
metadata.symbol_groups[:unknowns]     # [:x, :y, ...]
metadata.symbol_groups[:observables]  # [:u, ...]
```

### Custom Visualization

TransientAnalysis and CalibrationAnalysis results support custom visualizations where you select which variables to plot:

```julia
using DyadInterface: PlotlyVisualizationSpec, customizable_visualization

vizspec = PlotlyVisualizationSpec([:x, :y])
custom_plot = customizable_visualization(result, vizspec)
```

## Related Documentation

For advanced analysis features:

- **[functions.md](functions.md)** - Using Julia functions to compute complex parameter values in analyses
- **[arrays.md](arrays.md)** - Working with arrays of components in analyses
- **[plotting.md](plotting.md)** - Visualizing analysis results

## Built-in Analyses

### TransientAnalysis

**Purpose:** Simulates a system over time, given a component.
Solves initial value problems for differential-algebraic equations to capture dynamic behavior.

**Required:**
- `model` — the component to simulate
- `stop` — end time for the integration

**Optional:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `start` | `0` | Start time for the integration |
| `alg` | `ODEAlg.Auto()` | ODE solver algorithm. Variants: `Auto`, `AutoImplicit`, `Tsit5`, `Rodas5P`, `FBDF` |
| `abstol` | `1e-6` | Absolute tolerance for the solver |
| `reltol` | `1e-6` | Relative tolerance for the solver |
| `saveat` | `0` | Time interval for saving solution points. `0` lets the integrator choose |
| `dtmax` | `0` | Maximum allowed timestep. `0` lets the integrator choose |
| `tstops` | `[]` | Time points where the integrator must step exactly. Useful when you know where discontinuities or events occur — forces the solver to land on those times rather than stepping over them |
| `automatic_discontinuity_detection` | `false` | When `true`, applies the `ModelingToolkit.IfLifting` pass during `mtkcompile`, which automatically detects and handles `if`/`else` discontinuities in the model equations |
| `respecialize` | `false` | When `true`, calls `ModelingToolkit.respecialize` on the compiled system after `mtkcompile`. This specializes nonnumeric parameters (e.g. abstractly typed containers) to their concrete types based on their defaults. Required for FMU generation and can improve simulation performance for models with complex parameter types (e.g. fluid medium models) |

**Output:** Time series solution, plots, solution tables. As a special case, any TransientAnalysis is plottable via `plot(result; attributes...)`.

### SteadyStateAnalysis

**Purpose:** Finds equilibrium where system derivatives equal zero.
Useful for determining operating points and static analysis of systems at rest.

**Required:**
- `model` — the component to find the equilibrium of

**Optional:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `alg` | `NonlinearSolveAlg.Auto()` | Nonlinear solver algorithm. Variants: `Auto` (polyalgorithm), `TrustRegion`, `LevenbergMarquardt`, `NewtonRaphson` |
| `abstol` | `1e-8` | Absolute tolerance for the solver |
| `reltol` | `1e-8` | Relative tolerance for the solver |
| `automatic_discontinuity_detection` | `false` | When `true`, applies the `ModelingToolkit.IfLifting` pass during `mtkcompile`, which automatically detects and handles `if`/`else` discontinuities in the model equations |
| `respecialize` | `false` | When `true`, calls `ModelingToolkit.respecialize` on the compiled system after `mtkcompile`. This specializes nonnumeric parameters (e.g. abstractly typed containers) to their concrete types based on their defaults. Required for FMU generation and can improve simulation performance for models with complex parameter types (e.g. fluid medium models) |

**Output:** Steady state variable values, DataFrame

## Control Analyses (DyadControlSystems.jl)

### ClosedLoopAnalysis
**Purpose:** Analyzes feedback system frequency/time-domain properties via linearization.
Evaluates stability margins, sensitivity functions, and closed-loop performance characteristics.
- **Required:** `model`, `measurement` (vector), `control_input` (vector)
- **Optional:** `wl=-1`, `wu=-1`, `num_frequencies=300`, `pos_feedback=true`, `duration=-1.0`, `loop_openings=[]`, `t=0.0`
- **Output:** Bode plots, disk/classical margins, step responses

### ClosedLoopSensitivityAnalysis
**Purpose:** Computes sensitivity function S=1/(1+PC) to assess robustness.
Determines how sensitive the closed-loop system is to disturbances and model uncertainties.
- **Required:** `model`, `analysis_points` (vector)
- **Optional:** `loop_openings=[]`, `wl=-1.0`, `wu=-1.0`, `t=0.0`
- **Output:** Sensitivity Bode plot, H-infinity norm, phase/gain margin bounds

### LinearAnalysis
**Purpose:** Linearizes model for small-signal frequency/time-domain analysis.
Provides comprehensive linear system analysis including poles, zeros, and frequency response.
- **Required:** `model`, `inputs` (vector), `outputs` (vector)
- **Optional:** `wl=-1`, `wu=-1`, `num_frequencies=3000`, `duration=-1`
- **Output:** Bode/margin/step/root-locus plots, damping/observability reports

### PIDAutotuningAnalysis
**Purpose:** Automatically optimizes PID gains for frequency-domain robustness.
Uses optimization to find controller parameters that satisfy sensitivity constraints while maximizing performance.
- **Required:** `model`, `measurement`, `control_input`, `step_input`, `step_output`, `Ts` (sampling), `duration`, `Ms`, `Mt`, `Mks`
- **Optional:** `ref=0.0`, `disc="tustin"`, `filter_order=2`, `wl`, `wu`
- **Output:** Optimized PID parameters, sensitivity plots, Nyquist plot

### FrequencyResponseAnalysis
**Purpose:** Performs frequency response experiments on nonlinear models.
Excites the system with a chirp or other input signal and measures the frequency response at specified outputs.
- **Required:** `model`, `input` (string), `outputs` (vector), `wl`, `wu`
- **Optional:** `num_frequencies=50`, `input_type="chirp"`, `duration=-1.0`, `Ts=-1.0`
- **Output:** Bode plot of measured frequency response

### LQGAnalysis
**Purpose:** Designs an optimal Linear-Quadratic-Gaussian (LQG) controller with state feedback and Kalman observer.
Computes optimal gains by solving Riccati equations for the specified cost weights and noise covariances.
- **Required:** `model`, `measurement` (vector), `controlled_output` (vector), `control_input` (vector), `q1_diag`, `q2_diag`, `r1_diag`, `r2_diag`
- **Optional:** `loop_openings=[]`, `t=0.0`, `qQ=0.0`, `qR=0.0`, `disc="cont"`, `Ts=-1.0`, `integrator_indices=[]`, `integrator_r1_diag=[]`, `wl=-1`, `wu=-1`, `num_frequencies=3000`, `duration=-1.0`, `maximum_order=-1`
- **Output:** Controller and observer gains, closed-loop analysis plots

### PolePlacementAnalysis
**Purpose:** Designs a state feedback controller and observer via pole placement.
Places closed-loop poles to achieve desired damping and bandwidth characteristics.
- **Required:** `model`, `measurement` (vector), `control_input` (vector)
- **Optional:** `loop_openings=[]`, `t=0.0`, `min_damping=0.707`, `controller_speed_factor=1.0`, `observer_speed_factor=5.0`, `min_bandwidth=-1.0`, `max_bandwidth=-1.0`, `direct_controller=false`, `disc="cont"`, `Ts=-1.0`, `integrator_indices=[]`, `integrator_poles=[]`, `wl=-1`, `wu=-1`, `num_frequencies=3000`, `duration=-1.0`
- **Output:** Controller and observer gains, closed-loop analysis plots

### StateEstimationAnalysis
**Purpose:** Estimates hidden states from noisy measurements using Kalman filtering or smoothing.
Supports Extended Kalman Filter for nonlinear models with configurable noise covariances.
- **Required:** `model`, `outputs` (vector), `disturbance_inputs` (vector), `r1_diag`, `r2_diag`
- **Data:** Either `input_data`/`output_data` matrices or `dataset` (DyadTimeseries) with `input_cols`/`output_cols`
- **Optional:** `inputs=[]`, `estimator="ExtendedKalmanFilter"`, `filtering_mode="filtering"`, `sigma0=1e-4`, `discretization="Rk4"`, `Ts=-1.0`, `plot_confidence=true`, `confidence_level=1.96`, `n_samples=0`
- **Output:** Filtered/smoothed state trajectories, innovation analysis, performance metrics

### SystemIdentificationAnalysis
**Purpose:** Identifies a linear state-space model from input/output data.
Supports subspace identification and prediction-error methods to build models from experimental measurements.
- **Required:** `Ts` (sampling period)
- **Data:** Either `input_data`/`output_data` matrices or `dataset` (DyadTimeseries) with `input_cols`/`output_cols`
- **Optional:** `method="subspaceid"`, `nx="auto"`, `simulation_focus=false`, `stable=false`, `zeroD=false`, `h=1`, `r=10`, `W="MOESP"`, `detrend=true`, `wl=-1.0`, `wu=-1.0`, `num_frequencies=3000`, `duration=-1.0`
- **Output:** Identified model, fit metrics, frequency response

## Model Calibration (DyadModelOptimizer.jl)

> **Breaking change in DyadModelOptimizer v15 (shipped with Dyad 3.0.0).** The `calibration_alg`, `optimizer`, and `loss_func` parameters on `CalibrationAnalysis` and the discovery analyses below are no longer strings — they are dyad enum types: `CalibrationAlg`, `OptimizerAlg`, and `LossFunc` respectively. Old string-form values from v14 (`"SingleShooting"`, `"auto"`, `"l2loss"`, etc.) translate to the corresponding enum variant: `CalibrationAlg.SingleShooting()`, `OptimizerAlg.Auto()`, `LossFunc.L2Loss()`.

### CalibrationAnalysis
**Purpose:** Fits model parameters to experimental data via optimization.
Minimizes the difference between simulated and measured outputs to find optimal parameter values.
- **Required:** `model`, `stop`, `data` (DyadDataset), `N_cols`, `depvars_cols`, `depvars_names`, `N_tunables`, `search_space_names`, `search_space_lb`, `search_space_ub`
- **Optional:** `alg=ODEAlg.Auto()`, `abstol=1e-8`, `reltol=1e-8`, `calibration_alg=CalibrationAlg.SingleShooting()`, `optimizer=OptimizerAlg.Auto()`, `optimizer_maxiters=100`
- **Output:** Calibrated parameters, comparison plots, parameter tables

## Model Discovery (DyadModelDiscovery.jl)

### SystemLevelNNTrainingAnalysis
**Purpose:** Trains a neural network to learn missing dynamics at the ODE system level.
Augments the compiled ODE right-hand side with a NN, then optimizes NN weights to fit observed data.
- **Required:** `model`, `stop`, `data` (DyadTimeseries), `depvars_names`, `calibration_alg` (a `CalibrationAlg` variant), `optimizer_maxiters`, `N_inputs`, `input_vars`, `N_outputs`, `output_vars`, `nn_depth`, `nn_width`, `nn_activation`
- **Optional:** `alg=ODEAlg.Auto()`, `abstol=1e-8`, `reltol=1e-8`, `optimizer=OptimizerAlg.Auto()`, `learning_rate=1e-3`, `wrapper_type="add"`, `use_bias=false`, `scale_input=false`, `scale_output=false`, `nn_rng_seed=42`, `zero_init_last=false`, `nn_model_type="chain"`, `loss_func=LossFunc.L2Loss()`, `optimizer_abstol=1e-4`, `optimizer_maxtime=0.0`, `optimizer_verbose=false`, `multiple_shooting_trajectories=0`
- **Output:** Trained NN weights (`res.r.u`), convergence plot, mean input Jacobian, calibrated simulation

### SystemLevelUDEAnalysis
**Purpose:** Runs symbolic regression on a trained system-level NN to extract interpretable equations.
Takes trained NN weights from `SystemLevelNNTrainingAnalysis` and discovers symbolic expressions.
- **Required:** `model`, `stop`, `data` (DyadTimeseries), `depvars_names`, `calibration_alg` (a `CalibrationAlg` variant), `optimizer_maxiters`, `nn_depth`, `nn_width`, `nn_activation`, `training_result_N`, `training_result` (weight vector from step 1), `N_sr_inputs`, `sr_inputs`, `N_sr_outputs`, `sr_outputs`, `maxdepth`, `maxsize`
- **Optional:** `N_inputs=0`, `input_vars=[]`, `N_outputs=0`, `output_vars=[]`, `save_to_file=true`, plus all NN and optimizer options from `SystemLevelNNTrainingAnalysis`
- **Output:** Candidate symbolic expressions (`res.candidates`), candidate models that can be simulated

### NNTrainingAnalysis
**Purpose:** Trains a `NeuralNetworkBlock` embedded in a Dyad component to fit observed data.
References the NN by its component name and optimizes its parameters.
- **Required:** `model`, `stop`, `data` (DyadTimeseries), `depvars_names`, `calibration_alg` (a `CalibrationAlg` variant), `optimizer_maxiters`, `network_component`
- **Optional:** `alg=ODEAlg.Auto()`, `abstol=1e-8`, `reltol=1e-8`, `optimizer=OptimizerAlg.Auto()`, `learning_rate=1e-3`, `loss_func=LossFunc.L2Loss()`, `min_weight=-Inf`, `max_weight=Inf`, `initial_values_path=""`, `results_path=""`, `optimizer_abstol=1e-4`, `optimizer_maxtime=0.0`, `optimizer_verbose=false`, `multiple_shooting_trajectories=0`
- **Output:** Trained NN weights (saveable via `results_path`), convergence plot, mean input Jacobian, calibrated simulation

### SymbolicRegressionUDEAnalysis
**Purpose:** Runs symbolic regression on a trained component-level NN to extract interpretable equations.
Loads trained weights from a CSV file and discovers symbolic expressions that approximate the NN.
- **Required:** `model`, `data` (DyadTimeseries), `depvars_names`, `network_component`, `training_result` (path to CSV), `maxdepth`, `maxsize`
- **Optional:** `alg=ODEAlg.Auto()`, `abstol=1e-8`, `reltol=1e-8`, `loss_func=LossFunc.L2Loss()`, `min_weight=-Inf`, `max_weight=Inf`, `save_to_file=true`, `unary_operators=[]`
- **Output:** Candidate symbolic expressions (`res.candidates`), candidate models that can be simulated

## FMU Generation (DyadFMUGeneration.jl)

### FMUAnalysis
**Purpose:** Builds Functional Mock-up Unit from Dyad model for co-simulation or model exchange.
Creates a binary that implements FMI standard, enabling model exchange with other simulation tools.
- **Required:** `model`, `n_inputs::Integer`, `inputs::Vector{String}`, `n_outputs::Integer`, `outputs::Vector{String}`
- **Optional:** `version = "FMI_2" or "FMI_3"`, `fmu_type "FMI_ME" or "FMI_CS" or "FMI_BOTH"`, `alg` (only for cosimulation)
- **Output:** FMU file (.fmu), compliance report

## Common Parameter Types
- **Time:** Numeric time values
- **String vectors:** Use `["signal1", "signal2"]` format
- **Solver algorithms:** "auto" selects automatically
- **Tolerances:** Absolute (abstol) and relative (reltol) numerical tolerances

## Usage Pattern
```dyad
analysis MyAnalysisName
  extends PackageName.AnalysisType(
    required_param = value,
    optional_param = value
  )
  model = MyModel()
end
```
