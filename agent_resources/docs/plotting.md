# Plotting in Dyad

You can plot the results of `TransientAnalysis` via `plot(result; attributes...)`.
This ability is enabled by loading Plots.jl, via `using Plots`.

Here are some examples.  First there is a Dyad component (from `BlockComponents`)
that we create, as well as an analysis to run it:

```dyad
component FirstAndSecondOrder
  "First-order state: der(x) = 1 - x"
  variable x::Real
  "Second-order state"
  variable y::Real
  "Second-order derivative: der(yd) = 1 - 2*yd - y"
  variable yd::Real
relations
  der(x) = 1 - x
  der(y) = yd
  der(yd) = 1 - 2*yd - y
end
```

And the analysis:

```dyad
analysis FirstAndSecondOrderTransient
  extends TransientAnalysis(stop = 10.0)
  model = FirstAndSecondOrder()
end
```

Now we can run the analysis and plot the results:

```julia
result = FirstAndSecondOrderTransient()
plot(result)
```

This will produce a plot of the results.

You can also pass attributes to the plot function to customize the plot.

These attributes are documented in the Plots.jl docs as well as the SciML docs.

## Standard Plots Using the Plot Recipe

Plotting functionality is provided by recipes to Plots.jl. To
plot solutions of transient analyses, simply call the `plot(result)` after importing Plots.jl
and the plotter will generate appropriate plots.

```julia
#]add Plots # You need to install Plots.jl before your first time using it!
import Plots
Plots.plot(result) # Plots the solution
```

Many of the types defined in the DiffEq universe, such as
`ODESolution`, `ConvergenceSimulation` `WorkPrecision`, etc. have plot recipes
to handle the default plotting behavior. Plots can be customized using
[all the keyword arguments provided by Plots.jl](https://docs.juliaplots.org/stable/generated/attributes_plot/).
For example, we can change the plotting backend to the GR package and put a title
on the plot by doing:

```julia
plt = Plots.plot(result, title = "I Love DiffEqs!")
```

Then to save the plot, use `savefig`, for example:

```julia
Plots.savefig(plt, "myplot.png")
```

## Density

If the problem was solved with `dense=true`, then `denseplot` controls whether
to use the dense function for generating the plot, and `plotdensity` is the number
of evenly-spaced points (in time) to plot. For example:

```julia
Plots.plot(result, denseplot = false)
```

means “only plot the points which the solver stepped to”, while:

```julia
Plots.plot(result, plotdensity = 1000)
```

means to plot 1000 points using the dense function (since `denseplot=true` by
default).

## [Choosing Variables](@id plot_vars)

In the plot command, one can choose the variables to be plotted in each plot.  This is done by passing an `idxs` keyword argument.

You can pass symbolic indices or strings.  To fetch indices you can always get the model from `result.spec.model`.  Then you can pass e.g. `model.x`, `model.y`, etc.


Here are a few examples:

Choosing a variable
```julia
Plots.plot(result; idxs = model.x)
```

Multiple variables on the same plot:

```julia
Plots.plot(result; idxs = [model.x, model.y])
```

Phase plot

```julia
Plots.plot(result; idxs = (model.x, model.y))
```

Plot some expression on the solution:

```julia
Plots.plot(result; idxs = model.x + model.y)
```

Multiple variables in multiple plots

Shorthand:
```julia
Plots.plot(result; idxs = [model.x, model.y], layout = (2, 1))
```

Long form (more configurable):
```julia
plt = Plots.plot(result; idxs = model.x)
Plots.plot!(plt, result; idxs = model.y)
# ...
```

You can pass any Plots.jl kwarg like `linecolor` etc to the keyword arguments as long as it is in the correct and expected form.

