
# Enums and Conditional Initialization

Dyad provides enums with switch-case statements to handle complex conditional initialization scenarios, particularly useful for models with multiple initialization modes.

## Enum Definition

Enums define a type with a finite set of named variants. Each variant can optionally carry typed fields:

```dyad
# Simple enum without fields
enum InitMode = 
  | SteadyState
  | Transient
  | FromFile

# Enum with fields (Note: field access has limitations - see below)
enum InitWithData = 
  | Default
  | WithValues(x0::Real, y0::Real)
  | FromArray(values::Real[3])
```

## Using Switch-Case for Conditional Initialization

The `switch` statement allows different initialization paths based on an enum value:

```dyad
component ConditionalInit
  "Must be structural parameter for compile-time optimization"
  structural parameter init_mode::InitMode = InitMode.SteadyState

  # Regular parameters for initialization values
  "Initial value for x"
  parameter x_init::Real = 10.0
  "Initial value for y"
  parameter y_init::Real = 20.0

  variable x::Real
  variable y::Real

relations
  switch init_mode
    case SteadyState
      # Initialize derivatives to zero for steady state
      initial der(x) = 0
      initial der(y) = 0

    case Transient
      # Initialize with specific values
      initial x = x_init
      initial y = y_init

    case FromFile
      # Initialize with default values (file loading not shown)
      initial x = 0
      initial y = 0
  end

  # Regular equations follow
  der(x) = -x + y
  der(y) = x - 2*y
end
```

## Important Limitations

### Field Access in Enum Variants
While enum variants can have fields, **accessing these fields within switch cases is currently not supported** by the Dyad compiler. This means:

```dyad
# This WILL compile - fields are defined
enum InitData = Fixed(x::Real, y::Real)

# But this will NOT work - cannot access fields
switch init
  case Fixed
    initial x = init.x  # ERROR: Cannot access field
end
```

**Workaround**: Use separate parameters for initialization data:

```dyad
component WorkingExample
  structural parameter mode::InitMode = InitMode.Fixed
  # Use regular parameters for data
  "Initial x value"
  parameter x_value::Real = 10.0
  "Initial y value"
  parameter y_value::Real = 20.0

  variable x::Real
  variable y::Real

relations
  switch mode
    case Fixed
      initial x = x_value  # Use parameter, not enum field
      initial y = y_value
  end
end
```

## How It Works Under the Hood

When Dyad compiles switch-case statements for initialization:

1. **Enum types** are converted to algebraic data types using Julia's pattern matching capabilities
2. **Switch statements** become pattern matching expressions that execute different code paths
3. **Initial equations** within cases are collected into initialization equation arrays
4. **Structural parameters** ensure the enum value is known at compile time, allowing optimization

The compiler generates:
- `initial x = value` → Sets default/initial values
- `initial der(x) = 0` → Adds initialization equations for derivatives
- Array initialization with loops is unrolled at compile time

## Practical Example: Heat Conduction with Multiple Modes

```dyad
enum ThermalInitMode =
  | Equilibrium
  | LinearGradient
  | StepChange

component ThermalLayer
  "Number of temperature nodes"
  structural parameter N::Integer = 5
  "Initialization mode selector"
  structural parameter init_mode::ThermalInitMode = ThermalInitMode.Equilibrium

  # Separate parameters for initialization data
  "Left boundary temperature"
  parameter T_left::Real = 293.15
  "Right boundary temperature"
  parameter T_right::Real = 303.15
  "Uniform temperature for equilibrium mode"
  parameter T_uniform::Real = 298.15

  "Temperature at each node"
  variable T::Real[N]

relations
  switch init_mode
    case Equilibrium
      # All nodes at uniform temperature
      for i in 1:N
        initial T[i] = T_uniform
      end

    case LinearGradient
      # Linear temperature distribution
      for i in 1:N
        initial T[i] = T_left + (T_right - T_left) * (i-1)/(N-1)
      end

    case StepChange
      # Step change in middle
      for i in 1:N
        initial T[i] = ifelse(i <= N/2, T_left, T_right)
      end
  end

  # Heat conduction equations...
end
```

## Best Practices

1. **Always use structural parameters** for enum-valued initialization modes
2. **Keep initialization data in regular parameters** due to field access limitations
3. **Use descriptive enum variant names** that clearly indicate the initialization strategy
4. **Document each initialization mode** with physical meaning
5. **Test each mode separately** to ensure proper initialization

## When to Use This Pattern

This pattern is particularly valuable when one needs case like initialization logic. Use it when you have:

- Multiple distinct initialization strategies
- Configuration-dependent initial conditions  
- Different physical scenarios requiring different starting states
- Models that need both steady-state and transient initialization options

The enum-based approach provides clear, maintainable code where initialization modes are explicit and type-safe.

## Related Documentation

- **[initialization.md](initialization.md)** - General initialization techniques and debugging
- **[functions.md](functions.md)** - Using Julia functions for complex initialization calculations
- **[arrays.md](arrays.md)** - Initializing arrays with conditional logic
- **[syntax.md](syntax.md)** - Complete syntax reference including control flow