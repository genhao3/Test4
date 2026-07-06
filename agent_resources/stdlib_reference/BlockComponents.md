# BlockComponents

This is the documentation for the `BlockComponents` library.  Here you will find the documentation for the various definitions contained in `BlockComponents`, grouped by sub-library.

Items are listed with their fully-qualified dotted path. Use that exact path when referencing a component in Dyad code (e.g. `extends BlockComponents.Interfaces.SISO`).

Note that this documentation is automatically generated primarily from the doc strings and metadata associated with those definitions.

## Types

### Interfaces

  * `BlockComponents.Interfaces.SI2SO` - Partial component definition with two inputs and one output.
  * `BlockComponents.Interfaces.SISO` - Single input single output (SISO) base block, a partial component that defines the interface for blocks with one input and one output signal.
  * `BlockComponents.Interfaces.SO` - Standard output interface with a single real output connector.
  * `BlockComponents.Interfaces.Signal` - Base component for signal generators that output time-varying signals.
  * `BlockComponents.Interfaces.SingleVariableController` - Interface for single-variable continuous controllers with setpoint input, measurement input, and control output.

### Sources

  * `BlockComponents.Sources.ChirpLaw` - This enum defines the available chirp types

### Tables

  * `BlockComponents.Tables.ExtrapolationType` - Specifies the extrapolation method used for the 1D innterpolation when trying to access values outside of the given data.
  * `BlockComponents.Tables.InterpolationDimension` - Specifies the interpolation method for each dimension in 2D table interpolation (`InterpolatedTable`).
  * `BlockComponents.Tables.InterpolationType` - Specifies the interpolation method used for 1D interpolation in the `Interpolation` component.
  * `BlockComponents.Tables.Real2RealInterpolator`
  * `BlockComponents.Tables.TableInterpolator`

## Components

### Continuous

  * `BlockComponents.Continuous.Derivative` - Filtered derivative approximation with configurable time constant and gain.
  * `BlockComponents.Continuous.FirstOrder` - First-order filter with a single real pole and adjustable gain.
  * `BlockComponents.Continuous.Integrator` - Integrates the input signal with optional gain factor.
  * `BlockComponents.Continuous.LimPID` - PID controller with limited output, back calculation anti-windup compensation, setpoint weighting and feed-forward
  * `BlockComponents.Continuous.LimPIDExternalDerivative` - PID controller with limited output, anti-windup, and an external derivative input.
  * `BlockComponents.Continuous.Plant` - Second-order linear system for testing control designs.
  * `BlockComponents.Continuous.SecondOrder` - Second-order filter with configurable gain, bandwidth, and damping ratio.
  * `BlockComponents.Continuous.StateSpace` - Linear state-space system with operating point support.

### Math

  * `BlockComponents.Math.Add` - Weighted adder that outputs the sum of two scalar inputs with configurable gains.
  * `BlockComponents.Math.Add3` - Weighted summation block that adds three scalar inputs with configurable gains.
  * `BlockComponents.Math.Division` - Divides first input by second input.
  * `BlockComponents.Math.Feedback` - Computes the difference between a reference input and a feedback input.
  * `BlockComponents.Math.Gain` - Multiplies input signal by a constant gain factor.
  * `BlockComponents.Math.Product` - Multiplies two input signals and outputs their product.
  * `BlockComponents.Math.ReverseCausality` - Forces equality between two input signals by computing an implicit output.

### Nonlinear

  * `BlockComponents.Nonlinear.Limiter` - Signal limiter that constrains input values between specified boundaries.
  * `BlockComponents.Nonlinear.SlewRateLimiter` - Limits the rate of change of a signal between specified rising and falling rates.

### Routing

  * `BlockComponents.Routing.RealPassThrough` - Pass a Real signal through without modification.
  * `BlockComponents.Routing.Terminator` - Signal termination block that consumes input signals without further processing.

### Sources

  * `BlockComponents.Sources.Chirp` - The `Chirp` block generates a time-varying frequency sweep signal (chirp).
  * `BlockComponents.Sources.Constant` - Provides a constant output signal of value k.
  * `BlockComponents.Sources.ContinuousClock` - Generates a continuous time signal that starts counting from a specified time.
  * `BlockComponents.Sources.Cosine` - Generates a cosine wave with configurable parameters.
  * `BlockComponents.Sources.CosineVariableFrequencyAndAmplitude` - Cosine voltage source with variable frequency and amplitude
  * `BlockComponents.Sources.ExpSine` - Exponentially damped sine wave with configurable amplitude, frequency, and damping.
  * `BlockComponents.Sources.Pulse` - Single pulse generator with configurable amplitude, duration, and start time.
  * `BlockComponents.Sources.Ramp` - Generates a linearly increasing signal from an offset to a target value over a specified duration.
  * `BlockComponents.Sources.Sine` - Generates a sine wave signal with configurable parameters.
  * `BlockComponents.Sources.SineVariableFrequencyAndAmplitude` - Sine voltage source with adjustable frequency and amplitude through external signals.
  * `BlockComponents.Sources.Square` - Square wave generator that alternates between positive and negative values.
  * `BlockComponents.Sources.Step` - Generates a step signal that transitions from `offset` to `height+offset` at the specified time.
  * `BlockComponents.Sources.Triangular` - Triangular waveform generator with configurable amplitude and frequency.

