## ParameterSpace

Defines a sampling space over model parameters using Latin Hypercube (default) or other quasi-Monte Carlo methods.

```julia
ParameterSpace(lb, ub, nsamples = 100, alg = LatinHypercubeSample(); labels)
ParameterSpace(lb, ub, samples::AbstractMatrix; labels)
ParameterSpace(samples::AbstractMatrix; labels = nothing)
```

| Argument | Type | Description |
|----------|------|-------------|
| `lb` | `Vector` | Lower bounds for each parameter dimension |
| `ub` | `Vector` | Upper bounds for each parameter dimension |
| `nsamples` | `Int` | Number of parameter samples to generate. Default `100` |
| `alg` | `QuasiMonteCarlo` algorithm | Sampling algorithm. Default `LatinHypercubeSample()` |
| `samples` | `AbstractMatrix` | Pre-computed samples matrix (D × N). Bypasses sampling. |

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `labels` | `Vector` | `["p_1", "p_2", ...]` | Labels for each parameter dimension. For MTK systems use `ModelingToolkit.parameters(simplified_sys)` |

### Fields
- `config::VectorSpaceConfig` — stores `lb`, `ub`, `nsamples`, `alg`, `labels`
- `samples` — D × N matrix of sampled parameter vectors

### Accessing config
```julia
param_space.config.lb       # lower bounds
param_space.config.ub       # upper bounds
param_space.config.labels   # labels
param_space.samples         # D × N sample matrix
```

---

## ICSpace

Defines a sampling space over initial conditions. Identical API to `ParameterSpace`.

```julia
ICSpace(lb, ub, nsamples = 100, alg = LatinHypercubeSample(); labels)
ICSpace(lb, ub, samples::AbstractMatrix; labels)
ICSpace(samples::AbstractMatrix; labels = nothing)
```

| Argument | Type | Description |
|----------|------|-------------|
| `lb` | `Vector` | Lower bounds for each state dimension |
| `ub` | `Vector` | Upper bounds for each state dimension |
| `nsamples` | `Int` | Number of IC samples to generate. Default `100` |
| `alg` | `QuasiMonteCarlo` algorithm | Sampling algorithm. Default `LatinHypercubeSample()` |
| `samples` | `AbstractMatrix` | Pre-computed samples matrix (D × N). Bypasses sampling. |

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `labels` | `Vector` | `["ic_1", "ic_2", ...]` | Labels for each state dimension. For MTK systems use `ModelingToolkit.unknowns(simplified_sys)` |

---

## SimulatorConfig

Combines one or more sample spaces and orchestrates ensemble simulation.

```julia
SimulatorConfig(args::AbstractSpace...; combine_alg = CrossProduct())
```

| Argument | Type | Description |
|----------|------|-------------|
| `args...` | `AbstractSpace` | Any combination of `ParameterSpace`, `ICSpace`, `CtrlSpace`. Order does not matter. |

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `combine_alg` | `AbstractCombineAlg` | `CrossProduct()` | How to combine samples from multiple spaces. `CrossProduct()` produces `n1 × n2 × ...` combinations. |

### Calling the SimulatorConfig

The `SimulatorConfig` is callable. It takes either an `ODEProblem` or a `ModelingToolkit.System` and returns an `ExperimentData`:

```julia
ed = sim_config(prob; kwargs...)           # ODEProblem
ed = sim_config(simplified_sys; kwargs...) # MTK System (must be structurally simplified)
```

All `kwargs...` are forwarded through `simulate_ensemble` → `solve`. The following are explicitly handled:

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `alg` | ODE solver | `AutoTsit5(FBDF())` | ODE solver algorithm. Use `Tsit5()` for non-stiff, `Rosenbrock23()` or `FBDF()` for stiff systems. |
| `enseble_alg` | `EnsembleAlgorithm` | `EnsembleDistributed()` | Parallelization strategy. Use `EnsembleDistributed()` with `Distributed.addprocs()`. `EnsembleSerial()` for single-process. `EnsembleThreads()` for multithreading. |
| `verbose` | `Bool` | `true` | Print progress and process info during simulation. |
| `tspan` | `Tuple{Float64, Float64}` | from `ODEProblem` | Time span for integration. Required for MTK systems. |
| `abstol` | `Float64` | solver default | Absolute tolerance for the ODE solver. |
| `reltol` | `Float64` | solver default | Relative tolerance for the ODE solver. |
| `saveat` | `AbstractVector` / `Float64` | solver default | Time points to save solution at, or a fixed step size. |
| `maxiters` | `Int` | solver default | Maximum number of solver iterations per trajectory. |
| `dtmin` | `Float64` | solver default | Minimum allowed timestep. |
| `dtmax` | `Float64` | solver default | Maximum allowed timestep. |
| `states_labels` | `Vector` | all unknowns | (MTK only) Subset of unknowns to store. Defaults to all unknowns in the system. |
| `observables_labels` | `Vector` | all observed | (MTK only) Subset of observed variables to store. Defaults to all observed variables. Set to `nothing` to skip. |

