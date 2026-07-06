# TranslationalComponents

This is the documentation for the `TranslationalComponents` library.  Here you will find the documentation for the various definitions contained in `TranslationalComponents`, grouped by sub-library.

Items are listed with their fully-qualified dotted path. Use that exact path when referencing a component in Dyad code (e.g. `extends BlockComponents.Interfaces.SISO`).

Note that this documentation is automatically generated primarily from the doc strings and metadata associated with those definitions.

## Types

### Components

  * `TranslationalComponents.Components.Regularization` - Type of regularization near zero speed for sign-dependent force and torque models.

### Interfaces

  * `TranslationalComponents.Interfaces.PartialAbsoluteSensor` - Base model for an ideal mechanical sensor measuring absolute flange variables by ensuring zero force interaction.
  * `TranslationalComponents.Interfaces.PartialCompliant` - Base model for a 1D translational compliant connection.
  * `TranslationalComponents.Interfaces.PartialCompliantWithRelativeStates` - Base model for a 1D translational compliant connection using relative displacement and relative velocity as states.
  * `TranslationalComponents.Interfaces.PartialElementaryOneFlangeAndSupport` - Base model for a one-flange translational component with support.
  * `TranslationalComponents.Interfaces.PartialElementaryOneFlangeAndSupport2` - Partial model for a component with one translational 1D flange and a support.
  * `TranslationalComponents.Interfaces.PartialElementaryRotationalToTranslational` - Base model defining the mechanical interfaces for transforming rotational motion into translational motion.
  * `TranslationalComponents.Interfaces.PartialElementaryTwoFlangesAndSupport2` - Partial model for a component with two translational 1D flanges and a support.
  * `TranslationalComponents.Interfaces.PartialForce` - Partial model of a force acting at the flange (accelerates the flange).
  * `TranslationalComponents.Interfaces.PartialRelativeSensor` - Base two-port element for relative sensing, ensuring conservation of flow between its connection points.
  * `TranslationalComponents.Interfaces.PartialRigid` - Models a massless, rigid connection of a defined length between two translational 1D flanges.
  * `TranslationalComponents.Interfaces.PartialTwoFlanges` - Base component representing a one-dimensional mechanical component with two translational connection points (flanges).

### Sources

  * `TranslationalComponents.Sources.ReferenceType` - Type of reference signal handling for position and speed source components.

## Components

### Components

  * `TranslationalComponents.Components.Damper` - Linear translational damper relating force to relative velocity.
  * `TranslationalComponents.Components.ElastoGap` - 1D translational spring damper combination with gap.
  * `TranslationalComponents.Components.Fixed` - Constrains a translational flange to a fixed position.
  * `TranslationalComponents.Components.IdealGearR2T` - Gearbox transforming rotational into translational motion.
  * `TranslationalComponents.Components.IdealRollingWheel` - Simple 1-dim. model of an ideal rolling wheel without inertia.
  * `TranslationalComponents.Components.Mass` - Represents a sliding mass with inertia, subject to external and gravitational forces.
  * `TranslationalComponents.Components.PrescribeInitialAcceleration` - Defines a specific initial acceleration for a one-dimensional mechanical translational flange.
  * `TranslationalComponents.Components.PrescribeInitialEquilibrium` - Sets the initial velocity and acceleration of a connected flange to zero.
  * `TranslationalComponents.Components.PrescribeInitialPosition` - Sets the initial position of a translational mechanical flange.
  * `TranslationalComponents.Components.PrescribeInitialVelocity` - Sets an initial velocity condition for a translational mechanical flange.
  * `TranslationalComponents.Components.RelativeStates` - Definition of relative state variables.
  * `TranslationalComponents.Components.Rod` - Rod without inertia.
  * `TranslationalComponents.Components.RollingResistance` - Resistance of a rolling wheel.
  * `TranslationalComponents.Components.Spring` - Linear 1D translational spring relating force to displacement via Hooke's Law.
  * `TranslationalComponents.Components.SpringDamper` - Models a linear translational spring and a linear translational damper connected in parallel.

