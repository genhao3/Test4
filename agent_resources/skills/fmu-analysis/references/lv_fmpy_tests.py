# FMPy tests of LotkaVolterra FMU defined at /refereces/lotka_volterra_fmu.dyad

import fmpy
import sys
import numpy as np

fmu = "/home/ven-k/.julia/scratchspaces/ca28fe3e-7809-4c0f-9d3e-a21c6e6f3e9d/JSDeploymentjl/WQTR3k/LotkaVolterra.fmu"

# Validate FMU metadata
print("=== FMU Dump ===")
fmpy.dump(fmu)

# Simulate with default settings
print("\n=== Simulating with defaults ===")
result = fmpy.simulate_fmu(fmu, stop_time=10.0, output_interval=0.01)

# Validate result structure
assert result is not None, "Simulation returned None"
assert len(result) > 0, "Simulation returned empty result"

# Check expected output columns exist
col_names = result.dtype.names
assert 'x_1' in col_names, f"x_1 not in output columns: {col_names}"
assert 'x_2' in col_names, f"x_2 not in output columns: {col_names}"

# Check outputs are finite and non-trivial
x1 = result['x_1']
x2 = result['x_2']
assert np.all(np.isfinite(x1)), "x_1 contains non-finite values"
assert np.all(np.isfinite(x2)), "x_2 contains non-finite values"
assert not np.allclose(x1, 0.0), "x_1 is all zeros"
assert not np.allclose(x2, 0.0), "x_2 is all zeros"

# Simulate with input signals
print("\n=== Simulating with inputs ===")
t = np.linspace(0, 10, 1001)
input_signals = np.column_stack([
    t,
    0.01 * np.exp(-t),   # u_1
    0.01 * np.cos(t),    # u_2
])
result_with_input = fmpy.simulate_fmu(
    fmu,
    stop_time=10.0,
    output_interval=0.01,
    input=input_signals,
    input_signals=['u_1', 'u_2'],
)
assert result_with_input is not None, "Simulation with inputs returned None"
assert len(result_with_input) > 0, "Simulation with inputs returned empty result"

print("\nAll FMPy tests passed.")