### Tables

  * `BlockComponents.Tables.InterpolatedTable`
  * `BlockComponents.Tables.Interpolation` - Performs interpolation on input values using a specified dataset and interpolation method.
  * `BlockComponents.Tables.ParameterizedInterpolation` - Performs interpolation of values based on an input signal using externally defined parameters.
  * `BlockComponents.Tables.ScalarInterpolation` - Performs interpolation on input values using a specified dataset and interpolation method.

## Tests

### Continuous/Tests

  * `BlockComponents.Continuous.Tests.DerivativeIntegratorTerminator` - Test component that demonstrates the chained behavior of differentiation and integration of a sine signal.
  * `BlockComponents.Continuous.Tests.FirstOrder` - Test fixture for evaluating first-order system response to constant input.
  * `BlockComponents.Continuous.Tests.LimPID` - Test bench for a limited PID controller connected to a plant model with step input.
  * `BlockComponents.Continuous.Tests.LimPIDExternalDerivative` - Test bench for the LimPIDExternalDerivative controller connected to a plant model.
  * `BlockComponents.Continuous.Tests.SecondOrder` - Second-order system test with constant input.
  * `BlockComponents.Continuous.Tests.StateSpaceTest` - Test component for StateSpace block demonstrating basic functionality.

### Math/Tests

  * `BlockComponents.Math.Tests.Add` - Adds two constant values to produce a sum of 3.
  * `BlockComponents.Math.Tests.Add3` - Test the functionality of the Add3 block by connecting three constant inputs.
  * `BlockComponents.Math.Tests.Division` - Division operation that divides a first input by a second input.
  * `BlockComponents.Math.Tests.Feedback` - Computes the difference between two input signals.
  * `BlockComponents.Math.Tests.Product` - Multiplies two constant values together.

### Nonlinear/Tests

  * `BlockComponents.Nonlinear.Tests.Limiter` - Test harness for the Limiter component that constrains signals to specified bounds.
  * `BlockComponents.Nonlinear.Tests.SlewRateLimiter` - Test component that validates SlewRateLimiter behavior with a sinusoidal input.

### Sources/Tests

  * `BlockComponents.Sources.Tests.Chirp` - Test component that verifies linear, quadratic, and exponential chirp signal generators.
  * `BlockComponents.Sources.Tests.ContinuousClock` - Test that evaluates a continuous clock signal integrated over time.
  * `BlockComponents.Sources.Tests.Cosine` - Tests the integration of a cosine signal with configurable parameters.
  * `BlockComponents.Sources.Tests.ExpSine` - Test component that connects an exponentially damped sine wave to an integrator for validation.
  * `BlockComponents.Sources.Tests.Pulse` - Generates a pulse signal with configurable parameters and integrates it.
  * `BlockComponents.Sources.Tests.Ramp` - Test passing a ramp signal to an integrator for verification purposes.
  * `BlockComponents.Sources.Tests.Sine` - Test component that integrates a sine wave with specific parameters.
  * `BlockComponents.Sources.Tests.Square` - Connects a square wave generator to an integrator to test integration of a periodic signal.
  * `BlockComponents.Sources.Tests.Step` - Test that validates step response behavior by connecting a step signal to a terminator.
  * `BlockComponents.Sources.Tests.Triangular` - A test component that integrates a triangular signal over time.
  * `BlockComponents.Sources.Tests.VariableSinCos` - Test component for sine and cosine generators with variable frequency and amplitude inputs.

### Tables/Tests

  * `BlockComponents.Tables.Tests.InterpolatedTable`
  * `BlockComponents.Tables.Tests.InterpolationExtrapolation` - Tests interpolation with extrapolation by applying linear interpolation with constant extrapolation.
  * `BlockComponents.Tables.Tests.InterpolationFile` - Tests time-based interpolation using data from a CSV file.
  * `BlockComponents.Tables.Tests.InterpolationJuliaHubDataset` - Test time-dependent interpolation of JuliaHub dataset values.
  * `BlockComponents.Tables.Tests.InterpolationTable` - Tests interpolation by applying linear interpolation to a dataset of squares.
  * `BlockComponents.Tables.Tests.ParameterizedInterpolation`
  * `BlockComponents.Tables.Tests.ParameterizedInterpolationExtrapolation` - Tests parameterized interpolation with extrapolation on a mass-spring-damper system.
  * `BlockComponents.Tables.Tests.ScalarInterpolationFile` - Tests time-based interpolation using data from a CSV file.
