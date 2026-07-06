---
description: Guide to defining components in Dyad
---

# Components {#Components}

Components are the main unit of Dyad.  A Dyad "model" is components all the way down, which can use or extend each other.

Components can contain other components, `variable`s, `parameter`s, and `relation`s.  They can also `extend` other components or `partial component`s for code reuse.

## Using Components from Libraries {#using-library-components}

**CRITICAL:** When using components from other libraries (like BlockComponents, ElectricalComponents, etc.), you **MUST** use the fully qualified name with the library namespace. Dyad does not use import statements - all external components must be namespace-qualified.

```dyad
# ✅ CORRECT - fully qualified names
component MyCircuit
  resistor = ElectricalComponents.Analog.Basic.Resistor(R=100)
  filter = BlockComponents.Continuous.FirstOrder(T=0.1, k=2.0)
  capacitor = ElectricalComponents.Analog.Basic.Capacitor(C=1e-6)
relations
  # component connections and equations...
end
```

```dyad
# ❌ WRONG - will fail to compile
component MyCircuit
  resistor = Resistor(R=100)          # ERROR: Resistor not found
  filter = FirstOrder(T=0.1)          # ERROR: FirstOrder not found
  capacitor = Capacitor(C=1e-6)       # ERROR: Capacitor not found
relations
  # This will never compile...
end
```

**Why this matters:**
- Dyad compilation will fail with "component not found" errors if you omit the namespace
- There are no import/using statements in Dyad - qualification is the only way to reference library components
- This applies to ALL external libraries: `BlockComponents.Sources.Step`, `ThermalComponents.Components.HeatCapacitor`, `HydraulicComponents.Machines.Pump`, etc.

### Inheritance {#syntax-component-inheritance}

Any component can `extend`, or inherit from, any other component.   This means that the new component will have all the variables, parameters, and relations of the base component, plus any additional variables, parameters, and relations defined in itself.

The way this is done is by using the `extends` keyword in the component definition. Let's say we have a base component `FirstOrder`, which is a simple linear system:

```@dyad extends
component FirstOrder
  variable x::Real
  variable k::Real
relations
  initial x = 1
  initial k = 1
  der(x) = k
end
```


Now, we can define a new component `SecondOrder` that extends `FirstOrder`, adds a new parameter `z`, and uses it to drive the `k` parameter of `FirstOrder`:

```@dyad extends
component SecondOrder
  extends FirstOrder
  parameter z::Real = 1
relations
  der(k) = z
end
```

#### Partial components {#syntax-partial-components}

Partial components are components that are not complete on their own, but can  be used as a base for other components.

You can define a partial component by prefixing the component definition with `partial`.

```dyad
partial component MyPartialComponent
  variable x::Real
  parameter y::Real
relations
  # ...
end
```


Then, regular components (or other partial components) can extend it:

```dyad
component MyComponent
  extends MyPartialComponent
  parameter z::Real
relations
  initial x = 0
  der(x) = y + z
end
```


Here, `MyComponent` has all the variables and parameters of `MyPartialComponent`, even though we haven't explicitly written them out in the definition.

Partial components and inheritance are very useful for sharing code between components, without requiring  components that share a common structure but differ in their specific parameters and behaviour, like electric circuit parts.  See the [RLC Circuit tutorial](/tutorials/creating-components#tutorial-rlc) for an example of using inheritance from partial components.

The advantage of inheritance over simply using a sub-component is namespacing:  the all the variables and parameters of the base component are available directly in the new component, without having to prefix them with the base component's name.

::: tip For example, if we have a base component `MyBaseComponent` with a variable `x`, and a component `MyComponent` that extends it, then we can refer to `x` simply as `mycomponent.x`.  If `MyComponent` did not extend `MyBaseComponent`, but instead had a subcomponent `base = MyBaseComponent()`, then we would have to refer to `x` as `mycomponent.base.x` - significantly more inconvenient! :::

## Related Documentation

For more advanced component features, see:

- **[arrays.md](arrays.md)** - Working with arrays of variables, parameters, and components
- **[functions.md](functions.md)** - Using Julia functions for complex parameter calculations
- **[enums.md](enums.md)** - Conditional initialization with enums and switch-case
- **[library_namespacing.md](library_namespacing.md)** - Namespacing rules for components and connectors from libraries and sub-libraries
- **[syntax.md](syntax.md)** - Complete syntax reference including all component features
