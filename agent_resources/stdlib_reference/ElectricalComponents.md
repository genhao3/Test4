# ElectricalComponents

This is the documentation for the `ElectricalComponents` library.  Here you will find the documentation for the various definitions contained in `ElectricalComponents`, grouped by sub-library.

Items are listed with their fully-qualified dotted path. Use that exact path when referencing a component in Dyad code (e.g. `extends BlockComponents.Interfaces.SISO`).

Note that this documentation is automatically generated primarily from the doc strings and metadata associated with those definitions.

## Types

### Analog/Interfaces

  * `ElectricalComponents.Analog.Interfaces.FourPin` - Component with two electrical ports (four pins).
  * `ElectricalComponents.Analog.Interfaces.OnePort` - A base model for two-terminal electrical components, defining voltage and current relationships.
  * `ElectricalComponents.Analog.Interfaces.TwoPin` - A base model for two-terminal electrical components, defining voltage relationship.
  * `ElectricalComponents.Analog.Interfaces.TwoPort` - Component with two electrical ports, including current conservation.

## Components

### Analog/Basic

  * `ElectricalComponents.Analog.Basic.CCC` - Linear current-controlled current source.
  * `ElectricalComponents.Analog.Basic.CCV` - Linear current-controlled voltage source.
  * `ElectricalComponents.Analog.Basic.Capacitor` - Ideal electrical capacitor.
  * `ElectricalComponents.Analog.Basic.Conductor` - Ideal linear electrical conductor relating current and voltage through its conductance.
  * `ElectricalComponents.Analog.Basic.Ground` - Ideal electrical ground connection, providing a zero-voltage reference.
  * `ElectricalComponents.Analog.Basic.Gyrator` - Gyrator two-port element.
  * `ElectricalComponents.Analog.Basic.Inductor` - Ideal inductor characterized by its inductance L.
  * `ElectricalComponents.Analog.Basic.MTransformer` - Generic transformer with N mutually coupled inductors.
  * `ElectricalComponents.Analog.Basic.NonlinearResistor` - A nonlinear resistor with a piecewise-linear current-voltage characteristic, commonly known as Chua's Resistor.
  * `ElectricalComponents.Analog.Basic.OpAmpDetailed` - A detailed operational amplifier, incorporating input/output characteristics,
  * `ElectricalComponents.Analog.Basic.Potentiometer` - Adjustable resistor (potentiometer) with three terminals.
  * `ElectricalComponents.Analog.Basic.Resistor` - Linear electrical resistor following Ohm's Law.
  * `ElectricalComponents.Analog.Basic.RotationalEMF` - An ideal electromechanical transducer coupling electrical voltage and current to rotational mechanical torque and angular velocity.
  * `ElectricalComponents.Analog.Basic.SaturatingInductor` - Inductor model exhibiting magnetic saturation.
  * `ElectricalComponents.Analog.Basic.Transformer` - Transformer with two ports.
  * `ElectricalComponents.Analog.Basic.TranslationalEMF` - Electromotive force (electric/translational-mechanic transformer).
  * `ElectricalComponents.Analog.Basic.VCC` - Linear voltage-controlled current source.
  * `ElectricalComponents.Analog.Basic.VCV` - Linear voltage-controlled voltage source.
  * `ElectricalComponents.Analog.Basic.VariableCapacitor` - Ideal linear electrical capacitor with variable capacitance.
  * `ElectricalComponents.Analog.Basic.VariableConductor` - Ideal linear electrical conductor with variable conductance.
  * `ElectricalComponents.Analog.Basic.VariableInductor` - Ideal linear electrical inductor with variable inductance.
  * `ElectricalComponents.Analog.Basic.VariableResistor` - Ideal linear electrical resistor with variable resistance.

### Analog/Sensors

  * `ElectricalComponents.Analog.Sensors.CurrentSensor` - Ideal ammeter measuring the electrical current flowing between its two pins.
  * `ElectricalComponents.Analog.Sensors.MultiSensor` - Provides combined voltage and current measurements from an electrical circuit.
  * `ElectricalComponents.Analog.Sensors.PotentialSensor` - Measures the electrical potential at a connection point.
  * `ElectricalComponents.Analog.Sensors.PowerSensor` - Measures the instantaneous electrical power flowing through or consumed by a circuit.
  * `ElectricalComponents.Analog.Sensors.VoltageSensor` - Measures the electrical potential difference between its two connection terminals.

