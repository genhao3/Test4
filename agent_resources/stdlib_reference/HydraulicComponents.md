# HydraulicComponents

This is the documentation for the `HydraulicComponents` library.  Here you will find the documentation for the various definitions contained in `HydraulicComponents`, grouped by sub-library.

Items are listed with their fully-qualified dotted path. Use that exact path when referencing a component in Dyad code (e.g. `extends BlockComponents.Interfaces.SISO`).

Note that this documentation is automatically generated primarily from the doc strings and metadata associated with those definitions.

## Types

### Interfaces

  * `HydraulicComponents.Interfaces.AbstractMedium`
  * `HydraulicComponents.Interfaces.Port`
  * `HydraulicComponents.Interfaces.TwoPorts` - A base model for generic two-port fluid dynamic components.

## Components

### Fittings

  * `HydraulicComponents.Fittings.FlowDivider` - Splits an incoming mass flow from `port_a` such that the flow to `port_b` is reduced by a factor `n`, with the remainder exiting via an `open` port.

### Machines

  * `HydraulicComponents.Machines.DoubleActingCylinder` - The Double Acting Cylinder model is a hydraulic actuator with two fluid ports (port_a and port_b)

### Pipes

  * `HydraulicComponents.Pipes.TubeBase` - Models the pressure drop in a fluid-carrying tube considering friction and optional inertia.

### Sources

  * `HydraulicComponents.Sources.BoundaryPressure` - Establishes a pressure boundary condition dictated by an external signal.

### Vessels

  * `HydraulicComponents.Vessels.FixedVolume` - Represents a chamber with fixed-volume.

## Examples

### Examples

  * `HydraulicComponents.Examples.FluidSystem` - Models a test fluid system where a step-defined pressure source drives flow through a pipe into a fixed volume.

## Tests

### Machines/Tests

  * `HydraulicComponents.Machines.Tests.DoubleActingCylinder` - This test case simulates a Double Acting cylinder with an external mass connected
