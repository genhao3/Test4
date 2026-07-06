---
description: "Learn about the syntax of Dyad with this reference guide."
---

# Syntax {#Syntax}

This section provides an overview of Dyad's syntax and language constructs.  It only briefly  touches on how to use them, and should be read as reference material for what you _can_ do.

Dyad files (`.dyad`) typically include [`component`](/manual/syntax#syntax-components) definitions and [`analysis`](/manual/syntax#syntax-analyses) definitions.  They may also includes [`using`](/manual/syntax#syntax-importing-libraries) statements when referencing external Julia packages.

In this syntax guide, we have placed all optional keywords in square brackets, with `|` separating the options.  For example, `[structural | final] parameter` means that the following syntax is supported:
- `parameter`

- `structural parameter`

- `final parameter`


## Connectors {#syntax-connectors}

Connectors define points of interaction between components.

### Composite Connector

Fields in composite connectors can be prefixed with `potential`, `flow`, `input`, `output`, `stream`, or `path` to specify their role in the connection semantics.

**Variable types:**
- `potential`: Across variable - equated across all connected connectors (e.g., voltage, pressure, temperature)
- `flow`: Through variable - sum to zero at connection points (e.g., current, mass flow, heat flow)
- `stream`: Intensive properties that flow with the medium - propagate based on flow direction using `instream()` (e.g., specific enthalpy, species concentration)
- `path`: Information shared throughout circuit topology - propagated using `continuity()` (e.g., medium type, fluid properties)
- `input`: Causal variable that receives values from outside
- `output`: Causal variable that provides values to the outside

See [Modeling of Fluid Systems in Dyad](modeling_fluid_systems.md) for a complete example of using `stream` and `path` variables.

```dyad
connector FluidPort
  potential p::Pressure               # Across variable (same at connection)
  flow m_flow::MassFlowRate           # Through variable (sum to zero at connection)
  stream h_outflow::SpecificEnthalpy  # Intensive property of flowing medium
  path medium::AbstractMedium         # Shared topology information
end

connector IOConnector
  input u::Real  # Input variable
  output y::Real # Output variable
end
```

### Scalar Connector

Scalar connectors can be defined only for `input` and `output` variable types.

```dyad
connector MyCustomInput = input MyCustomType   # causal input connector
connector MyCustomOutput = output MyCustomType  # causal output connector
```

> **Note on `input` as an identifier.** Since Dyad 3.0.0, `input` is a **contextual** keyword in the parser: it is only treated as a connector-field qualifier when it appears at the start of a connector field declaration. Elsewhere — variable names, parameter names, subcomponent names — `input` is a valid identifier and can be used freely (`variable input::Real`, `parameter input::Real = 1.0`, `input = SomeComponent()`). The companion keyword `output` is **not** contextual; it remains a reserved word and cannot be used as an identifier.

### Connector Parameters

A composite connector can also carry `parameter` and `structural parameter` declarations alongside its variable fields. Structural parameters are particularly useful for sizing connector arrays:

```dyad
connector ParameterizedOutputConnector
  "This controls the size of `y`"
  structural parameter N::Integer = 3
  parameter name::String = "bill"
  output y::Real[N]
end
```

When a connector with parameters is used as a subcomponent, the structural parameter is fixed at component creation time and shapes the connector's array fields. Non-structural parameters behave like regular component parameters — they can be overridden at instantiation.


## Components {#syntax-components}

Components are the fundamental building blocks in Dyad.  The are meant to capture mathematical behavior (causal, acausal or discrete) as a reusable component.  They may contain `variable`s, `parameter`s, `connector`s, subcomponents, and `relation`s.  Furthermore, they may `extend` from other components.

The component declaration may be prefixed with:
- `partial` to indicate that it is a partial component, which can be used as a base for other components,

- `example` to indicate that it is an example component to show what you can do with other components,

- `test` to indicate that it is a component used only for testing, and should not be exported.


Here is an example `component` definition:

```dyad
"Sample component"
component MyComponent
  # A component can have one or more extends clauses, like this one...
  extends BaseComponent
  "A normal parameter only results in a parametric change, not a structural change"
  parameter y::Real
  "A structural parameter is a parameter changes the number of equations or variables"
  structural parameter N::Integer = 10
  "Variables and parameters can have a number of different attributes"
  variable x::Real(min = 0, max = 10, units = "m")
  "Subcomponents are components nested inside other components forming hierarchical models"
  subcomponent = SomeComponent()
  "Connectors represent points of interaction between the components"
  p = Pin()
relations
  # One type of relation is an equation, like this one
  der(x) = y
  # Another type of relation is a connection
  connect(subcomponent.p, p)
end
```


### Component metadata {#Component-metadata}

Components can also have metadata, which is used by the UI, documentation tools, and codegen for some specific keys.  For example, you can specify the icon for a component in the metadata.

```dyad
component MyComponent
  # ...
metadata {
  "Dyad": {
    "icons": {"default": "dyad://YourComponentLibrary/icon.svg"}
  }
}
end
```


The `Dyad` namespace in metadata is reserved.  But all other namespaces can be used.  This allows application/user/customer specific metadata to be included in models.  An example use of metadata might be to include the corresponding physical part number in the component metadata.

#### Marking a definition as deprecated {#Component-metadata-deprecated}

Components, analyses, and connectors can be marked deprecated through the `Dyad.deprecated` metadata key. Library authors use this to flag definitions that should no longer be referenced; the kernel emits a `deprecated-usage` warning at every use site (including `extends` and subcomponent overrides). Both fields are optional.

```dyad
component OldComponent
metadata {
  "Dyad": {
    "deprecated": {
      "message": "Use NewComponent instead",
      "hotfix": { "action": "replace", "value": "MyLibrary.NewComponent" }
    }
  }
}
end
```

`message` surfaces in the warning text. `hotfix` (currently only `"action": "replace"`) tells tooling what to substitute the reference with. An empty `"deprecated": {}` is also valid — it produces a generic warning with no hotfix.

### Analyses {#syntax-analyses}

Analyses describe workflows that can be performed.  One way to think about this is the a `component` describes a problem while an `analysis` is something that ultimately leads to a "result" (some kind of computation typically performed on a `component` or perhaps even another `analysis`).

Examples of analyses might include:
- simulate a model over time with a TransientAnalysis,
- or even define and run a custom analysis using your own Julia code.

To write an analysis in Dyad you must extend from some existing analysis; ultimately all analyses are implemented in Julia.

```dyad
analysis MyAnalysis
  extends TransientAnalysis(abstol=0.001)
  model = CircuitModel()
relations
  # Relations between model and data
end
```

See [Dyad Analysis Reference](analyses.md) for more on different kinds of analyses.

### Importing libraries {#syntax-importing-libraries}

The `using` statement imports components, types, or other definitions from other packages. Crucially, these can be functions or variables from Julia as well as Dyad component libraries.

**Note:** The `using` syntax for importing functions with type annotations is not currently supported by the parser.

To use functions from external packages or your module, simply call them with the module prefix: `ModuleName.function(args)`. See [functions.md](functions.md) for complete details on using Julia functions in Dyad.

To import a component from another component library, it's sufficient to fully specify the component library and the name, like so:

```dyad
subcomponent = BlockComponents.Sources.SomeComponent()
```

All external libraries must be declared in the `Project.toml` file. Use the Julia tool to add missing dependencies with `Pkg.add(["MyLibrary1", "MyLibrary2"])`.
See [Julia's package manager documentation](https://pkgdocs.julialang.org/v1/) for more details.

### Variables {#syntax-variables}

Variables represent quantities that can change during simulation.  For variables of type `Real` you can define what units are associated with that variable, in which case Dyad will automatically check that the units are correct in every `relation` it is involved in.

```dyad
component MyComponent
  variable position::Real
  variable velocity::Real(units="m/s")
relations
  # ...
end
```

A variable declaration may include an equation form, an initial value, or both. The right-hand side after `=` selects the form:

```dyad
component MyComponent
  # Equation form — emits an equation `x = 0.0` that an extending component
  # can override (unless declared `final`).
  variable x::Real = 0.0
  # Initial-only — sets the initial condition at t=0 without adding an equation.
  # Use this for differential states.
  variable y::Real = initial 1.0
  # Both — equation `z = 0.0` plus initial condition `z(0) = 1.0`.
  variable z::Real = 0.0 initial 1.0
relations
  der(y) = -y
end
```

A variable modification has up to two parts: an equation form on the left of `initial`, and an initial-condition form on the right of `initial`. Either part can be a value, an expression, or `missing` (to drop the inherited form). What is accepted depends on whether the modification appears in an `extends` clause or in a subcomponent call.

#### Subcomponent call modifications

In `inner = Foo(...)`, each variable accepts the equation form, the initial form, or both, in any combination:

```dyad
inner_a = Foo(y = 5.0)                       # ✅ equation only
inner_b = Foo(y = initial 7.0)               # ✅ initial only
inner_c = Foo(y = 5.0 initial 7.0)           # ✅ both
inner_d = Foo(y = missing initial missing)   # ✅ drop both
inner_e = Foo(final y = 5.0)                 # ✅ promote to final
```

#### `extends` clause modifications

In `extends Foo(...)`, every variable modification must carry an equation form. An `initial …` form can ride along but cannot stand alone.

```dyad
extends Foo(y = 5.0)                         # ✅ equation only
extends Foo(y = 5.0 initial 7.0)             # ✅ equation and initial
extends Foo(y = missing initial 7.0)         # ✅ drop equation, override initial
extends Foo(y = missing)                     # ✅ drop equation, initial untouched
extends Foo(y = missing initial missing)     # ✅ drop both
extends Foo(final y = 5.0)                   # ✅ promote to final
```

Forms that are not valid in `extends`:

```dyad
extends Foo(y = initial 7.0)                 # ❌ initial only — silently dropped
extends Foo(y = initial missing)             # ❌ initial only — silently dropped
```


### Parameters {#syntax-parameters}

Parameters are values that remain fixed during a simulation, but can be changed between simulations.

```dyad
component MyComponent
  parameter mass::Mass = 1.0
  parameter length::Length = 0.5
  # Cannot be modified at all, even when constructing a new component
  final parameter id::Integer = 12345
  # See below for more on structural parameters.
  structural parameter N::Integer = 3
  # ...
end
```

`final` can also be added in an `extends` modification to lock a parameter at the extending component:

```dyad
component LockedDown
  extends MyComponent(final mass = 2.0)
end
```

`final` parameters become MTK bindings; non-`final` parameters are runtime MTK parameters.


#### Structural parameters {#syntax-structural-parameters}

Structural parameters are parameters whose changes might imply structural changes in the model. They are fixed at component creation time, and cannot be changed after the component is created.

The size of an array in a component can be defined by a literal integer or a structural parameter.

```dyad
component MyComponent
  "Number of elements"
  structural parameter N::Integer = 3
  "Array size depends on N"
  variable x::Real[N]
relations
  # ...
end
```


### Variable and Parameter Attributes {#syntax-variable-attributes}

Attributes are optional properties specified in parentheses after the type annotation. They control solver behavior, physical units, and value constraints.

```dyad
variable x::Real(units = "m", min = 0, max = 100)
parameter R::Real(units = "Ohm", min = 0) = 1.0
```

#### `Real` attributes

| Attribute        | Value Type | Description                   |
|------------------|------------|-------------------------------|
| `min`            | number     | Minimum value                 |
| `max`            | number     | Maximum value                 |
| `units`          | string     | Unit of measurement           |
| `quantity`       | string     | Physical quantity name        |
| `displayUnits`   | string     | Units for display purposes    |
| `guess`\*        | number     | Initial guess for the solver  |
| `statePriority`\*| integer    | Priority when choosing states |

#### `Integer` attributes

| Attribute      | Value Type | Description                  |
|----------------|------------|------------------------------|
| `min`          | integer    | Minimum value                |
| `max`          | integer    | Maximum value                |
| `units`        | string     | Unit of measurement          |
| `quantity`     | string     | Physical quantity name       |
| `displayUnits` | string     | Units for display purposes   |
| `guess`\*      | integer    | Initial guess for the solver |

#### `Boolean` attributes

| Attribute  | Value Type | Description                  |
|------------|------------|------------------------------|
| `quantity` | string     | Physical quantity name       |
| `guess`\*  | boolean    | Initial guess for the solver |

`String` and `Native` types do not accept any attributes.

\* **Variable-only.** `statePriority` is ignored for parameters — it influences state selection during index reduction (parameters are not part of the state vector). During code generation, these are emitted into MTK `@variables` metadata; e.g. `variable x::Real(statePriority = 10)` produces `@variables (x(t)::Real), [state_priority = 10]`.

**Note:** The `guess` attribute in variable declarations is currently not functional. Use `guess x = value` in the relations block instead.

#### The `final` keyword

Any attribute can be prefixed with `final` to prevent it from being overridden by subtypes or extending components:

```dyad
type Current = Real(final units = "A")
```

#### Attributes with type aliases

Type aliases from the standard library bundle a base type with default attributes. For example:

```dyad
type Velocity = Real(units = "m/s")
type AngularVelocity = Real(units = "rad/s")
```

When you write `variable v::Velocity(min = 0)`, `Velocity` resolves to `Real(units = "m/s")`, so this is equivalent to `variable v::Real(units = "m/s", min = 0)`. The attribute from the type alias is inherited and additional attributes are merged in.

### Continuity {#syntax-continuity}

`continuity` accepts list of path variables or connector field references.

```dyad
# `air_medium` flows through connecting_port
continuity(air_medium, connecting_port.medium)
# `port_a` and `port_b` are part of same continuity set
continuity(port_a.medium, port_b.medium)
```

It is used in hydraulic/fluid components to ensure that the medium (fluid properties) remains consistent across different ports of a component.

The `continuity` relation is essential for modeling physical systems where material properties must be preserved as they flow through components.

Note: `connect` implicitly defines continuity.


### Relations {#syntax-relations}

The `relations` block contains equations and other statements that define a component's behavior.

You can use `initial` in front of an equation to set the initial value of a variable (at the start time of the simulation).

Loops via `for` are supported, and can contain other relations within them. Note that they will be unrolled in Julia, so you shouldn't have extremely long loops here (O(10_000) and above) for performance reasons  (But they will still work!).

You can also use `connect` to connect `connector`s.  A `connect` call can have any number of arguments, and will connect all the listed `connector`s to each other.

```dyad
relations
  # Equations
  initial x = 0.0  # Initial condition
  der(x) = v      # Differential equation (dx/dt = v)
  F = m * der(v)  # Newton's law

  # Loops
  for i in 1:5
    initial array_of_components[i].x = 0.0
  end

  for i in 1:4
    connect(array_of_components[i].y, array_of_components[i+1].x)
  end

  # Connections
  connect(source.p, resistor.p)
  connect(resistor.n, ground.g)
end
```


### Expressions {#syntax-expressions}

Expressions are used to compute values in equations and other contexts.  They can be used in most any context where a value is expected (except for array sizes, which require literals, or parameter guesses).

Most expressions are pretty similar to Julia syntax - you can use  `+` for addition, `*` for multiplication, `^` for exponentiation, etc. as you would in most programming or modeling languages.

#### Operators {#syntax-operators}

Dyad supports a variety of operators for arithmetic and logical operations.  The operator precedence here is the [same as in Julia](https://docs.julialang.org/en/v1/manual/mathematical-operations/#Operator-Precedence-and-Associativity).

```
a + b            # Addition
a - b            # Subtraction
a * b            # Multiplication
a / b            # Division
a ^ b            # Power
a % b            # Modulo

a > b            # Greater than
a < b            # Less than
a >= b           # Greater than or equal
a <= b           # Less than or equal
a == b           # Equal
a != b           # Not equal

a and b          # Logical AND
a or b           # Logical OR
!a               # Logical NOT

a = b            # Assignment
```


#### Function calls {#syntax-function-calls}

Dyad supports calling functions with arguments.  You can also provide default values for arguments.

You can call any Julia function that is available in your component library.  That means anything  from Julia Base, or any packages you load _within that module_ (using `using`), or any functions  you define within that module.

You must import a function as shown in the [importing libraries](/manual/syntax#syntax-importing-libraries) section.

**📖 For comprehensive details on using functions in Dyad**, including:
- Where functions can be used (parameters, arrays, initial equations)
- How to use external Julia packages
- Replacing complex Modelica expressions
- Complete examples and limitations

See [functions.md](functions.md)

```
sin(angle)
atan2(y, x)
custom_func(data, tolerance=0.01)
```


#### Conditional expressions {#syntax-conditional-expressions}

Dyad uses the `ifelse()` function for conditional expressions. This function takes three arguments: a condition, a value for when the condition is true, and a value for when the condition is false.

```dyad
# Basic ifelse usage from BlockComponents/Sources/Step.dyad
y = ifelse(time >= start_time, height + offset, offset)

# Nested ifelse for multiple conditions from BlockComponents/Sources/Ramp.dyad
y = ifelse(start_time < time,
           ifelse(time < start_time + duration,
                  offset + (time - start_time) * height / duration,
                  offset + height),
           offset)

# Complex nested example from ElectricalComponents/Analog/Basic/NonlinearResistor.dyad
i = ifelse(v < -Ve, Gb*(v+Ve) - Ga*Ve,
           ifelse(v > Ve, Gb*(v-Ve) + Ga*Ve,
                  Ga*v))
```
See functions.md on how to create even more complicated conditionals using arrays and Julia functions!

#### Literals {#syntax-literals}

```dyad
x = 10           # Integer
y = 3.14         # Real number
z = 1.5e-3       # Scientific notation
R = 10k          # With metric prefix (10 kilo => 10 * 10e3 => 10,000)
text = "Hello"   # String
flag = true      # Boolean
```


#### Time {#syntax-time}

Dyad supports a `time` variable, which is a special variable that represents the current time of the simulation.

Here is a step function that changes at `t=10`:

```dyad
v = ifelse(time < 10, 0, 1)
```


You can use `time` anywhere you could use a variable.  For example, here's an expression that switches from sine to cosine at `t=10`:

```dyad
v = ifelse(time < 10, sin(time), cos(time))
```


### Arrays {#syntax-arrays}

Arrays can be used for variables, parameters, and other data structures.

```dyad
parameter vector::Real[3] = [1, 2, 3]
variable matrix::Real[2, 2]
variable pos::Position[3]  # 3D position vector
```


Array comprehensions can initialize arrays of components:

```dyad
resistors = [Resistor(R=i*10) for i in 1:5]  # Array of 5 resistors
```

**⚠️ Important:** Array comprehensions work ONLY for component arrays, NOT for parameter arrays.

The size of an array can be defined by a literal integer or a `structural parameter`, but cannot vary at runtime and any change to a structural parameter will require that the model undergo symbolic processing again.

**📖 For complete array documentation**, including:
- Initialization methods (literals, fill, functions returning arrays)
- Why parameter array comprehensions don't work
- Working with multidimensional arrays
- Common patterns and solutions

See [arrays.md](arrays.md)

### Control flow {#syntax-control-flow}

#### Conditional expressions in relations {#syntax-conditional-in-relations}

For conditional logic in relations, Dyad uses the `ifelse()` function. This allows you to create conditional expressions within equations. The `ifelse()` function evaluates to different values based on a condition, maintaining the continuous nature of the mathematical model.

```dyad
# From BlockComponents/Sources/Step.dyad - A step function that changes at start_time
relations
  y = ifelse(time >= start_time, height + offset, offset)
end

# From DyadExampleComponents/stopper.dyad - Conditional force application
relations
  f = ifelse((s_a >= s_b), (v_a - v_b)*d + c*(s_a - s_b), 0)
end

# From BlockComponents/Sources/Ramp.dyad - Multiple conditions with nested ifelse
relations
  y = ifelse(start_time < time,
             ifelse(time < start_time + duration,
                    offset + (time - start_time) * height / duration,
                    offset + height),
             offset)
end
```

Note that both branches of the `ifelse()` must produce values of the same type, and the function is evaluated continuously during simulation.
<!--


#### States and transitions {#syntax-states-and-transitions}

Components can define state machines:

```dyad
component TrafficLight
  output current_light::LightColor

  initial state Red
    current_light := Red
  end
  state Yellow
    current_light := Yellow
  end
  state Green
    current_light := Green
  end
relations
  transition(Red => Green, timeInState() > 10)
  transition(Green => Yellow, timeInState() > 15)
  transition(Yellow => Red, timeInState() > 3)
end
```

-->


### Metadata {#syntax-metadata}

Metadata attaches additional information to model elements for documentation, UI hints, or tool-specific data.  Metadata is organized into namespaces.  The `Dyad` namespace is reserved, but other namespaces can be used to manage any kind of structured (JSON) data, _e.g.,_

```dyad
component MyComponent
  parameter x::Real = 1.0
metadata {
  "Dyad": {
    "icons": {
      "default": "dyad://MyLibrary/my_component.svg"
    }
  }
}
end
```


For associating metadata with a definition, or...

```dyad
component WithInlineMetadata
  p = Pin() [{ "Dyad": { "iconName": "pos" } }]
end
```


For associating metadata with individual components, connectors, variables, _etc_.

### Docstrings {#docstrings}

Multiline docstrings use tripple quotes `"""..."""`
Single-line docstrings use single quotes `"..."`.

```dyad
"""
Dyad supports multiline docstrings.
These are used to describe a component's physics, references and other relevant details.
"""
component Hello
  "Single quotes are used to add single line descriptive strings"
  parameter greet::Boolean = true
end
```

### Agent Comments

Dyad supports temporary comments while implementing models. These are catered to agents to plan the implementation.
These comments begin with `#`. For multiline comments, begin each new line with `#`.

NOTE: Dyad compiler drops the agent-comments when formatted. See [Docstrings](@ref#docstrings) section for adding persistent documentation.

```dyad
component Heater
  # I need to add thermal subcomponents
  "Thermal connector"
  port = HeatPort()
  # I need to add electrical subcomponents
  "Electrical connector"
  pin = Pin()
relations
  # I need to research on a Heater's physics
end
```

