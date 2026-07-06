# Dyad Library Management

Dyad Libraries are effectively julia packages. This is because Dyad modeling code (`.dyad` files), through the compile tool generates julia files that are used to actually simulate / run the dyad model.

**To actually use these components in your project:**
1. Add the library as a Julia dependency: `Pkg.add(["ElectricalComponents"])`
2. Reference with full namespace: `ElectricalComponents.Analog.Basic.Resistor(R=100)`

The `.dyad` files in `agent_resources/stdlib_reference/` are **reference snippets for documentation purposes only** - they are NOT usable code. These snippets show internal library code without namespaces because they're excerpts from within each library.

## Important: `agent_resources/stdlib_reference/` is Documentation Only
**NEVER** treat `stdlib_reference/` or `agent_resources/` as a dyad library, they are **DOCS**

## When Do You Need External Packages?

**You DON'T need external packages if:**
- Writing custom components using base Dyad connectors (Pin, Flange, HeatPort, RealInput/Output) - these are always available
- Defining your own component library in `.dyad` files that doesn't depend on anything outside of your `dyad/` folder

**You DO need external packages if:**
- Using pre-built components from standard libraries (e.g., `ElectricalComponents.Analog.Basic.Resistor`, `BlockComponents.Sources.Sine`)
- Extending existing component hierarchies

## Sublibraries (Organizing Components into Submodules)

To organize components into a sublibrary, create a subdirectory under `dyad/`. The directory name becomes the sublibrary name.

```
dyad/
  analysis.dyad          # root-level analysis
  Sub1/
    my_component.dyad    # component inside Sub1 sublibrary
```

When referencing a sublibrary component from outside it, you must fully qualify from the root library. See [library_namespacing.md](library_namespacing.md) section 3 for the rule and examples.

## Why Package Installation Matters

When you use a library component like `ElectricalComponents.Analog.Basic.Resistor`:
1. The Dyad compiler generates Julia/MTK code in `generated/`
2. The generated code contains `using ElectricalComponents`
3. Julia must have that package installed or the generated code fails to compile and be generated

## Standard Libraries

- `BlockComponents` - Sine, Step, Ramp, Integrator, Gain, PID, etc.
- `ElectricalComponents` - Resistor, Capacitor, Inductor, VoltageSource, Ground, etc.
- `RotationalComponents` - Inertia, Spring, Damper, Torque, etc.
- `TranslationalComponents` - Mass, Spring, Damper, Force, etc.
- `ThermalComponents` - HeatCapacitor, ThermalConductor, etc.
- `HydraulicComponents` - Pipe, Pump, Valve, etc.

## Adding Libraries

```julia
using Pkg
Pkg.add(["BlockComponents", "ElectricalComponents"])
```

## Diagnosing Compilation Errors

### `lookup-failed: Unable to resolve type X in module in libname Y`

This error means the compiler cannot find component `X` in library `Y`. Two possible causes:

1. **Library `Y` is not installed** → Fix: `Pkg.add(["Y"])`
2. **Component `X` doesn't exist in library `Y`** (typo or wrong name) → Fix: Check `stdlib_reference/` for correct name

To diagnose: Check if the library is installed with `Pkg.status()` in julia_tool. If installed and it's a standard library, check `stdlib_reference/` for correct component names.

### Other Common Errors

- `Unknown symbol Y.X` → Package `Y` not installed → `Pkg.add(["Y"])`
- `Component 'X' not found` → Missing namespace OR typo → Use `LibraryName.X`

## Using Library Components

Always use full namespace:

```dyad
component MyCircuit
  source = ElectricalComponents.Analog.Sources.VoltageSource(V=12)
  r1 = ElectricalComponents.Analog.Basic.Resistor(R=100)
  gnd = ElectricalComponents.Analog.Basic.Ground()
  signal = BlockComponents.Sources.Sine(frequency=60)
end
```

## Check Installed Packages

```julia
using Pkg
Pkg.status()
```

**Note:** `DyadEcosystemDependencies` is NOT a standard library package - its presence does not mean you have the individual library packages installed. You still need to `Pkg.add()` each library you use.

## Related Documentation

- **[library_namespacing.md](library_namespacing.md)** - Namespacing rules for components and connectors from libraries and sub-libraries
