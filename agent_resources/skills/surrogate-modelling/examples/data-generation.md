
## 1. Generation simulations for `ModelingToolkit.System`.
For a MTK model defined like this:
```julia
@everywhere begin
    using ModelingToolkit, OrdinaryDiffEq
    using ModelingToolkit: t_nounits as t, D_nounits as D
    using DyadSurrogatesDataGen
end # ALWAYS LEVERAGE PARALLEL PROCESSING.

# # MTK MODEL DEFINITION. 

@component function LotkaVolterra(; name = :lv_component)
  @parameters p1 p2 p3 p4
  @variables x1(t) x2(t)

  eqs = [
    D(x1) ~ p1 * x1 - p2 * x1 * x2,
    D(x2) ~ -(p3 * x2) + p4 * x1 * x2,
  ]
  params = [p1, p2, p3, p4]
  vars = [x1, x2]
  initial_conditions = Dict(x1 => 1.0, x2 => 1.0, p1=>1.75,  p2=>1.8, p3=>2.0, p4=>1.8)
  System(eqs, t, vars, params; initial_conditions = initial_conditions, name)
end

@component function LotkaVolterraObservedSystem(; name=:lv_obs_comp)
  @variables w(t) v(t)

  lv_component = LotkaVolterra(; name = :lv_component)
  eqs = [
    w ~ sin(lv_component.x1 + lv_component.x2),
    v ~ cos(lv_component.x1 - lv_component.x2)
  ]
  initial_conditions = Dict()
  System(eqs, t, [w, v], []; systems = [lv_component], initial_conditions, name)
end
@named sys = LotkaVolterraObservedSystem()

# ALWAYS SIMPLIFY A SYSTEM BEFORE DATA GENERATION.
simplified_sys = structural_simplify(sys) 
```
Data is generated like this:

- **For all parameters**:
```julia
param_lower_bound = [1.5, 1.75, 1.5, 1.75]
param_upper_bound = [2.5, 2.0, 2.7, 2.43]
num_param_samples = 500

param_space = ParameterSpace(
  param_lower_bound, 
  param_upper_bound,
  num_param_samples,
  labels = ModelingToolkit.parameters(simplified_sys)
)
```

- **Subset of Parameters**:
```julia
param_lower_bound = [1.5, 1.75]
param_upper_bound = [2.5, 2.0]
num_param_samples = 500

params_of_interest = ["lv_component₊p1", "lv_component₊p3"]
param_labels = ModelingToolkit.parse_variable.(Ref(simplified_sys), params_of_interest)

param_space = ParameterSpace(
  param_lower_bound, 
  param_upper_bound,
  num_param_samples,
  labels = param_labels
)
```
- **For all initial conditions**:
```julia
u0_lower_bound = [0.98, 0.98]
u0_upper_bound = [1.2, 1.25]
num_u0_samples = 600
u0_space = ICSpace(
  u0_lower_bound,
  u0_upper_bound,
  num_u0_samples,
  labels = ModelingToolkit.unknowns(simplified_sys)
)
```
- **For subset of initial conditions**:
```julia
u0_lower_bound = [0.98]
u0_upper_bound = [1.3]
num_u0_samples = 600
u0_space = ICSpace(
  u0_lower_bound,
  u0_upper_bound,
  num_u0_samples,
  labels = ModelingToolkit.parse_variable.(Ref(simplified_sys), ["lv_component₊x2(t)"])
)
```

```julia
simulator_config_params_only = SimulatorConfig(param_space) # 500 samples
simulator_config_u0s_only = SimulatorConfig(u0_space) # 600 samples
simulator_config_all = SimulatorConfig(param_space, u0_space) # 500 x 600 = 30_000 samples
```
- **Save all variables**:
```julia
experiment_data_params_only = simulator_config_params_only(simplified_sys;
  tspan = (0.0, 10.0),
  alg = Tsit5(),
  abstol = 1e-8,
  reltol = 1e-8)

experiment_data_u0s_only = simulator_config_u0s_only(simplified_sys;
  tspan = (0.0, 10.0),
  alg = Tsit5(),
  abstol = 1e-8,
  reltol = 1e-8)

experiment_data_all = simulator_config_all(simplified_sys;
  tspan = (0.0, 10.0),
  alg = Tsit5(),
  abstol = 1e-8,
  reltol = 1e-8)
```
- **Save only variables of interest**:
```julia
unknowns_of_interest = ["lv_component₊x1(t)", "lv_component₊x2(t)"]
observed_of_interest = ["w(t)"]

states_labels = ModelingToolkit.parse_variable.(Ref(simplified_sys), unknowns_of_interest)
observables_labels = ModelingToolkit.parse_variable.(Ref(simplified_sys), observed_of_interest)

experiment_data_params_only = simulator_config_params_only(simplified_sys;
  states_labels, 
  observables_labels,
  tspan = (0.0, 10.0),
  alg = Tsit5(),
  abstol = 1e-8,
  reltol = 1e-8)

experiment_data_u0s_only = simulator_config_u0s_only(simplified_sys;
  states_labels, 
  observables_labels,
  tspan = (0.0, 10.0),
  alg = Tsit5(),
  abstol = 1e-8,
  reltol = 1e-8)

experiment_data_all = simulator_config_all(simplified_sys;
  states_labels, 
  observables_labels,
  tspan = (0.0, 10.0),
  alg = Tsit5(),
  abstol = 1e-8,
  reltol = 1e-8)
```

## 2. Generation simulations for `ODEProblem`.**
For an ODEProblem defined like this:
```julia
@everywhere begin
  using DyadSurrogates 
  using OrdinaryDiffEq
end

@everywhere function lv(u, p, t)
    u₁, u₂ = u
    α, β, γ, δ = p
    dx = α * u₁ - β * u₁ * u₂
    dy = δ * u₁ * u₂ - γ * u₂
    [dx, dy]
end
tstop = 12.5
p = [1.75, 1.8, 2.0, 1.8]
u0 = [1.0, 1.0]
tspan = (0.0, tstop)

prob = ODEProblem{false}(lv, u0, tspan, p);
```
You will generate data by using:
```julia

param_lower_bound = [1.5, 1.75, 1.5, 1.75]
param_upper_bound = [2.5, 2.0, 2.7, 2.43]
num_param_samples = 500

param_space = ParameterSpace(
  param_lower_bound, 
  param_upper_bound,
  num_param_samples,
  labels = ["α", "β", "δ", "γ"]
)

u0_lower_bound = [0.98, 0.98]
u0_upper_bound = [1.2, 1.25]
num_u0_samples = 600
u0_space = ICSpace(
  u0_lower_bound,
  u0_upper_bound,
  num_u0_samples,
  labels = ["u₁", "u₂"]
)

simulator_config_params_only = SimulatorConfig(param_space) # 500 samples
simulator_config_u0s_only = SimulatorConfig(u0_space) # 600 samples
simulator_config_all = SimulatorConfig(param_space, u0_space) # 500 x 600 = 30_000 samples

experiment_data_params_only = simulator_config_params_only(prob;
  tspan = (0.0, 10.0),
  alg = Tsit5(),
  abstol = 1e-8,
  reltol = 1e-8)

experiment_data_u0s_only = simulator_config_u0s_only(prob;
  tspan = (0.0, 10.0),
  alg = Tsit5(),
  abstol = 1e-8,
  reltol = 1e-8)

experiment_data_all = simulator_config_all(prob;
  tspan = (0.0, 10.0),
  alg = Tsit5(),
  abstol = 1e-8,
  reltol = 1e-8)
```
