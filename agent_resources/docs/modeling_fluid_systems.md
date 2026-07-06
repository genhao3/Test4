# Modeling Fluid Systems in Dyad

## Media Models

Hydraulic components are generic and medium-independent, automatically inferring media from model connectivity.
Media definitions are developed entirely in Julia to support various equations of state, different thermodynamic state representations, and arbitrary fluid properties.

### Simple Ideal Gas Example

Use abstract types and multiple dispatch for generic media handling:

```julia
abstract type AbstractMedium end

@kwdef struct IdealGas <: AbstractMedium
  R::Real  # Specific gas constant [J/(kg·K)]
end

const N2 = IdealGas(R=296.8033)
const O2 = IdealGas(R=259.837)
```

### Thermodynamic State

Use typed state objects to avoid ambiguity and handle mixtures:

```julia
abstract type ThermodynamicState end

@kwdef struct pT{T1<:Real,T2<:Real} <: ThermodynamicState
	p::T1  # Pressure [Pa]
	T::T2  # Temperature [K]
end

function density(medium::IdealGas, state::pT)
	state.p / (medium.R * state.T)
end
```

### Mixtures

```julia
@kwdef struct Mixture <: AbstractMedium
	media::Vector{AbstractMedium}
end

@kwdef struct pTX{T1<:Real,T2<:Real,T3<:AbstractVector{<:Real}} <: ThermodynamicState
    p::T1  # Pressure [Pa]
    T::T2  # Temperature [K]
    X::T3  # Mole fractions [mol/mol]
end

function density(medium::Mixture, state::pTX)
    sum(density.(medium.media, (pT(state.p, state.T),)) .* state.X)
end

const Air = Mixture(media=[N2, O2])
density(Air, pTX(p=101325, T=300, X=[0.78, 0.22])) # Returns 1.173575796885558
```

### Additional Properties

Use automatic differentiation for derived properties:

```julia
# Cp = dh/dT using automatic differentiation
function specific_heat_cp(medium::AbstractMedium, state::pT)::Float64
	ForwardDiff.derivative(t -> enthalpy(medium, pT(state.p, t)), state.T)
end
```

Media models support symbolic evaluation with Symbolics.jl and standard Julia testing.

## Component-Oriented Modeling

### Connector Definition

```dyad
type AbstractMedium = Native

connector FluidPort
  potential p::Pressure               # Drives dynamics
  flow m_flow::MassFlowRate           # Conserved quantity
  stream h_outflow::SpecificEnthalpy  # Intensive fluid properties
  path medium::AbstractMedium         # Shared circuit information
end
```

Key variable types:
- `potential`/`flow`: Standard across-through variables
- `stream`: Intensive properties of flowing fluid
- `path`: Information propagated throughout circuit topology

### Boundary Component

```dyad
component Boundary_PT
  port = FluidPort()
  parameter p_fixed::Pressure
  parameter T_fixed::Temperature
relations
  port.p = p_fixed
  port.h_outflow = enthalpy(port.medium, ThermodynamicState(p=p_fixed, T=T_fixed))
end
```

### Flow Components

Define `continuity` statement for ports that are part of the same circuit but aren't explicitly connected with `connect`.

#### Pressure-Driven Flow (Valve)

```dyad
component LinearValve
  port_a = FluidPort()
  port_b = FluidPort()
  parameter A::Area
  parameter C::LinearFlowCoefficient
relations
  continuity(port_a.medium, port_b.medium)  # Same circuit
  port_a.m_flow + port_b.m_flow = 0         # Mass conservation
  port_a.m_flow = C*A*(port_a.p - port_b.p) # Pressure-driven flow
  port_a.h_outflow = instream(port_b.h_outflow)
  port_b.h_outflow = instream(port_a.h_outflow)
end
```

#### Prescribed Flow (Pump/Source)

**CRITICAL:** Set only ONE port's m_flow. MTK adds conservation via connections.

