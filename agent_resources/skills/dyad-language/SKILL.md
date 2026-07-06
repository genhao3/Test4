---
name: dyad-language
description: Dyad language reference for writing components, test harnesses, and analyses. Covers syntax, initialization, component libraries, and accessing results in Julia. Load when building, editing, or reading any Dyad model.
---

# Dyad Language Reference

Dyad is a declarative acausal modeling language that compiles to ModelingToolkit. Component names, ports, and parameters are identical in both Dyad syntax and Julia/MTK.

## Documentation index

For advanced features, read the appropriate file from `agent_resources/docs/`:
- syntax.md — full language constructs, expressions, control flow
- libraries.md — package management, namespacing rules
- library_namespacing.md — namespacing rules for components and connectors from libraries and sub-libraries
- initialization.md — differential vs algebraic initialization details
- analyses.md — all analysis types (transient, steady-state, linear, calibration, FMU)
- connectors.md — connector types and custom connector definitions
- arrays.md, functions.md, enums.md, data.md — task-specific references
- components.md — component patterns, partial components, extends

## Component structure

```dyad
component MyComponent
  extends ElectricalComponents.Analog.Interfaces.OnePort   # Inherit interface
  parameter R::Resistance = 1.0          # Fixed parameter with units
  variable v::Voltage
relations
  initial i = 0.0                        # Differential state at t=0
  guess v = 5.0                          # Algebraic solver hint
  v = i * R                              # Algebraic equation
  connect(port_a, port_b)               # Connection between ports
end
```

## Test harness and analysis

```dyad
test component TestMyComponent
  source = ElectricalComponents.Analog.Sources.VoltageSource(V=10.0)
  comp = MyComponent(R=2.0)
  ground = ElectricalComponents.Analog.Basic.Ground()
relations
  connect(source.p, comp.p)
  connect(comp.n, ground.g)
  connect(source.n, ground.g)
end

analysis TestTransient
  extends TransientAnalysis(stop=1e-3)
  model = TestMyComponent()
end
```

## Running an analysis and accessing results

After compiling with `compile_tool`, run and validate in `julia_tool`:

```julia
using ProjectName
using DyadInterface

result = TestTransient()
sol = result.sol
model = symbolic_container(result)
```

- `sol[model.comp.v]` — extract time series
- `sol(t, idxs=model.comp.v)` — interpolate at specific time

## Initialization

- `initial x = value` — for variables with `der(x)` in equations (differential states)
- `guess x = value` in the relations block — for algebraic variables in simultaneous equations
- `variable x::Real = initial value` — declare the initial condition inline on the variable
- `variable x::Real = expr initial value` — default-binding equation plus an initial condition

## Modifications in extends and subcomponents

A variable modification has two parts: an **equation form** (left of `initial`) and an **initial form** (right of `initial`). Each part is a value, an expression, or `missing` to drop the inherited form. `final` may prefix any modification to lock it.

Subcomponent calls (`inner = Base(...)`) accept any combination:

- ✅ `inner = Base(p = 5.0)` — equation
- ✅ `inner = Base(y = initial 7.0)` — initial only
- ✅ `inner = Base(y = 5.0 initial 7.0)` — both
- ✅ `inner = Base(y = missing)` — drop equation
- ✅ `inner = Base(y = missing initial missing)` — drop both
- ✅ `inner = Base(final p = 5.0)` — promote to `final`

`extends` clauses require an equation form on every variable modification:

- ✅ `extends Base(p = 5.0)` — equation
- ✅ `extends Base(y = 5.0 initial 7.0)` — equation + initial
- ✅ `extends Base(y = missing initial 7.0)` — drop equation, override initial
- ✅ `extends Base(y = missing)` — drop equation
- ✅ `extends Base(y = missing initial missing)` — drop both
- ✅ `extends Base(final p = 5.0)` — promote to `final`

Not valid in `extends`:

- ❌ `extends Base(y = initial 7.0)` — initial only, silently dropped
- ❌ `extends Base(y = initial missing)` — initial only, silently dropped

## Component libraries

Component libraries are Julia packages, not files to copy:
- Install: `Pkg.add(["ElectricalComponents"])`
- Use with full namespace: `ElectricalComponents.Analog.Basic.Resistor(R=100)`
- `agent_resources/stdlib_reference/` is DOCUMENTATION ONLY — never copy or recreate locally
- Read `agent_resources/stdlib_reference/<Library>.md` for list of components in a <Library>
- Base connectors need no namespace or install: Pin, HeatPort, Flange, RealInput, RealOutput
- Standard library: BlockComponents, ElectricalComponents, RotationalComponents, TranslationalComponents, ThermalComponents, HydraulicComponents
