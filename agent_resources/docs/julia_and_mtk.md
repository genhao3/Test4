# Dyad and Julia

Dyad is a modeling language that compiles down to Julia code, which uses ModelingToolkit.jl and the DifferentialEquations.jl ecosystem to solve systems.

In general, the workflow of a Dyad user tends to be that they will write their models in Dyad and perhaps an analysis that can simulate the models (such as a transient analysis) and then invoke those in Julia. Read the analyses.md file in this directory to understand what that workflow looks like.

However, there may be times when you want to go straight to Julia and manipulate your model there.  In this case, here's how you can do that.

## Getting started

Load your component library into the current Julia session.  Also load ModelingToolkit and DyadInterface which are necessary to run Dyad models in Julia.  **YOU MUST ALWAYS LOAD MODELINGTOOLKIT AND DYADINTERFACE**.

```julia
using $MyLibrary
using ModelingToolkit, OrdinaryDiffEqDefault, DyadInterface
```

To construct a dyad model within Julia, you may use the `@named` macro, like so:

```julia
@named model = MyLibrary.MyModel()
```

This only instantiates the model. If you want to compile the model (applying structural simplification, etc.), call `mtkcompile` on it.

```julia
model = mtkcompile(model)
```

Alternatively, you may use the `@mtkcompile` macro to construct and compile at once.

```julia
@mtkcompile model = MyLibrary.MyModel()
```

## Running the model

To run the model, you can construct an `ODEProblem` and then solve it.

```julia
prob = ODEProblem(
    model,
    [model.x => 0.0, model.y => 0.0], # operating point: initial conditions and parameter overrides
    (0.0, 10.0) # timespan
)

sol = solve(prob) # One arg method preferred; uses default solver, which is generally best.
# or
sol = solve(prob, Tsit5()) # solve(prob, alg) where alg is from OrdinaryDiffEq.jl.  Make sure to load the correct ODE subpackage for that solver.
```

Good solvers to try are:
- `Tsit5()`: standard explicit solver
- `Rodas5P()`: standard implicit solver
- `FBDF()`: implicit BDF method, good with oscillations
- `Rosenbrock23()`: implicit Rosenbrock method, good with stiff systems

Note that to use all of these solvers you should do `using OrdinaryDiffEq` to get all the subpackages.

## Verbose logging

The `TransientAnalysis` can be used to show detailed logs during the integration by running with the
`DEVerbosity.Detailed()` or `DEVerbosity.All()` `verbose` option. This option can also be added from
the dyad code.

```
using DyadInterface

TransientAnalysisSpec(; ... verbose = DEVerbosity.All())
```

## Plotting the results

You can plot the results using Plots.jl.  See `plotting.md` in this directory for more specific plotting information.
