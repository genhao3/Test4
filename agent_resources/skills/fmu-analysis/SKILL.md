---
name: fmu-analysis
description: Load when the user asks to (a) generate, build, or export an FMU from a Dyad model (keywords "export ode system", "build an fmu", "co-simulation", "model exchange", FMI_ME / FMI_CS, FMUAnalysis), or (b) test, validate, inspect, or investigate an existing FMU (metadata checks, Julia load/simulate, FMPy cross-ecosystem verification). Covers FMUAnalysis arguments, and reference tests under references/.
---

# FMU Deployment

## FMUAnalysis

FMUAnalysis builds an FMU from a Dyad model. The generated FMU is a causal component with only input (`u`) and output (`h`) connectors — no acausal connectors. A **Model Exchange** FMU exposes the right-hand side `(f,g,h)` for an external solver. A **Cosimulation** FMU embeds an ODE solver that advances the state over a given `dt` with `u` held constant.

## FMU Workflow

### Step 1: Add Dependencies

`DyadFMUGeneration` provides `FMUAnalysis`. Check the current package environment; if it is missing, add it.

### Step 2: Implement and verify the Dyad model

If the requested component does not already exist in the Dyad library, implement it first. Verify that it compiles, simulates via `TransientAnalysis`, and returns correct trajectories. FMU compilation is slow — finalize the model first.

### Step 3: Write the FMUAnalysis in Dyad

```julia
analysis MyFMUAnalysis
  extends DyadFMUGeneration.FMUAnalysis(version = "FMI_V3", fmu_type = "FMI_CS", logfile="MyFMUAnalysis.log")
  model = BlockComponents.Sine(frequency = 1.0, amplitude = 1.0)
end
```

Set `logfile` to log stdout/stderr to a file.
If JuliaC fails to compile the FMU:
  - Analyze the log file and make a report.
  - Fall back to PackageCompiler by setting `use_juliac = false`.

To pin a specific cosimulation solver, pass the `ODEAlg` enum directly:

```julia
analysis MyFMUAnalysis
  extends DyadFMUGeneration.FMUAnalysis(version = "FMI_V3", fmu_type = "FMI_CS", alg = ODEAlg.Rodas5P(), logfile="MyFMUAnalysis.log")
  model = BlockComponents.Sine(frequency = 1.0, amplitude = 1.0)
end
```

See the `fmu_type` DAE restriction in Analysis Arguments below.

### Step 4: Build FMU and save artifact

Launch FMU compilation in a background Julia session.
When JuliaC is used, FMU compilation takes 300s–400s.
Without JuliaC, FMU compilation takes 1200s–2700s — don't poll more than once every 300s for the first 1200s.

```julia
result = MyFMUAnalysis()

using DyadInterface
fmu_path = artifacts(result, :FMU)
```

The FMU is written to a Julia scratchspace that may be cleaned up between
`julia_tool` calls. **Immediately** after `artifacts(result, :FMU)` returns,
copy the `.fmu` to a permanent location:

```julia
permanent = joinpath(@__DIR__, "..", "assets", "my_model.fmu")
cp(fmu_path, permanent; force=true)
@assert isfile(permanent)
```

### Step 5: Validate the generated FMU

**IMPORTANT:** `TransientAnalysis` on the Dyad model does NOT validate the FMU. The FMU is a compiled binary from a separate codegen pipeline and can diverge from the source (initialization, solver numerics, codegen bugs). Inspect and simulate the `.fmu` itself with FMI.jl.

**Prefer using FMI internals (e.g `FMI.loadFMU` + `fmu.modelDescription`) over extracting the archive and reading `modelDescription.xml` directly.** `FMI.loadFMU` parses the description with the same loader the runtime uses, surfaces loader/binary errors that a raw XML read would miss, and resolves variable references with proper typing. Manual zip extraction is acceptable only as a last resort — for example, when `FMI.loadFMU` itself fails and you need to inspect the archive to diagnose why.

#### Step 5a — Metadata inspection

Loading the FMU, reading `modelDescription`, and unloading does **not** run the solver, so it is safe to call in-process from `julia_tool` or as a subprocess. For a quick check, use the canned helper:

```julia
# SUBSTITUTE: path to your Dyad library project, path to your FMU
project_dir = "/path/to/the/Dyad/library"
fmu_path = "/path/to/my_model.fmu"
inspect_script = joinpath(@__DIR__, "..", "references", "fmu_inspect.jl")
run(`julia --project=$project_dir $inspect_script $fmu_path`)
```

It prints `fmiVersion`, CS/ME support, inputs, and outputs — enough to confirm the FMU matches the Dyad model's interface.

Use try-catch while inspecting metadata. Some `modelVariables` fields can be partially populated and bare access throws `UndefRefError`.

#### Step 5b — Simulation

**IMPORTANT:** FMU **simulation** in-process shares a runtime with `julia_tool` and deadlocks. Write the simulation script to a file and execute it via `run(cmd)`.

Replace values marked `# SUBSTITUTE`:

