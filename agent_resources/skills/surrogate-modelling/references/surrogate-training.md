## split

Splits an `ExperimentData` into training / validation / test sets.

```julia
split(ed::ExperimentData, ratio::Real; shuffle_dataset = false, rng = default_rng())
split(ed::ExperimentData, ratios::AbstractVector{<:Real}; shuffle_dataset = false, rng = default_rng())
```

| Argument | Description |
|----------|-------------|
| `ratio` | Single float (e.g. `0.75`). Returns `(train_ed, rest_ed)`. |
| `ratios` | Vector of floats (e.g. `[0.7, 0.15, 0.15]`). Returns N ExperimentData objects. |

| Keyword | Default | Description |
|---------|---------|-------------|
| `shuffle_dataset` | `false` | Shuffle trajectories before splitting |
| `rng` | `default_rng()` | Random number generator for shuffle order |

---

## DigitalEcho

Primary surrogate model. Encoder-decoder architecture with a continuous-time embedding system.

```julia
DigitalEcho(ed::ExperimentData; kwargs...)
DigitalEcho(ed::ExperimentData, checkpointed_surrogate, opt_state; kwargs...)
```

| Positional | Description |
|------------|-------------|
| `ed` | Training ExperimentData |
| `checkpointed_surrogate` | (Optional) Previously trained model to resume from |
| `opt_state` | (Optional) Optimizer state for resuming |

| Keyword | Default | Description |
|---------|---------|-------------|
| `ground_truth_port` | `:states` | Target field(s). `:states`, `:observables`, or `[:states, :observables]` |
| `RSIZE` | `256` | Size of the reservoir / embedding system |
| `n_layers` | `2` | Number of layers in the decoder |
| `n_epochs` | `24500` | Number of training epochs |
| `batchsize` | `2048` | Mini-batch size |
| `opt` | `Optimisers.Adam()` | Optimizer |
| `schedule` | `nothing` | Learning rate schedule |
| `lambda` | `1e-6` | L2 regularization coefficient |
| `activation` | `tanh` | Activation function for embedding system |
| `max_eig` | `0.9` | Maximum eigenvalue for weight initialization (spectral radius) |
| `tau` | `1e-1` | Effective time scale of the dynamical system |
| `solver` | `Tsit5()` | ODE solver used during training |
| `solver_kwargs` | `(abstol=1e-9, reltol=1e-9)` | Solver tolerances |
| `train_on_gpu` | `true` | Use GPU for training |
| `callevery` | `200` | Callback frequency (epochs between progress prints) |
| `verbose` | `false` | Print training progress |
| `val_ed` | `nothing` | Validation ExperimentData |
| `test_ed` | `nothing` | Test ExperimentData |

**Returns:** `DigitalEchoInferenceWrapper` (callable).

---

## SolutionOperator

DeepONet-style architecture with branch-trunk decomposition. Passed as a type argument to `DigitalEcho`.

```julia
DigitalEcho(SolutionOperator, ed::ExperimentData; kwargs...)
```

| Keyword | Default | Description |
|---------|---------|-------------|
| `ground_truth_port` | `:states` | Target field(s). `:states`, `:observables`, or `[:states, :observables]` |
| `norm_scale` | `(0.1, 1.0)` | Min-max normalization range |
| `epochs_per_lr` | `500` | Epochs per learning rate step |
| `lrs` | `[1e-3, 5e-4, 3e-4, 1e-4, 5e-5, 3e-5, 1e-5]` | Stepped learning rate schedule |
| `batchsize` | `2048` | Mini-batch size |
| `loss` | `Flux.mae` | Loss function |
| `lambda` | `1e-6` | L2 regularization |
| `opt` | `Optimisers.Adam()` | Optimizer |
| `train_on_gpu` | `true` | Use GPU for training |
| `verbose` | `false` | Print training progress |
| `val_ed` | `nothing` | Validation ExperimentData |
| `test_ed` | `nothing` | Test ExperimentData |

Total training epochs = `epochs_per_lr * length(lrs)` (default: 500 * 7 = 3500).

**Returns:** `SurrogateInferenceWrapper` (callable).

---

## Inference

Both `DigitalEchoInferenceWrapper` and `SurrogateInferenceWrapper` are callable:

```julia
# Array-based inference
pred = model(u0, x, p, tspan; saveat = ts)
```

| Argument | Type | Description |
|----------|------|-------------|
| `u0` | `AbstractArray` | Initial condition vector |
| `x` | `Function` or `nothing` | Control function `(u, t) -> control_vector`, or `nothing` for autonomous systems |
| `p` | `AbstractArray` | Parameter vector |
| `tspan` | `Tuple{Float64, Float64}` | Integration time span |

| Keyword | Description |
|---------|-------------|
| `saveat` | Time points or step size to save at |

```julia
# ExperimentData-based inference (runs on all trajectories)
pred_ed = model(ed)
pred_ed = model(ed; ic_port = :states)  # DigitalEchoInferenceWrapper only
```