### Sensors

  * `TranslationalComponents.Sensors.AccelerationSensor` - Ideal sensor measuring the absolute translational acceleration of a flange.
  * `TranslationalComponents.Sensors.ForceSensor` - Ideal sensor measuring the translational force transmitted between two flanges.
  * `TranslationalComponents.Sensors.MultiSensor` - Ideal sensor measuring absolute velocity, transmitted force, and power flow between two mechanical flanges.
  * `TranslationalComponents.Sensors.PositionSensor` - Measures the absolute linear position of a mechanical translational flange.
  * `TranslationalComponents.Sensors.PowerSensor` - Ideal sensor measuring the translational power flowing through a point.
  * `TranslationalComponents.Sensors.RelativeAccelerationSensor` - Ideal sensor measuring the relative acceleration between two translational flanges.
  * `TranslationalComponents.Sensors.RelativePositionSensor` - Measures the ideal relative translational position between two mechanical flanges.
  * `TranslationalComponents.Sensors.RelativeSpeedSensor` - Ideal sensor measuring the relative translational velocity between two mechanical flanges.
  * `TranslationalComponents.Sensors.SpeedSensor` - Ideal sensor that measures the absolute translational velocity of a mechanical flange.

### Sources

  * `TranslationalComponents.Sources.Accelerate` - Forced movement of a flange according to an acceleration signal.
  * `TranslationalComponents.Sources.ConstantForce` - Constant force, not dependent on speed.
  * `TranslationalComponents.Sources.ConstantSpeed` - Constant speed, not dependent on force.
  * `TranslationalComponents.Sources.Force` - An ideal force source that applies equal and opposite forces to two translational mechanical flanges, controlled by an external signal.
  * `TranslationalComponents.Sources.ForceStep` - Force step at a given time.
  * `TranslationalComponents.Sources.InverseSpeedDependentForce` - Force reciprocal dependent on speed.
  * `TranslationalComponents.Sources.LinearSpeedDependentForce` - Linear dependency of force versus speed.
  * `TranslationalComponents.Sources.Position` - Forced movement of a flange according to a reference position.
  * `TranslationalComponents.Sources.QuadraticSpeedDependentForce` - Quadratic dependency of force versus speed.
  * `TranslationalComponents.Sources.SignForce` - Constant force changing sign with speed.
  * `TranslationalComponents.Sources.Speed` - Forced movement of a flange according to a reference speed.

## Examples

### Examples

  * `TranslationalComponents.Examples.Accelerate` - Use of model Accelerate.
  * `TranslationalComponents.Examples.Damper` - Demonstrate the use of damper models.
  * `TranslationalComponents.Examples.ElastoGap` - Demonstrate usage of ElastoGap.
  * `TranslationalComponents.Examples.InitialConditions` - Setting of initial conditions.
  * `TranslationalComponents.Examples.Oscillator` - Oscillator demonstrates the use of initial conditions.
  * `TranslationalComponents.Examples.PreLoad` - Preload of a spool using ElastoGap models.
  * `TranslationalComponents.Examples.Sensors` - Demonstrate sensors for translational systems.
  * `TranslationalComponents.Examples.SignConvention` - Examples for the used sign conventions.
  * `TranslationalComponents.Examples.WhyArrows` - Demonstrate the importance of arrow direction in Translational models.

## Tests

### Components/Tests

  * `TranslationalComponents.Components.Tests.AllComponents` - Smoke test exercising all available translational components in a single model.
  * `TranslationalComponents.Components.Tests.MassDamperSpringFixed` - A one-dimensional translational mechanical system composed of a mass, spring, and damper connected to a fixed point.

### Sensors/Tests

  * `TranslationalComponents.Sensors.Tests.RelativeSensors` - A test rig for sensors measuring relative translational motion between two independently forced masses.
  * `TranslationalComponents.Sensors.Tests.Sensors` - Test environment for verifying absolute position, speed, and acceleration sensors monitoring a mass driven by a constant force.

### Sources/Tests

  * `TranslationalComponents.Sources.Tests.Position` - Test of the Position source component with all ReferenceType enum variants.
  * `TranslationalComponents.Sources.Tests.Speed` - Test of the Speed source component with all ReferenceType enum variants.
  * `TranslationalComponents.Sources.Tests.TestBraking` - Test of braking force models.
