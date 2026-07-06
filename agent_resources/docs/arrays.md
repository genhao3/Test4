---
description: Guide to arrays in Dyad - declaration, initialization, and usage
---

# Arrays in Dyad

Arrays allow working with collections of variables, parameters, and components. Array sizes must be defined using literal integers or structural parameters and cannot change during simulation.

## Declaration

```dyad
component ArrayBasics
  # Size with literals or structural parameters
  structural parameter N::Integer = 5

  # Single and multi-dimensional arrays
  variable x::Real[5]                    # 1D array
  variable matrix::Real[3, 3]            # 2D matrix
  variable data::Real[N]                 # Size from structural parameter
  parameter temps::Temperature[N]        # Typed array
relations
  # ...
end
```
## Initialization

### Direct Initialization
```dyad
parameter vec::Real[3] = [1.0, 2.0, 3.0]              # Literal values
parameter sequence::Real[11] = 0:0.1:1                # Range syntax (0.0 to 1.0)
parameter matrix::Real[2, 2] = [[1, 2], [3, 4]]       # 2D array
```

### Using Fill
```dyad
structural parameter N::Integer = 10
parameter ones::Real[N] = fill(1.0, N)                # All elements = 1.0
parameter zeros::Real[N, N] = fill(0.0, N, N)         # N×N matrix of zeros
```

### Array Comprehensions
```dyad
# Comprehensions only work for COMPONENT arrays, not parameters
resistors = [Resistor(R=i*10) for i in 1:N]           # ✅ Component array

# Parameter arrays do NOT support comprehensions
# parameter squares::Real[N] = [i^2 for i in 1:N]    # ❌ DOESN'T WORK
```

**Important:** Array comprehensions in Dyad are limited to component arrays only. For parameter arrays, use:
- Explicit literals: `[1.0, 2.0, 3.0]`
- Fill function: `fill(1.0, N)`
- Functions that return arrays: `MyModule.generate_array(N)`

## Working with Arrays

### Indexing (1-based)
```dyad
relations
  result = data[1]                  # First element
  matrix[2, 3] = 5.0                # Row 2, column 3
end
```

### Loops in Relations
```dyad
relations
  # Initialize all elements
  for i in 1:N
    initial x[i] = i * 0.1
  end

  # Element-wise operations
  for i in 1:N
    y[i] = 2 * x[i] + 1
  end

  # Nested loops for matrices
  for i in 1:3
    for j in 1:3
      C[i, j] = A[i, j] + B[i, j]
    end
  end
end
```

### Connecting Component Arrays
```dyad
component ChainedMasses
  structural parameter N::Integer = 4

  masses = [Mass(m=1.0) for i in 1:N]
  springs = [Spring(c=100.0) for i in 1:(N-1)]

relations
  # Connect in chain
  for i in 1:(N-1)
    connect(masses[i].flange_b, springs[i].flange_a)
    connect(springs[i].flange_b, masses[i+1].flange_a)
  end
end
```

## Complete Example: Thermal Discretization

```dyad
component ThermalLayer
  structural parameter nNodes::Integer = 5

  port_a = HeatPort()
  port_b = HeatPort()

  # Material properties
  "Thermal conductivity"
  parameter k::ThermalConductivity = 200.0
  "Layer thickness"
  parameter thickness::Length = 0.01
  "Cross-sectional area"
  parameter area::Area = 0.01

  # Arrays for discretized model
  "Temperature at each node"
  variable T::Temperature[nNodes]
  "Heat flow rate between nodes"
  variable Q_flow::HeatFlowRate[nNodes+1]

  # Derived parameters
  "Thermal resistance per segment"
  parameter R_segment::ThermalResistance = thickness/(nNodes * k * area)
  "Heat capacity per node"
  parameter C_node::HeatCapacity = 100.0

relations
  # Boundary connections
  port_a.Q_flow = Q_flow[1]
  port_b.Q_flow = -Q_flow[nNodes+1]

  # Heat flow between nodes
  Q_flow[1] = (port_a.T - T[1]) / R_segment
  for i in 2:nNodes
    Q_flow[i] = (T[i-1] - T[i]) / R_segment
  end
  Q_flow[nNodes+1] = (T[nNodes] - port_b.T) / R_segment

  # Energy balance at each node
  for i in 1:nNodes
    C_node * der(T[i]) = Q_flow[i] - Q_flow[i+1]
  end

  # Initial linear temperature distribution
  for i in 1:nNodes
    initial T[i] = 293.15 + 10.0 * (i-1) / (nNodes-1)
  end
end
```

## Common Pitfalls and Solutions

### ❌ Parameter array comprehensions not supported
```dyad
# WRONG - Parser doesn't support comprehensions for parameters
parameter vals::Real[N] = [i^2 for i in 1:N]         # ❌ DOESN'T WORK
parameter vals::Real[N] = [ifelse(i < 3, i*2, i*3) for i in 1:N]  # ❌ DOESN'T WORK

# CORRECT - Use alternatives:
# Option 1: Explicit literals
parameter vals::Real[5] = [1, 4, 9, 16, 25]

# Option 2: Fill for uniform values
parameter vals::Real[N] = fill(0.0, N)

# Option 3: Function that returns array
parameter vals::Real[N] = MyModule.generate_squares(N)

# Option 4: Initialize in relations (for variables only)
variable vals::Real[N]
relations
  for i in 1:N
    initial vals[i] = i^2
  end
```

### ✅ Function calls in parameter arrays
```dyad
# Functions CAN be used if they return arrays
parameter vals::Real[N] = MyModule.compute_values(N)

# Still valid - fill function
parameter vals::Real[N] = fill(1.0, N)
```

### ❌ Function calls inside array literals not supported
```dyad
# The parser does NOT allow function calls as elements of an array literal:
parameter arr::Real[3] = [MyModule.func(1.0),
                          MyModule.func(2.0),
                          MyModule.func(3.0)]   # ❌ parse error
```
Use a helper Julia function that returns the whole array (see above) instead.

## Key Points

- Arrays use 1-based indexing
- Sizes must be literal integers or structural parameters
- Array comprehensions require single line, simple expressions
- Complex initialization belongs in relations, not declarations
- Structural parameter changes require recompilation
- All array elements must have the same type