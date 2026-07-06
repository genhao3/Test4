# This is a minimum set of tests to validate existence, metadata, simulation and
# FMPy compatibility of LotkaVolterra FMU defined at /refereces/lotka_volterra_fmu.dyad

using Test
using FMI
using LightXML
using Dates

# SUBSTITUTE: path to your FMU
const FMU_PATH = "/home/ven-k/.julia/scratchspaces/ca28fe3e-7809-4c0f-9d3e-a21c6e6f3e9d/JSDeploymentjl/WQTR3k/LotkaVolterra.fmu"

# --- 1a. FMU file existence and basic structure ---
@testset "FMU File Exists" begin
    @test isfile(FMU_PATH)
    @test endswith(FMU_PATH, ".fmu")
end

# --- 1b. Load and inspect metadata ---
fmu = nothing
@testset "FMU Loads Successfully" begin
    fmu = FMI.loadFMU(FMU_PATH)
    # Run `FMI.unloadFMU(fmu)` after completing the tests
    # SUBSTITUTE: FMI.FMU2 for FMI 2.0, FMI.FMU3 for FMI 3.0
    @test fmu isa FMI.FMU2
end

if fmu === nothing
    @error "FMU failed to load — skipping remaining tests"
    return
end

md = fmu.modelDescription

@testset "FMI Version" begin
    # SUBSTITUTE: your FMI version string ("2.0" or "3.0")
    @test md.fmiVersion == "2.0"
end

@testset "CoSimulation Interface Present" begin
    @test md.coSimulation !== nothing
    # SUBSTITUTE: your model name
    @test md.coSimulation.modelIdentifier == "LotkaVolterra"
end

@testset "Inputs Declared" begin
    # SUBSTITUTE: your input names (empty Set if none)
    input_names = Set(["u_1", "u_2"])
    declared = Set(v.name for v in md.modelVariables if v.causality == "input")
    @test input_names ⊆ declared
end

@testset "Outputs Declared" begin
    # SUBSTITUTE: your output names
    output_names = Set(["x_1", "x_2"])
    declared = Set(v.name for v in md.modelVariables if v.causality == "output")
    @test output_names ⊆ declared
end

# --- 1c. Basic CS simulation (smoke test) ---
@testset "CoSimulation Smoke Test" begin
    # SUBSTITUTE: simulateCS or simulateME; your output names
    sol_cs = FMI.simulateCS(fmu, (0.0, 1.0);
        recordValues=["x_1", "x_2"],
        dt=0.01)
    @test sol_cs !== nothing
    @test length(sol_cs.values.saveval) > 0
end

# --- 1d. FMPy compatibility (Python cross-tool) ---
@testset "FMPy Validation" begin
    fmpy_script = joinpath(@__DIR__, "fmpy_lotka_volterra_test.py")
    if isfile(fmpy_script)
        result = run(ignorestatus(`python3 $(fmpy_script)`))
        @test success(result)
    else
        @info "Skipping FMPy test — fmpy_lotka_volterra_test.py not found"
    end
end

FMI.unloadFMU(fmu)
