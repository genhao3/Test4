# Using Julia Functions in Dyad

Dyad allows you to use Julia functions, providing a clean way to write declarations of complicated parameter and initial condition values.

## Where Functions Can Be Used

Functions can be called in contexts where values are assigned:
- Parameter definitions (single values and arrays)
- Initial conditions (not equations - Dyad only supports direct assignment)
- Regular equations/relations

## Basic Usage

You can call any Julia function available in your component library: Julia Base functions, imported packages, or custom functions defined in your module:

```dyad
component MyComponent
  structural parameter N::Integer = 5
  parameter p::Real = calculate_value(2.0, 3.0)
  parameter arr::Real[3] = [sin(1.0), sin(2.0), sin(3.0)]  # Simple arrays work
  # Note: Array comprehensions with functions [f(i) for i in 1:N] don't currently work
  variable x::Real

relations
  initial x = compute_initial(10.0, 20.0)
  der(x) = dynamic_calc(x)
end
```

## Using Functions from External Packages

**Note:** The `using` import syntax for functions is not currently supported by the parser.

Instead, to use functions from external packages:
1. Add the package to your `Project.toml`: `Pkg.add("PackageName")`
2. Import it in your Julia module: `using PackageName`
3. Call functions with the package prefix: `PackageName.function(args)`

Functions from your own module don't need any import - just call them with the module prefix.

## Defining Custom Helper Functions - Step by Step

### Method 1: Functions in the Module File (Simple)

For simple functions, define them directly in your module file:

```julia
# In src/MyLibraryName.jl
module MyLibraryName

# Step 1: Import any external packages you need
using DataFrames
using CSV

# Step 2: Define your functions BEFORE the generated include
function calculate_value(x::Real, y::Real)::Real
    return x + y * 2
end

# Step 3: Include generated code AFTER function definitions
include("../generated/module.jl")
end
```

### Method 2: Functions in Separate Files (Recommended for Complex Logic)

For better organization, put functions in separate files:

**Step 1: Create your function file**
```julia
# In src/thermal_calculations.jl
function calculate_mass_array(A, x, d, N, surf_a, surf_b)
    base_mass = A * x * d
    if surf_a && surf_b
        if N == 2
            return base_mass * fill(1/(2*(N-1)), N)
        else
            factors = [i == 1 || i == N ? 1/(2*(N-2)) : 1/(N-2) for i in 1:N]
            return base_mass * factors
        end
    else
        return base_mass * fill(1/N, N)
    end
end

function compute_initial_temperature(ambient::Real, offset::Real)::Real
    return ambient + offset
end
```

**Step 2: Include the function file in your module**
```julia
# In src/MyLibraryName.jl
module MyLibraryName

# Include your function files BEFORE the generated code
include("thermal_calculations.jl")
include("other_helpers.jl")  # You can have multiple files

# IMPORTANT: Generated code comes AFTER all includes
include("../generated/module.jl")
end
```

**Step 3: Use the functions in your Dyad components**
```dyad
component ThermalMass
  parameter masses::Real[5] = MyLibraryName.calculate_mass_array(
    1.0, 0.1, 1000.0, 5, true, true)
  variable T::Temperature
relations
  initial T = MyLibraryName.compute_initial_temperature(293.15, 10.0)
end
```

### Key Points to Remember

1. **Function location**: Functions must be defined or included BEFORE `include("../generated/module.jl")`
2. **Namespace usage**: Always call functions with the module prefix: `MyLibraryName.function_name()`
3. **No imports needed**: Functions in the same module don't need import statements in Dyad
4. **External packages**: Must be in Project.toml and imported in the Julia module file

## Real-World Example: Re-writing Complex Parameter Array Declarations

```modelica
parameter Mass m[n] = (A*x*d)*(if (surf_a and surf_b) then
  if (n == 2) then {1/(2*(n-1)) for i in 1:n}
  else {1/(if i == 1 or i == n then (2*(n-2)) else (n-2)) for i in 1:n}
  else {1/n for i in 1:n})
```

Use a clean function call in Dyad:

```dyad
component ThermalMass
  structural parameter N::Integer = 5
  parameter A::Real = 1.0
  parameter material_x::Real = 0.1
  parameter material_d::Real = 1000.0
  parameter surface_a::Boolean = true
  parameter surface_b::Boolean = true

  "Mass array computed from material properties"
  parameter m::Real[N] = calculate_mass_array(
    A, material_x, material_d, N, surface_a, surface_b)
end
```

## Important Limitations

1. **Functions must return single values or arrays** - No multiple return values (tuples)
2. **Array comprehensions with functions don't work** - Use simple arrays instead
3. **No implicit initial equations** - Only direct assignment like `initial x = value`

## Best Practices

1. **Keep functions pure** - No side effects, deterministic results
2. **Type annotations** - Use `::Real`, `::Int`, `::Bool` for clarity
3. **Document complex logic** - Add comments explaining the calculation
4. **Test separately** - Verify function output before using in components

## Summary

Julia functions in Dyad provide a powerful way to:
- Replace complex conditional expressions
- Compute parameter and initial condition arrays with sophisticated logic
- Keep component definitions clean and readable
- Reuse calculation logic across multiple components


This feature bridges the gap between other declarative style acausal modeling languages and the need for complex initialization logic in real-world models.