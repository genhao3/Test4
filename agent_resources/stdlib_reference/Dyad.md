# Dyad

This is the documentation for the base `Dyad` library.  Here you will find the documentation for the various definitions contained in the base library.

These definitions do not need to be namespaced when referenced in Dyad code — they are part of the base library (e.g. just `Pin`, not `Dyad.Pin`).

Note that this documentation is automatically generated primarily from the doc strings and metadata associated with those definitions.

## Connectors

  * `BooleanInput` - This connector represents a boolean signal as an input to a component
  * `BooleanOutput` - This connector represents a boolean signal as an output from a component
  * `ClockInput` - While it conveys no value, because every connector must
  * `ClockOutput` - While it conveys no value, because every connector must
  * `Flange` - This connector represents a mechanical flange with position and force as the potential and flow variables, respectively.
  * `Frame2D` - Coordinate system (2-dim.) fixed to the component with one cut-force and cut-torque.
  * `Frame3D` - Frame3D is the fundamental 3D connector used for 6DOF motion. Most components have one or several `Frame`
  * `HeatPort` - This connector represents a thermal node with temperature and heat flow as the potential and flow variables, respectively.
  * `IntegerInput` - This connector represents an integer signal as an input to a component
  * `IntegerOutput` - This connector represents an integer signal as an output from a component
  * `Pin` - This connector represents an electrical pin with voltage and current as the potential and flow variables, respectively.
  * `RealInput` - This connector represents a real signal as an input to a component
  * `RealOutput` - This connector represents a real signal as an output from a component
  * `Spline` - This connector represents a rotational spline with angle and torque as the potential and flow variables, respectively.

## Partial Components

  * `EmptyComponent`

## Enums

  * `DEVerbosity`
  * `NonlinearSolveAlg`
  * `ODEAlg`
  * `OptimizationLevel`

## Analyses

  * `SteadyStateAnalysis` - This is an analysis that computes the steady state solution of the specified `model`.
  * `TransientAnalysis` - This is an analysis that performs a transient simulation of the specified `model`.

## Types

The base library defines a large set of `type` aliases for physical quantities (SI units, dimensionless ratios, etc.). The full list is in `agent_resources/stdlib_reference/Dyad/Types.dyad`.
