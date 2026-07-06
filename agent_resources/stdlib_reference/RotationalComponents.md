# RotationalComponents

This is the documentation for the `RotationalComponents` library.  Here you will find the documentation for the various definitions contained in `RotationalComponents`, grouped by sub-library.

Items are listed with their fully-qualified dotted path. Use that exact path when referencing a component in Dyad code (e.g. `extends BlockComponents.Interfaces.SISO`).

Note that this documentation is automatically generated primarily from the doc strings and metadata associated with those definitions.

## Types

### Interfaces

  * `RotationalComponents.Interfaces.PartialAbsoluteSensor` - Base ideal sensor for measuring absolute spline variables with no torque interaction.
  * `RotationalComponents.Interfaces.PartialCompliant` - Defines a generic compliant rotational connection between two shaft splines.
  * `RotationalComponents.Interfaces.PartialCompliantWithRelativeStates` - Defines relative angular states for compliant rotational connections.
  * `RotationalComponents.Interfaces.PartialElementaryOneSplineAndSupport` - A base model for a mechanical component with a primary rotational spline and an interconnected support spline.
  * `RotationalComponents.Interfaces.PartialElementaryRotationalToTranslational` - Base model defining the mechanical interfaces for transforming rotational motion into translational motion.
  * `RotationalComponents.Interfaces.PartialElementaryTwoSplinesAndSupport` - A foundational model for a mechanical component with two rotational shaft interfaces and a supporting housing, establishing torque balance.
  * `RotationalComponents.Interfaces.PartialRelativeSensor` - A foundational partial model for measuring relative kinematic variables between two ideal mechanical splines.
  * `RotationalComponents.Interfaces.PartialTorque` - Partial model of torque that accelerates the flange.
  * `RotationalComponents.Interfaces.PartialTwoSplines` - Base component providing two independent spline instances.

### Sources

  * `RotationalComponents.Sources.ReferenceType` - Type of reference signal handling for position and speed source components.
  * `RotationalComponents.Sources.Regularization` - Type of regularization near zero speed for sign-dependent torque models.

## Components

### Components

  * `RotationalComponents.Components.Damper` - Models a linear rotational mechanical damping element where torque is proportional to relative angular velocity.
  * `RotationalComponents.Components.Disc` - 1-dim. rotational rigid component without inertia, where right spline is rotated
  * `RotationalComponents.Components.Fixed` - Represents a mechanical rotational element fixed at a specified angle.
  * `RotationalComponents.Components.IdealGear` - An ideal mechanical gear unit with a fixed housing, connecting two rotational shafts.
  * `RotationalComponents.Components.IdealGearR2T` - Gearbox transforming rotational into translational motion.
  * `RotationalComponents.Components.IdealPlanetaryGear` - Ideal planetary gear set with three rotational flanges (sun, ring, carrier).
  * `RotationalComponents.Components.IdealRollingWheel` - Ideal rolling wheel converting rotational motion to translational motion and vice-versa, without inertia.
  * `RotationalComponents.Components.Inertia` - A 1D-rotational component with inertia, subject to torques from two splines.
  * `RotationalComponents.Components.PrescribeInitialAcceleration` - Defines an initial angular acceleration for a rotational mechanical spline.
  * `RotationalComponents.Components.PrescribeInitialEquilibrium` - Sets initial zero angular velocity and zero angular acceleration for a rotational connector.
  * `RotationalComponents.Components.PrescribeInitialPosition` - Sets a specific initial angular position for a rotational spline connector.
  * `RotationalComponents.Components.PrescribeInitialVelocity` - Sets a defined initial angular velocity to a rotational mechanical connector.
  * `RotationalComponents.Components.RackAndPinion` - Models an ideal rack and pinion system, converting rotational motion to translational motion.
  * `RotationalComponents.Components.RelativeStates` - Definition of relative state variables.
  * `RotationalComponents.Components.Spring` - Ideal linear rotational spring.
  * `RotationalComponents.Components.SpringDamper` - Models a linear 1D rotational spring and damper acting in parallel.