Any other keyword accepted by `DifferentialEquations.solve` is also forwarded.

---

## ExperimentData

Container for simulation results. Holds both the specifications (initial conditions, parameters, time spans) and results (states, observables, controls, time series).

### Structure
```
ExperimentData
├── specs::DSSpecification
│   ├── u0s::StatsAndVals      # initial conditions
│   ├── y0s::StatsAndVals      # initial observables
│   ├── ps::StatsAndVals       # parameters
│   └── tspans::StatsAndVals   # time spans
└── results::DSResults
    ├── states::StatsAndVals   # state trajectories
    ├── observables::StatsAndVals  # observable trajectories
    ├── controls::StatsAndVals # control input trajectories
    └── tss::StatsAndVals      # time arrays
```

Each `StatsAndVals` holds:
- `labels` — variable names
- `stats` — named tuple with `lb`, `ub`, `mean`, `std` (all vectors of length D)
- `vals` — `Vector{Matrix{Float64}}` where each matrix is D × T_i (one per trajectory)

### Length and indexing

```julia
length(ed)       # number of trajectories
ed[i]            # single trajectory → new ExperimentData with 1 trajectory
ed[1:10]         # range → new ExperimentData with trajectories 1–10
ed[1:end]        # all trajectories (equivalent to ed[:])
```

Indexing always returns a new `ExperimentData` with recomputed statistics.

### Concatenation

```julia
ed_combined = vcat(ed1, ed2, ed3, ...)
```

Combines multiple `ExperimentData` objects. All must represent the same system (matching labels and dimensions). Statistics are recomputed over the combined set.

### Labels

```julia
get_labels(ed, :states)       # state variable labels
get_labels(ed, :u0s)          # same as :states
get_labels(ed, :observables)  # observable labels
get_labels(ed, :y0s)          # same as :observables
get_labels(ed, :controls)     # control input labels
get_labels(ed, :ps)           # parameter labels
get_labels(ed)                # all labels as a vector of vectors
```

### Statistics

All return a `Vector{Float64}` of length D (one value per variable):

```julia
get_lb(ed, sym)    # lower bound across all trajectories
get_ub(ed, sym)    # upper bound across all trajectories
get_mean(ed, sym)  # mean across all trajectories
get_std(ed, sym)   # standard deviation across all trajectories
```

`sym` can be any of: `:states`, `:observables`, `:controls`, `:u0s`, `:y0s`, `:ps`.

For results fields (`:states`, `:observables`, `:controls`), bounds are computed over all time points across all trajectories.
For spec fields (`:u0s`, `:y0s`, `:ps`), bounds are computed over the sampled values.

Global bounds (all states + controls + params combined):
```julia
get_lb(ed)   # concatenated lower bounds
get_ub(ed)   # concatenated upper bounds
```

### Accessing raw data

```julia
# Continuous (time-varying) data — returns Vector{Matrix{Float64}}
ed.results.states.vals         # state trajectories, each D_s × T_i
ed.results.observables.vals    # observable trajectories, each D_o × T_i
ed.results.controls.vals       # control trajectories, each D_c × T_i
ed.results.tss.vals            # time arrays, each 1 × T_i

# Discrete (per-trajectory) data — returns Vector{Vector{Float64}}
ed.specs.u0s.vals              # initial conditions, each length D_s
ed.specs.ps.vals               # parameters, each length D_p
ed.specs.y0s.vals              # initial observables, each length D_o
ed.specs.tspans.vals           # time spans
```

Convenience accessors:
```julia
grab_continuous_sim_value(ed, :states)      # same as ed.results.states.vals
grab_continuous_sim_value(ed, :observables)
grab_continuous_sim_value(ed, :controls)
grab_discrete_sim_value(ed, :u0s)           # same as ed.specs.u0s.vals
grab_discrete_sim_value(ed, :ps)
```

### Iteration

```julia
for traj in ed
    traj.results   # single trajectory results
    traj.specs     # single trajectory specs
end
```

### Filtering

```julia
filtered_ed = filter(f, ed)   # f receives each trajectory, returns Bool
```
