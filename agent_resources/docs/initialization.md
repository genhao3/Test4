# Initialization in Dyad

Dyad has two distinct initialization mechanisms.

## initial equations vs guess statements

Use initial equations for differential state variables. Use guess statements for algebraic variables.

initial sets the value at t=0 for variables that have der() applied to them:

```dyad
component Integrator
  variable x::Real
  parameter k::Real = 1.0

relations
  initial x = 0.0
  der(x) = k
end
```

You can also attach the initial value directly to the variable declaration with `= initial`:

```dyad
component Integrator
  variable x::Real = initial 0.0
  parameter k::Real = 1.0
relations
  der(x) = k
end
```

`= initial value` only sets the initial condition — it does not add an equation `x = value`. Use `= value` (no `initial` keyword) when you want a default binding equation, or `= value initial init` when you want both. See `syntax.md` for the full form.

### Overriding an initial through `extends` or a subcomponent call

A subcomponent call accepts the initial form on its own:

```dyad
inner = Integrator(x = initial 5.0)   # ✅ overrides x's initial to 5.0
```

An `extends` clause requires an equation form on every variable modification. Pair the initial override with an equation form — either a value or `missing` to drop the inherited equation:

```dyad
extends Integrator(x = 0.0 initial 5.0)         # ✅ equation 0.0 + initial 5.0
extends Integrator(x = missing initial 5.0)     # ✅ drop equation, override initial
```

Not valid in `extends`:

```dyad
extends Integrator(x = initial 5.0)             # ❌ initial only — silently dropped
```

See `syntax.md` for the full set of forms.

guess provides starting points for algebraic variables in simultaneous equations. Place guess statements in the relations block:

```dyad
component NPNTransistor
  variable Vbe::Voltage
  variable Ib::Current
  capacitor = ElectricalComponents.Analog.Basic.Capacitor()

relations
  guess Vbe = 0.7
  guess Ib = 1e-5
  Vbe = b.v - e.v
  Ib = Is * (exp(Vbe / Vt) - 1.0)
  guess capacitor.i = 0
end
```

## When to use each

State variables are integrated quantities. These need initial conditions.

Algebraic variables are instantaneous: voltage across a resistor from Ohm's law, current from Kirchhoff's laws, force from equilibrium. These need guesses when they form loops.

## Related Documentation

- syntax.md - Complete syntax for initial equations and variable attributes
- enums_and_initialization.md - Conditional initialization with switch-case
- analyses.md - Using analyze_tool to check models before simulation
