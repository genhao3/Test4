---
name: surrogate-modelling
description: "Surrogate generation for dynamical systems with DyadSurrogates.
---

# When To Use:
To generate surrogate of a dynamical system.

# DyadSurrogates - Data generation and surrogate modelling.

The core workflow for surrogate generation is as follows:
- Generate simulation data for the model
- Inspect generated simulation data
- Train a surrogate on simulation data.


## Data Generation:
Inorder to train the surrogate, multiple simulations of the source model over a parameter space and an initial condition space are collected in an `DyadSurrogates.ExperimentData` object. 

### Data Sources:
DataGeneration supports the following sources for running simulations:
- `ModelingToolkit.System` for MTK models.
- `ODEProblem` for direct `f(u, p, t)` functions written with DifferentialEquations.jl
The final result of a data generation step is an ExperimentData object.

### Core Workflow:
The core workflow for generating simulation data from a `ModelingToolkit.System` data source is as follows:

#### Adding the right sub package directly to the Project:
```julia
Pkg.add(["DyadSurrogates", "DyadSurrogatesDataGen", "DyadSurrogatesBase"])
```

#### Leverage Julia Parallel Processes
Data generation will take up a lot of time if run serially. Inorder to parallelize the process, you should ALWAYS use Julia Distributed library.
```julia
# Load All the required packages on main process
using Distributed
using ModelingToolkit, OrdinaryDiffEq
using ModelingToolkit: t_nounits as t, D_nounits as D
using DyadSurrogatesDataGen
num_procs = 10
# Add 10 processes.
addprocs(num_procs)
# Load the packages on all processes
@everywhere begin
    using ModelingToolkit, OrdinaryDiffEq
    using ModelingToolkit: t_nounits as t, D_nounits as D
    using DyadSurrogates
end 
```
#### Defining  Sample Spaces: Parameter Space and Initial Conditions Space
This step involves defining the space for initial conditions and parameters in order to sample parameters and initial conditions from them. These parameters and inital conditions would be used to generate a simulation.
```julia
p_lower_bound = [1.1, 500.0]
p_upper_bound = [1.25, 1000.0]
p_num_samples = 100
params_of_interest = ["subsystem₊p1", "sub_system₊component₊p2"] # Provide the parameters for which sampling is done.
p_labels =  ModelingToolkit.parse_variable.(Ref(simplified_sys), params_of_interest)
param_space = ParameterSpace(p_lower_bound, p_upper_bound, p_num_samples; labels = p_labels) # Latin Hypercube sampling for parameter space: [1.1, 500] -> [1.25, 1000.0]
param_space.samples
```
```julia
ic_lower_bound = [0.23, 4.9]
ic_upper_bound = [0.62, 9.1]
ic_num_samples = 125
ic_of_interest = ["subsystem₊x1(t)", "sub_system₊component₊y(t)"]
ic_labels = ModelingToolkit.parse_variable.(Ref(simplified_sys), ic_of_interest)
ic_space = ICSpace(ic_lower_bound, ic_upper_bound, ic_num_samples; labels = ic_labels)
```

#### Defining overall Simulation Space:
The number of simulation trajectories that will be generated is `p_num_samples` x `ic_num_samples`. 
Define a `SimulatorConfig` as:
```julia
sim_config_only_param = SimulatorConfig(param_space)
sim_config_only_ic = SimulatorConfig(ic_space)
sim_config = SimulatorConfig(ic_space, param_space) 
```
A `SimulatorConfig` can take both or either of the two spaces, order doesnot matter.

#### Running the data source on the constructed simulator config:
```julia
ed = sim_config(simplified_sys; tspan = (0.0, 10.0), alg = Tsit5(), abstol = 1e-8, reltol = 1e-9)
```


