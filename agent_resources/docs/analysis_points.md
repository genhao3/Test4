---
description = Learn about analysis points in Dyad, their purpose, and how to use them for advanced system analysis.
---

# [Analysis Points](@id analysis_points)

## What Are Analysis Points?

Analysis points are special constructs in Dyad that allow users to define specific locations in a model where signal connections can be manipulated for analysis purposes. These points act as named connections, enabling model transformations such as adding inputs and outputs, as well as breaking connections.

In control systems, analysis points are particularly useful for studying feedback loops, assessing robustness, and performing frequency-domain analyses. They provide a way to isolate and inspect specific parts of a system without altering its overall behavior during simulation.


## How to Use Analysis Points in Dyad

### Syntax Breakdown

In Dyad, analysis points are declared using the `analysis_point` keyword. The syntax is:

```dyad
u: analysis_point(output_signal, input_signal)
```

Here:
- `u` is the name of the analysis point.
- `output_signal` is a block output, i.e., the causal result of a computation performed by a block. This signal is typically treated as the output variable if the analysis point is marked as an output.
- `input_signal` is a block input. This signal will typically be treated as an input or additively perturbed by a new external input if the analysis point is marked as an input.

In the most common usage, the analysis-point declaration directly mirrors a `connect` statement between an output and an input, e.g., to add an analysis point to the connection
```
connect(controller.y, plant.u)
```
one would add the following relation to the model:
```dyad
u: analysis_point(controller.y, plant.u)
```
Here, the name `u` is chosen to reflect the common convention of naming control inputs with `u`. The choice of the name `u` here is just an example, you can give it any name. An analysis point may be added to connections with more than one receiving input, but the declaration may only contain a single _output_ (signal source).

The fact that the declaration of an analysis point is separated from the formation of a connection allows for addition of analysis points to any lower level in the model hierarchy, i.e., analysis points can be added inside pre-existing components from an outer component.

### Full Example

Below is a simple example of a feedback system with analysis points:

```dyad
component TestDCMotorLoadControlled
  motor = DCMotor()
  ground = ElectricalComponents.Analog.Basic.Ground()
  source = ElectricalComponents.Analog.Sources.VoltageSource()
  fixed = RotationalComponents.Components.Fixed()
  load = RotationalComponents.Sources.TorqueSource()
  load_source = BlockComponents.Sources.Step(height=tau_load, start_time=load_step_start_time)
  speed_reference = BlockComponents.Sources.Constant(k=w_motor)
  controller = BlockComponents.Continuous.LimPID(k=k, Ti=Ti, Td=Td, Nd=Nd, y_max=5, y_min=-5)
  signal_ff = BlockComponents.Sources.Constant(k=0)
  speed_sensor = RotationalComponents.Sensors.VelocitySensor()
  # Motor desired speed
  parameter w_motor::AngularVelocity = 1
  # Amplitude of load torque step
  parameter tau_load::Torque = -0.3
  # Load step start time
  parameter load_step_start_time::Time = 3
  # Controller gain
  parameter k::Real = 0.5
  # Controller time constant of the integrator block
  parameter Ti::Time = 0.1
  # Controller Time constant of the derivative block
  parameter Td::Time = 1e5
  parameter Nd::Real = 10
relations
  initial motor.L1.i = 0
  initial motor.inertia.w = 0
  u: analysis_point(controller.y, source.V)
  y: analysis_point(speed_sensor.w, controller.u_m)
  r: analysis_point(speed_reference.y, controller.u_s)
  connect(load_source.y, load.tau)
  connect(source.p, motor.p)
  connect(motor.n, source.n, ground.g)
  connect(motor.shaft, load.spline)
  connect(motor.housing, load.support, fixed.spline)
  connect(speed_reference.y, controller.u_s)
  connect(speed_sensor.w, controller.u_m)
  connect(controller.y, source.V)
  connect(controller.u_ff, signal_ff.y)
  connect(speed_sensor.spline, motor.shaft)
end
```

In this example:
- `u` names the connection from the controller output to the voltage source input.
- `y` names the connection from the speed sensor output to the controller input.
- `r` names the connection from the speed reference to the controller reference input.

The diagram below illustrates the connections and analysis points in this example, abstracting the controller and plant components into blocks `C` and `P` respectively:

```
r   ┌─────┐     ┌─────┐
───►│     │  u  │     │ y
    │  C  ├────►│  P  ├─┬─►
  ┌►│     │     │     │ │
  │ └─────┘     └─────┘ │
  │                     │
  └─────────────────────┘
```


## Model transformations
To facilitate analysis, ModelingToolkit may, depending on the analysis requested, transform connections and / or add new input variables. This section describes some of the available transformations.

### Linearization
When linearizing a model between two analysis points, ModelingToolkit will automatically add one perturbation input variable to each input analysis point. For example, in the diagram
```
         ▲
         │e₁
         │  ┌─────┐
d₁────+──┴──►  P  ├─────┬──►e₄
      │     └─────┘    y│
      │u                │
      │     ┌─────┐    -│
 e₂◄──┴─────┤  C  ◄──┬──+───d₂
            └─────┘  │
                     │e₃
                     ▼
```
linearization between analysis points `u` and `y` will add the artificial input variable `d₁`, and linearize between `d₁` and `y`. Note, the result of such a linearization is _not_ the transfer function of the system `P` between `u` and `y`, instead it is the _closed-loop transfer function_ $(I + PC)^{-1}P$ that is obtained with all the connections in the diagram intact. If the transfer function of the isolated system `P` is desired, one may make use of the `loop_openings` feature to break the connections `u` and `y` during the linearization, i.e., by passing `loop_openings = ["u", "y"]` to the analysis. Loop openings are discussed in more detail below.

### Sensitivity analysis
When computing the sensitivity function in the signal `y`

```
         ▲
         │e₁
         │  ┌─────┐
d₁────+──┴──►  P  ├─────┬──►e₄
      │     └─────┘    y│
      │u                │
      │     ┌─────┐    -│
 e₂◄──┴─────┤  C  ◄──┬──+───d₂
            └─────┘  │
                     │e₃
                     ▼
```
ModelingToolkit will automatically add the input variable `d₂` and the output variable `e₃`, i.e., the analysis point `y` will be perturbed by an artificial input and the output is taken to be the signal _after_ the perturbation. If, instead, the _complementary_ sensitivity function is requested, ModelingToolkit will add the same input variable `d₂`, but the output will instead be immediately _before_ the perturbation, i.e., the output variable `e₄`.

### Loop openings
All analysis-point transformations may be combined with _loop openings_. A loop opening is requested by passing the name of one or several analysis points to the argument `loop_openings`. For example, if `loop_openings = ["u"]` while linearizing between the analysis points `u` and `y`, the connection labeled `u` in the diagram above will be broken during the analysis. This will in this case result in the transfer function `P` being computed, rather than the closed-loop transfer function $(I + CP)^{-1}P$ that would be obtained if the loop was not opened. In this case, breaking the connection through `y` is not required in order to isolate the system `P`, since the block `C` is downstream of the analysis point `y`.