### Analog/Sources

  * `ElectricalComponents.Analog.Sources.CurrentSource` - Ideal current source driven by an external signal.
  * `ElectricalComponents.Analog.Sources.VoltageSource` - Ideal voltage source whose output voltage is determined by a real input signal and a scaling parameter.

## Examples

### Analog/Examples

  * `ElectricalComponents.Analog.Examples.ChuaCircuit` - Chua's circuit, an electronic circuit known for its chaotic dynamics.
  * `ElectricalComponents.Analog.Examples.CompareTransformers` - MSL validation test: CompareTransformers (basic transformer part).
  * `ElectricalComponents.Analog.Examples.DeSauty` - AC bridge circuit for comparing capacitances
  * `ElectricalComponents.Analog.Examples.DeSautyTransient`
  * `ElectricalComponents.Analog.Examples.ParallelGLC` - Represents an electrical circuit with a conductor, inductor, and capacitor in parallel, driven by a sinusoidal current source.
  * `ElectricalComponents.Analog.Examples.ParallelResonance` - `ParallelResonance` models two parallel RLC resonance circuits, each driven by a current source with variable frequency and amplitude.
  * `ElectricalComponents.Analog.Examples.RLCModel` - An electrical circuit model featuring an inductor in series with a parallel resistor-capacitor combination, driven by a constant voltage source.
  * `ElectricalComponents.Analog.Examples.SeriesResonance` - Models two series RLC circuits, one driven by a sine voltage and the other by a cosine voltage, where both sources have their frequency controlled by a common ramp input and their amplitude by a common constant input.
  * `ElectricalComponents.Analog.Examples.ShowVariableResistor` - MSL validation test: ShowVariableResistor.
  * `ElectricalComponents.Analog.Examples.SimpleRLCTransient`
  * `ElectricalComponents.Analog.Examples.SimpleSineRLCTransient`
  * `ElectricalComponents.Analog.Examples.SinRLC` - Series RLC circuit driven by a sinusoidal voltage input.

## Tests

### Analog/Basic/Tests

  * `ElectricalComponents.Analog.Basic.Tests.AmplifierWithOpAmpDetailed` - Inverting operational amplifier circuit built using a detailed op-amp model.
  * `ElectricalComponents.Analog.Basic.Tests.CCC` - Test circuit for CCC (current-controlled current source).
  * `ElectricalComponents.Analog.Basic.Tests.CCV` - Test circuit for CCV (current-controlled voltage source).
  * `ElectricalComponents.Analog.Basic.Tests.Gyrator` - MSL validation test: Gyrator.
  * `ElectricalComponents.Analog.Basic.Tests.MTransformer` - Test circuit for MTransformer with N=2.
  * `ElectricalComponents.Analog.Basic.Tests.Potentiometer` - Test circuit for Potentiometer.
  * `ElectricalComponents.Analog.Basic.Tests.RotationalEMF` - A test circuit for a rotational electromechanical transducer (RotationalEMF) driven by a sinusoidal voltage and connected to an inertial load.
  * `ElectricalComponents.Analog.Basic.Tests.SaturatingInductor` - Test circuit for a saturating inductor component.
  * `ElectricalComponents.Analog.Basic.Tests.TranslationalEMF` - Test circuit for TranslationalEMF driven by a sinusoidal voltage with a mass load.
  * `ElectricalComponents.Analog.Basic.Tests.VCC` - Test circuit for VCC (voltage-controlled current source).
  * `ElectricalComponents.Analog.Basic.Tests.VCV` - Test circuit for VCV (voltage-controlled voltage source).
  * `ElectricalComponents.Analog.Basic.Tests.VariableCapacitor` - Test circuit for VariableCapacitor.
  * `ElectricalComponents.Analog.Basic.Tests.VariableConductor` - Test circuit for VariableConductor.
  * `ElectricalComponents.Analog.Basic.Tests.VariableInductor` - Test circuit for VariableInductor.

### Analog/Sensors/Tests

  * `ElectricalComponents.Analog.Sensors.Tests.MultiSensor` - A test circuit designed to verify the behavior of a MultiSensor component within
  * `ElectricalComponents.Analog.Sensors.Tests.Sensors` - A test circuit with a resistor and capacitor in series, driven by a sinusoidal voltage source, instrumented with voltage, current, and power sensors.