#### Providing State and Observable Labels:
Sometimes, you only need to store a certain subset of unknowns and observables of interest from a system. Use the string name of the variable, and parse it.
```julia
unknowns_to_save = ModelingToolkit.parse_variable.(Ref(simplified_sys), ["subsystem₊x2(t)", "sub_system₊component₊z(t)"]) 
observed_to_save = ModelingToolkit.parse_variable.(Ref(simplified_sys), ["sub_system₊component₊o(t)"])
ed = sim_config(simplified_sys; tspan = (0.0, 10.0), alg = Tsit5(), abstol = 1e-8, reltol = 1e-9, state_labels = unknowns_to_save, observables_labels = observed_to_save)
```

Read `agent_resources/surrogate-modelling/examples/data-generation.md`, for end to end examples.

#### Data Inspection:
In order to train a surrogate, the following things are IMPORTANT:
- The parameters or / and initial conditions space should have an uniform distribution. i.e. the parameter samples and initial conditions samples should be uniformly distributed across the hypercube space defined by the bounds.
- The states / observable space should be explored completely. i.e. enough data is generated to truely represent the system.

### Saving the ExperimentData object.
ALWAYS serialize and save the `ExperimentData` object. Data generation is a time consuming process, instead of losing all data on a fresh julia session, you can load the data from serialized object instead.
```julia
Serialization.serialize("experiment_data.jls", ed)
```

NOTE: Before reloading the experiment data, make sure the model is defined in the current session.

## Surrogate Training:
Once a suitable dataset is generated in the form of an `ExperimentData`, the next step is training the surrogate.
See `references/surrogate-training.md` for full API reference on `split`, `DigitalEcho`, and `SolutionOperator` kwargs.

### Splitting Data
```julia
train_ed, val_ed = split(ed, [0.75, 0.25]; shuffle_dataset = true)
```

### GPU Setup
```julia
using CUDA, cuDNN
```

### Training with DigitalEcho-SolutionOperator (Recommended):
`SolutionOperator` is passed as a type argument to `DigitalEcho`:
```julia
model = DigitalEcho(SolutionOperator, train_ed;
    ground_truth_port = :states,
    verbose = true,
    val_ed = val_ed,
    train_on_gpu = true,
)
```
####  Managing the Training Schedule:
You can provide the `epochs_per_lr` keyword argument to the function to specify the number of epochs per learning rate step. The learning rate schedule is designed to train the surrogate optimally.
Inorder to reduce the training time, pass a smaller `epochs_per_lr` value. Total number of epochs will be `epochs_per_lr x 7 (7 is the number of learning rate steps)`. For example, if `epochs_per_lr` is 100, total epochs will be 700. If `epochs_per_lr` is 500, total epochs will be 3500. The default value is 500.
For example:
```julia
model = DigitalEcho(SolutionOperator, train_ed;
    ground_truth_port = :states,
    verbose = true,
    val_ed = val_ed,
    train_on_gpu = true,
    epochs_per_lr = 30,
) # Will train for 30*7 = 210 epochs.
```

### Inference
Both return callable wrappers with the same interface:
```julia
# Directly produce an experiment data (Recommended)
pred_ed = model(val_ed; ic_port = [:states]) # trained only on states
pred_ed = model(val_ed; ic_port = [:observables]) # trained only on observables
pred_ed = model(val_ed; ic_port = [:states, :observables]) # trained on both
# Other methods:
pred = model(u0, nothing, p, tspan; saveat = ts)           # no controls
pred = model(u0, (u, t) -> ctrl(t), p, tspan; saveat = ts) # with controls
```

#### Handling the Prediction ExperimentData
The prediction experiment data (`pred_ed`) will contain `ArrayOfSplines` for the predicted fields.
```julia
typeof(pred_ed.results.states.vals[1]) <: ArrayOfSplines
```
To get the predictions in a matrix form to compare against a validation experiment data object do:
```julia
predicted_states = map(pred_ed.results.states.vals) do val 
    reduce(hcat, val.u)
end
# Similarly if observables are also trained via `ground_truth_port`:
predicted_obs = map(pred_ed.results.observables.vals) do val 
    reduce(hcat, val.u)
end
```
Now they can be used for comparision against a validation experiment data, or for plotting. 