<!-- fmu_test.jl -->
```julia
using FMI

# SUBSTITUTE: path to your generated FMU
fmu = FMI.loadFMU("/path/to/my_model.fmu")
md = fmu.modelDescription

# SUBSTITUTE: "3.0" for FMI_V3, "2.0" for FMI_V2
@assert md.fmiVersion == "3.0"

# SUBSTITUTE: your output variable names
output_vars = Set(v.name for v in md.modelVariables if v.causality == "output")
@assert Set(["y1", "y2"]) ⊆ output_vars

# SUBSTITUTE: simulateME or simulateCS
sol = FMI.simulateME(fmu, (0.0, 10.0))
@assert all(all(isfinite, u) for u in sol.states.u)

# Always unload FMU after completing the simulation
FMI.unloadFMU(fmu)
```

```julia
# SUBSTITUTE: path to your Dyad library project
project_dir = "/path/to/the/Dyad/library"
# SUBSTITUTE: path to the script written above
cmd = `julia --project=$project_dir /path/to/fmu_test.jl`
run(cmd)
```

For extended validation (file structure, XML metadata, input functions, step-size sweeps), adapt `references/lv_minimum_tests.jl` or `references/lv_detailed_tests.jl`.

### Step 6: Cross-validate against reference (if one exists)

> **Degenerate test warning:** If the reference FMU starts at equilibrium
> (all-zero or constant ICs), all formulations produce identical zero
> trajectories regardless of equation correctness. Always test with
> nonzero initial conditions that excite the dynamics before declaring
> a match.

If a reference exists, compare its outputs against the **generated `.fmu`** at nonzero ICs — load both with `FMI.loadFMU` and run `simulateCS` / `simulateME` on each, then diff the trajectories. **Do not** substitute `TransientAnalysis` on the Dyad model for this step; the warning at the top of Step 5 applies. See `references/lv_fmpy_tests.py` for the FMPy cross-ecosystem template.

## Completion Checklist

An FMU task is complete when ALL of these are true:

- [ ] FMUAnalysis compiles without errors
- [ ] `artifacts(result, :FMU)` returns a valid `.fmu`
- [ ] The `.fmu` loads with `FMI.loadFMU` as the correct type (FMU2/FMU3)
- [ ] modelDescription shows correct version, CS/ME support, inputs, outputs
- [ ] `simulateME` or `simulateCS` on the **generated FMU** produces finite, non-trivial results
- [ ] If a reference FMU exists: state trajectories match within tolerance at nonzero ICs

## Analysis Arguments

#### Required Arguments

- `model`: the Dyad model that the analysis is being applied to.

#### Optional Arguments

- `version::String`: FMU version. `"FMI_V2"` (default) or `"FMI_V3"`.
- `fmu_type::String`: FMU type. `"FMI_ME"` (Model Exchange), `"FMI_CS"` (Cosimulation), or `"FMI_BOTH"` (both in one binary, default).

  > **DAE restriction:** Model Exchange FMUs require a pure ODE system
  > (mass matrix = identity after `mtkcompile`). If your model has implicit
  > algebraic constraints, the build will fail with "DAEs not supported for
  > ModelExchange FMUs." Either reformulate as an explicit ODE (solve the
  > mass matrix analytically) or use `fmu_type = "FMI_CS"`.

- `alg::ODEAlg`: solver algorithm for the Cosimulation FMU. Default is `ODEAlg.Auto()`. Other choices: `ODEAlg.AutoImplicit()`, `ODEAlg.Rodas5P()`, `ODEAlg.FBDF()`, `ODEAlg.Tsit5()`. Pass the enum value directly (no string).
- `n_inputs::Integer`: length of `u(t)`.
- `inputs::String[n_inputs]`: Dyad variables bound to each input; order must match `u(t)`.
- `n_outputs::Integer`: length of `h`.
- `outputs::String[n_outputs]`: variables included in `h`; order must match `h`.
- `additional_deps::Vector{String}`: Additional Julia package dependencies to bundle into the generated FMU.
- `use_juliac::Boolean`: Use the `juliac`-based pipeline for smaller FMU binaries. `true` by default — JuliaC is the default pipeline; set `false` to fall back to PackageCompiler. When `true`, requires `respecialize = true` (the default) — a warning is emitted otherwise and compilation will likely fail.
- `verbose::Boolean`: Stream build output to the terminal. `false` by default. When `false`, stdout/stderr are redirected (see `logfile`).
- `logfile::String`: Path to write build stdout and stderr to. Empty by default — temporary files are used and their paths are logged. Ignored when `verbose = true`. Build logs are the only way to diagnose codegen/compile failures, so prefer setting this to a known path for non-trivial builds.
- `respecialize::Boolean`: Re-specialize the model based on the current parameters. `true` by default; required when a model has a struct-typed parameter declared with an abstract supertype, otherwise the model is type-unstable and won't compile.

> **No inputs / no outputs:** if the model has no input connectors, omit `n_inputs` and `inputs` (do not pass `n_inputs = 0` or an empty `inputs` vector). Same for `n_outputs` / `outputs`. The resulting FMU's `modelDescription` will simply show zero variables of that causality.

## Backend

Dyad's FMUAnalysis uses FMUGeneration.jl as the backend. For the FMUGeneration API see `references/fmu-julia-api.md`; for a direct-usage example see `references/lotka_volterra.jl`.
