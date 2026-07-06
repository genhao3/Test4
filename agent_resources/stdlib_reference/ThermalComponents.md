# ThermalComponents

This is the documentation for the `ThermalComponents` library.  Here you will find the documentation for the various definitions contained in `ThermalComponents`, grouped by sub-library.

Items are listed with their fully-qualified dotted path. Use that exact path when referencing a component in Dyad code (e.g. `extends BlockComponents.Interfaces.SISO`).

Note that this documentation is automatically generated primarily from the doc strings and metadata associated with those definitions.

## Types

### Interfaces

  * `ThermalComponents.Interfaces.ConvectiveElement1D` - ConvectiveElement1D is baseclass for 1D convective heat transfer elements, defining temperature drop and heat flow between solid and fluid interfaces without energy storage.
  * `ThermalComponents.Interfaces.Element1D` - Element1D is partial one-dimensional thermal element for models without energy storage.

## Components

### Components

  * `ThermalComponents.Components.BodyRadiation` - BodyRadiation models radiative heat transfer between two surfaces.
  * `ThermalComponents.Components.Convection` - Models heat transfer by convection where the thermal conductance is a signal input.
  * `ThermalComponents.Components.ConvectiveResistor` - ConvectiveResistor is 1D thermal convective element with a dynamically supplied thermal resistance.
  * `ThermalComponents.Components.HeatCapacitor` - Represents a lumped thermal element that stores heat energy.
  * `ThermalComponents.Components.ThermalConductor` - Lumped thermal element for heat conduction without thermal energy storage.
  * `ThermalComponents.Components.ThermalResistor` - Represents a pure thermal resistance relating temperature difference to heat flow rate.

### Sensors

  * `ThermalComponents.Sensors.HeatFlowSensor` - Measures the rate of heat flow between two thermal connection points.
  * `ThermalComponents.Sensors.RelativeTemperatureSensor` - Measures the temperature difference between two thermal nodes.
  * `ThermalComponents.Sensors.TemperatureSensor` - Measures the absolute temperature at a thermal node.

### Sources

  * `ThermalComponents.Sources.FixedHeatFlow` - Fixed heat flow boundary condition, potentially temperature-dependent.
  * `ThermalComponents.Sources.FixedTemperature` - Defines a fixed temperature boundary condition at its port.
  * `ThermalComponents.Sources.PrescribedHeatFlow` - Models a prescribed heat flow rate at a thermal port, with optional temperature dependency.
  * `ThermalComponents.Sources.PrescribedTemperature` - Imposes a specified temperature at a thermal connection point.

## Examples

### Examples

  * `ThermalComponents.Examples.HeatSystem` - Models a thermal system with a fixed temperature source heating a heat capacitor via a conductor; serves as a test component.
  * `ThermalComponents.Examples.TemperatureOfTwoMasses` - Test component for simulating heat exchange between two masses and verifying temperature sensor readings.
