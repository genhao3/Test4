---
description: Guide to working with datasets, interpolation, and data sources in Dyad
---

# Working with Data

DyadData offers three main types of datasets:

- **`DyadTimeseries`**: For time-series data with an independent variable (typically time) and one or more dependent variables. Use this for driving model inputs over time or validating model outputs against experimental data.
- **`DyadTable`**: For general tabular data with named columns, useful for steady-state calibration data or multi-row tables.
- **`DyadInterpolationTable2D`**: For 2D lookup tables where a value depends on two independent variables (e.g., damper force as a function of velocity and temperature).

## Data Sources

Datasets can be loaded from multiple sources using URI strings:

| URI Scheme | Example | Description |
|------------|---------|-------------|
| `dyad://` | `"dyad://MyPackage/data.csv"` | **Recommended.** References files in a package's `assets/` folder. Portable across machines. |
| `file://` | `"file://data.csv"` or `"file:///absolute/path/data.csv"` | Local files. Supports both relative and absolute paths, but less portable than `dyad://`. |
| `dyad+juliahub://` | `"dyad+juliahub://juliahub.com/datasets/user/name"` | JuliaHub datasets for collaborative work. |

Using `dyad://` URIs is recommended over `file://`.

## Interpolation Components

The BlockComponents library provides interpolation components to use datasets in your models:

| Component | Use Case |
|-----------|----------|
| `Interpolation` | 1D interpolation from a dataset. The interpolator is fixed at construction time. |
| `ParameterizedInterpolation` | 1D interpolation from a dataset, with data exposed as tunable parameters for runtime modification. |
| `InterpolatedTable` | 2D interpolation for lookup tables with two independent variables. |

### Interpolation Types (1D)