```dyad
component MassFlowSource
  port_a = FluidPort()  # Connect to upstream (source)
  port_b = FluidPort()  # Connect to downstream (load)
  parameter m_flow_set::MassFlowRate = 0.1
relations
  continuity(port_a.medium, port_b.medium)  # Same circuit
  # Set ONLY port_b - MTK handles port_a via connections
  port_b.m_flow = -m_flow_set  # Negative = flow OUT of port_b
  port_a.p = port_b.p
  # Stream variables: cross-link pattern
  port_a.h_outflow = instream(port_b.h_outflow)
  port_b.h_outflow = instream(port_a.h_outflow)
end
```

**Flow Sign Convention:**
- `m_flow > 0`: Flow INTO the port/component
- `m_flow < 0`: Flow OUT OF the port/component
- For a source pushing flow: `port_b.m_flow = -m_flow_set` (negative)
- Connection equation: `portA.m_flow + portB.m_flow = 0` added by MTK

### Control Volume

```dyad
component ClosedVolume
  port = FluidPort()
  parameter volume::Volume
  parameter p0::Pressure
  parameter T0::Temperature
  variable m::Mass
  variable U::Energy
  variable T::Temperature
relations
  initial port.p = p0
  initial T = T0
  m = volume*density(port.medium, ThermodynamicState(p=port.p, T=T))
  U = m*internal_energy(port.medium, ThermodynamicState(p=port.p, T=T))
  port.h_outflow = enthalpy(port.medium, ThermodynamicState(p=port.p, T=T))
  D(U) = port.m_flow*actualstream(port.m_flow, port.h_outflow)  # Energy conservation
  D(m) = port.m_flow  # Mass conservation
end
```

### Complete System Example

```dyad
test component Filling_Test
  boundary = Boundary_PT(p_fixed=1M, T_fixed=500.0)
  valve = LinearValve(A=1.0, C=0.1)
  cv = ClosedVolume(volume=10k, p0=1e5, T0=400.0)
  path medium::AbstractMedium = N2  # Medium specified at top level
relations
  continuity(medium, boundary.port.medium)
  connect(boundary.port, valve.port_a)
  connect(valve.port_b, cv.port)
end

analysis TestFilling
  extends TransientAnalysis(stop=10)
  model = Filling_Test()
end
```

Note that `continuity` statement specifies the `medium` in the `boundary.port`. `connect` statements implicitly imply continuity. As `boundary` is to connected to `valve` and `valve` to `cv` via `connect` the whole system has N2 as the medium.

## Summary

**Media Models:**
- Define properties in Julia using abstract types and multiple dispatch
- Use automatic differentiation for derived properties
- Work with symbolic evaluation and standard Julia tooling

**Components:**
- Medium is a `path` variable propagated throughout circuit topology
- Add `continuity` when ports are not explicitly connected but are part of the same fluid circuit.
- Components are medium-independent, adapting to any fluid type
- Only compute properties actually needed for each component
- Stream variables automatically handle intensive property transport
- Property evaluations are ordinary Julia function calls

**Stream Variable Functions:**

`actualstream` is commonly defined helper function:

```julia
function actualstream(flow, sv)
    ifelse(flow > 0, instream(sv), sv)
end
```

**How it works:**
- If `flow > 0`: Flow is INTO the component → use `instream(sv)` (get value from connected upstream port)
- If `flow ≤ 0`: Flow is OUT OF the component → use `sv` (use local component's value)

**Where to use it:**
Use `actualstream()` in **consuming components** (volumes, mixers) in energy balance equations:

```dyad
component Mixer
  inlet1 = FluidPort()
  inlet2 = FluidPort()
  outlet = FluidPort()
  variable U::Energy
relations
  # Energy balance with actualstream()
  der(U) = inlet1.m_flow * actualstream(inlet1.m_flow, inlet1.h_outflow) +
           inlet2.m_flow * actualstream(inlet2.m_flow, inlet2.h_outflow) +
           outlet.m_flow * actualstream(outlet.m_flow, outlet.h_outflow)
  # Set local h_outflow for reverse flow
  inlet1.h_outflow = h_local
  inlet2.h_outflow = h_local
  outlet.h_outflow = h_local
end
```

**Do NOT use in flow sources** - they use cross-link pattern (see MassFlowSource above)