### Sensors

  * `RotationalComponents.Sensors.AccelerationSensor` - Measures the absolute angular acceleration of a rotational spline.
  * `RotationalComponents.Sensors.AngleSensor` - Measures the absolute rotational angle of a connected spline.
  * `RotationalComponents.Sensors.MultiSensor` - Ideal sensor to measure the absolute angular velocity, torque, and power between two splines.
  * `RotationalComponents.Sensors.PowerSensor` - Measures the instantaneous rotational power transmitted between two mechanical rotational splines.
  * `RotationalComponents.Sensors.RelativeAccelerationSensor` - Ideal sensor that measures the relative angular acceleration between two rotational mechanical splines.
  * `RotationalComponents.Sensors.RelativeAngleSensor` - Ideal sensor to measure the relative angle between two splines.
  * `RotationalComponents.Sensors.RelativeVelocitySensor` - Ideal sensor for measuring the relative angular velocity between two rotational splines.
  * `RotationalComponents.Sensors.TorqueSensor` - Ideal sensor measuring the torque transmitted between two rotational splines.
  * `RotationalComponents.Sensors.VelocitySensor` - Measures the ideal absolute angular velocity of a rotational mechanical flange.

### Sources

  * `RotationalComponents.Sources.AccelerationSource` - Defines the forced angular movement of a spline based on an input acceleration signal.
  * `RotationalComponents.Sources.ConstantSpeed` - Constant speed, not dependent on torque.
  * `RotationalComponents.Sources.ConstantTorque` - Constant torque, not dependent on speed.
  * `RotationalComponents.Sources.InverseSpeedDependentTorque` - Torque reciprocal dependent on speed.
  * `RotationalComponents.Sources.LinearSpeedDependentTorque` - Linear dependency of torque versus speed.
  * `RotationalComponents.Sources.Position` - Forced movement of a spline according to a reference angle signal.
  * `RotationalComponents.Sources.QuadraticSpeedDependentTorque` - Quadratic dependency of torque versus speed.
  * `RotationalComponents.Sources.SignTorque` - Constant torque changing sign with speed.
  * `RotationalComponents.Sources.SpeedSource` - Forced movement of a spline according to a reference angular velocity signal.
  * `RotationalComponents.Sources.Torque2` - Input signal acting as torque on two splines.
  * `RotationalComponents.Sources.TorqueSource` - Ideal source applying an externally specified torque to a rotational spline.
  * `RotationalComponents.Sources.TorqueStep` - Constant torque, not dependent on speed.

## Examples

### Examples

  * `RotationalComponents.Examples.CompareBrakingTorque` - Compare different braking torques.
  * `RotationalComponents.Examples.ElasticBearing` - Example to show possible usage of support flange.
  * `RotationalComponents.Examples.First` - First example: simple drive train.
  * `RotationalComponents.Examples.FirstGrounded` - First example: simple drive train with grounded elements.
  * `RotationalComponents.Examples.TwoInertiasWithDrivingTorque` - A mechanical system of two rotational inertias coupled by a spring and damper, driven by a sinusoidal torque.

## Tests

### Sources/Tests

  * `RotationalComponents.Sources.Tests.AllComponents` - Tests Position, SpeedSource, AccelerationSource, and Torque2 components,
  * `RotationalComponents.Sources.Tests.ConstantSpeed` - Test for ConstantSpeed source, matching MSL ModelicaTest.Rotational.AllComponents topology.
  * `RotationalComponents.Sources.Tests.Position` - Test of the Position source component with all ReferenceType enum variants,
  * `RotationalComponents.Sources.Tests.Speed` - Test for SpeedSource with Filtered and Exact modes, matching MSL ModelicaTest.Rotational.TestSpeed.
  * `RotationalComponents.Sources.Tests.TestBraking` - Test for braking torque sources, matching MSL ModelicaTest.Rotational.TestBraking.
  * `RotationalComponents.Sources.Tests.Torque2` - Test for Torque2: two inertias driven by a torque acting between them, matching the MSL test topology.
  * `RotationalComponents.Sources.Tests.TorqueStep` - Test for TorqueStep source, matching MSL ModelicaTest.Rotational.AllComponents topology.