The `Interpolation` and `ParameterizedInterpolation` components accept an `interpolation_type` parameter from the `InterpolationType` enum. These types map to interpolation methods from [DataInterpolations.jl](https://docs.sciml.ai/DataInterpolations/stable/methods/):

| Type | Description |
|------|-------------|
| `ConstantInterpolation()` | Step-wise constant interpolation. Maintains the value from the left data point until the next point. |
| `SmoothedConstantInterpolation()` | Similar to constant interpolation but with smooth transitions between values. Continuously differentiable. |
| `LinearInterpolation()` | Linear interpolation between adjacent data points. The most common choice for general-purpose interpolation. |
| `QuadraticInterpolation()` | Fits parabolas through nearest points. Continuously differentiable. |
| `LagrangeInterpolation(n)` | Fits a polynomial of degree `n` through the data points. Higher degrees capture more complex patterns but may oscillate. |
| `QuadraticSpline()` | Piecewise quadratic curves that pass through all data points exactly. Continuous first derivative. |
| `CubicSpline()` | Cubic spline interpolation. Twice continuously differentiable. Good balance of smoothness and accuracy. |
| `AkimaInterpolation()` | Piecewise cubic polynomials using only neighboring points. Avoids overshooting and oscillation common in global methods. |

### Extrapolation Types

Both `Interpolation` and `ParameterizedInterpolation` accept an optional `extrapolation_type` parameter that controls behavior when the input is outside the data range. The default is `ExtrapolationType.None()`.

| Type | Description |
|------|-------------|
| `ExtrapolationType.None()` | Throws an error when the input is outside the data range. **(Default)** |
| `ExtrapolationType.Constant()` | Extends the interpolation with the boundary values of the data. |
| `ExtrapolationType.Linear()` | Extends the interpolation with a linear continuation, making it C¹ smooth at the data boundaries. |
| `ExtrapolationType.Extension()` | Extends the interpolation with a continuation of the boundary interval expression for maximum smoothness. |
| `ExtrapolationType.Periodic()` | Wraps the interpolation periodically, so `A(t + T) == A(t)` where `T` is the data range. |
| `ExtrapolationType.Reflective()` | Mirrors the interpolation at the data boundaries. |

### Interpolation Dimensions (2D)

The `InterpolatedTable` component uses `InterpolationDimension` to specify the interpolation method for each axis. These types map to methods from [DataInterpolationsND.jl](https://sciml.github.io/DataInterpolationsND.jl/stable/usage/):

| Type | Description |
|------|-------------|
| `LinearInterpolationDimension()` | Linear interpolation along this axis. The most common choice. |
| `ConstantInterpolationDimension()` | Step-wise constant interpolation along this axis. |
| `BSplineInterpolationDimension(n)` | B-spline interpolation with maximum derivative order `n`. Provides smooth curves with configurable smoothness. |

## Examples

### 1D Interpolation from a Timeseries

This example shows how `BlockComponents.Tables.Interpolation` can be used in a spring damper system to integrate recorded measurements into the model. The `DyadTimeseries` loads the CSV and specifies which columns to use, and the `Interpolation` component extracts the columns internally.

```dyad
component SpringDamperSystem
  # Parameters
  parameter m::Mass = 1.0
  parameter c::TranslationalSpringConstant = 10.0
  parameter d::TranslationalDampingConstant = 2.0

  # State variables
  variable x::Position
  variable v::Velocity

  # Load force vs time data from file
  structural parameter force_dataset::DyadData.DyadTimeseries = DyadData.DyadTimeseries(
    "dyad://InterpolationDemo/force_time.csv",
    independent_var = "timestamp",
    dependent_vars = ["force"]
  )

  # Create interpolation block from dataset
  force_interp = BlockComponents.Tables.Interpolation(
    interpolation_type = BlockComponents.Tables.InterpolationType.LinearInterpolation(),
    dataset = force_dataset
  )

  variable F_applied::Force

relations
  F_applied = force_interp.y
  force_interp.u = time

  # Kinematics
  v = der(x)

  # Dynamics: m*a = F_applied - c*x - d*v
  m * der(v) = F_applied - c * x - d * v
end
```

Connect `force_interp.u` to `time` and read the interpolated value from `force_interp.y`. The interpolator is computed once at construction time and cannot be changed at runtime.

### 2D Table Lookup

For cases where a value depends on two independent variables, use `BlockComponents.Tables.InterpolatedTable` with a `DyadInterpolationTable2D`. The table specifies names for its two axes and the data column, which are accessed via string indexing.

```dyad
component TemperatureDependentDamper
  parameter m::Mass = 1.0
  parameter k::TranslationalSpringConstant = 100.0

  variable x::Position
  variable v::Velocity
  variable T::Temperature
  variable F_damper::Force

  # Load 2D lookup table
  structural parameter input_file::String = "dyad://InterpolationDemo/damper_table.csv"
  structural parameter damper_table::DyadData.DyadInterpolationTable2D = DyadData.DyadInterpolationTable2D(
    input_file,
    axis1_name = "velocity",
    axis2_name = "temperature",
    data_name = "damping_force"
  )

  # 2D interpolation
  damper_interp = BlockComponents.Tables.InterpolatedTable(
    axis1 = damper_table["velocity"],
    axis2 = damper_table["temperature"],
    data = damper_table["damping_force"],
    interpolation_dim1 = BlockComponents.Tables.InterpolationDimension.LinearInterpolationDimension(),
    interpolation_dim2 = BlockComponents.Tables.InterpolationDimension.LinearInterpolationDimension()
  )

relations
  damper_interp.u1 = v
  damper_interp.u2 = T
  F_damper = damper_interp.y

  # Temperature varies with time
  T = 300.0 + 50.0 * sin(2*pi*0.1*time)

  v = der(x)
  m * der(v) = -k * x - F_damper
end
```

`InterpolatedTable` has two inputs (`u1`, `u2`) and one output (`y`). Each dimension can have its own interpolation method.

## Using DyadData in Julia Code

### DyadTimeseries

`DyadTimeseries` handles time-series data with an independent variable and one or more dependent variables. You can construct one from a URI or from raw data:

```julia
# From a URI
ts = DyadTimeseries(
    "dyad://PackageName/data/measurements.csv";
    independent_var = "timestamp",
    dependent_vars = ["x", "y"]
)

# From raw data
data = rand(10, 3)
ts = DyadTimeseries(data; independent_var="time", dependent_vars=["x", "y"])
```

Access individual columns by name using string indexing:

```julia
time_values = ts["timestamp"]
x_values = ts["x"]
```

### DyadTable

`DyadTable` is used for general tabular data with named columns. Like `DyadTimeseries`, it can be constructed from a URI or from raw data:

```julia
# From a URI
tbl = DyadTable(
    "dyad://PackageName/calibration.csv";
    columns = ["param1", "param2", "param3"]
)

# From raw data (single row, e.g., steady-state data)
steady_state = DyadTable([1.0, 2.0, 3.0]; columns=["x", "y", "z"])

# From raw data (multiple rows)
data = rand(10, 3)
tbl = DyadTable(data; columns=["x", "y", "z"])
```

Access columns by name using string indexing:

```julia
param1_values = tbl["param1"]
```

### Working with Tables

Use `build_table()` to convert a dataset into a TypedTables `Table` for advanced operations like filtering, joining, or aggregation:

```julia
ts = DyadTimeseries("file:///path/to/data.csv";
                    independent_var="time",
                    dependent_vars=["x", "y"])

table = build_table(ts)  # Returns a Table from TypedTables.jl
```

For more on table operations, see the [TypedTables.jl documentation](https://typedtables.juliadata.org/stable/man/table/).

### CSV Options

You can pass additional keyword arguments to customize CSV reading. For example, to read tab-separated values:

```julia
ts = DyadTimeseries("file:///path/to/data.tsv";
                    independent_var="time",
                    dependent_vars=["x", "y"],
                    delim='\t')
```

See the [CSV.jl documentation](https://csv.juliadata.org/stable/reading.html) for all available options.

### Helper Functions

Each dataset type provides helper functions for inspecting its structure:

```julia
# DyadTimeseries
get_independent_var(ts)  # Returns the independent variable name
get_dependent_vars(ts)   # Returns the dependent variable names

# DyadTable
get_columns(tbl)         # Returns the column names
```

## Key Points

- When specifying the enum to use in interpolation, use `interpolation_type = BlockComponents.Tables.InterpolationType.<InterpolatorType>()`.
- The interpolation type needs to be fully namespaced for all cases.
- The `Interpolation` component takes a `dataset` parameter and extracts the columns internally.
