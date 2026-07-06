# This is a larger set of tests to more extensively validate the metadata, file structure and
# simulation using FMI of LotkaVolterra FMU defined at /refereces/lotka_volterra_fmu.dyad

using Test
using FMI
using LightXML
using Dates

# SUBSTITUTE: path to your FMU
const FMU_PATH = "/home/ven-k/.julia/scratchspaces/ca28fe3e-7809-4c0f-9d3e-a21c6e6f3e9d/JSDeploymentjl/WQTR3k/LotkaVolterra.fmu"

fmu = FMI.loadFMU(FMU_PATH)
# Run `FMI.unloadFMU(fmu)` after completing the tests
md = fmu.modelDescription

# --- Detailed Metadata Validation ---
@testset "Metadata — XML Structure" begin
  # Parse raw XML for detailed checks
  tmpdir = mktempdir()
  run(`unzip -o $(FMU_PATH) -d $(tmpdir)`)
  xml_path = joinpath(tmpdir, "modelDescription.xml")
  @test isfile(xml_path)

  xdoc = parse_file(xml_path)
  xroot = root(xdoc)

  @testset "fmiModelDescription Attributes" begin
    @test name(xroot) == "fmiModelDescription"
    # SUBSTITUTE: your FMI version string ("2.0" or "3.0")
    @test attribute(xroot, "fmiVersion") == "2.0"
    # SUBSTITUTE: your model name
    @test attribute(xroot, "modelName") == "LotkaVolterra"
    @test !isnothing(attribute(xroot, "guid"))
  end

  @testset "CoSimulation Element" begin
    xCS = find_element(xroot, "CoSimulation")
    @test xCS !== nothing
    # SUBSTITUTE: your model name
    @test attribute(xCS, "modelIdentifier") == "LotkaVolterra"
  end

  @testset "DefaultExperiment" begin
    xDE = find_element(xroot, "DefaultExperiment")
    if xDE !== nothing
      start_t = attribute(xDE, "startTime")
      stop_t = attribute(xDE, "stopTime")
      @test start_t !== nothing
      @test stop_t !== nothing
      @test parse(Float64, stop_t) > parse(Float64, start_t)
    end
  end

  @testset "ModelVariables — Inputs" begin
    xMV = find_element(xroot, "ModelVariables")
    vars = child_elements(xMV) |> collect
    input_vars = filter(v -> attribute(v, "causality") == "input", vars)
    input_var_names = Set(attribute(v, "name") for v in input_vars)
    # SUBSTITUTE: your input names (remove these checks if no inputs)
    @test "u_1" in input_var_names
    @test "u_2" in input_var_names
    for iv in input_vars
      @test attribute(iv, "variability") in ("continuous", nothing)
      xReal = find_element(iv, "Real")
      @test xReal !== nothing
    end
  end

  @testset "ModelVariables — Outputs" begin
    xMV = find_element(xroot, "ModelVariables")
    vars = child_elements(xMV) |> collect
    output_vars = filter(v -> attribute(v, "causality") == "output", vars)
    output_var_names = Set(attribute(v, "name") for v in output_vars)
    # SUBSTITUTE: your output names
    @test "x_1" in output_var_names
    @test "x_2" in output_var_names
  end

  @testset "ModelStructure — Outputs Declared" begin
    xMS = find_element(xroot, "ModelStructure")
    xOutputs = find_element(xMS, "Outputs")
    @test xOutputs !== nothing
    output_entries = child_elements(xOutputs) |> collect
    # SUBSTITUTE: expected number of outputs
    @test length(output_entries) >= 2
  end

  free(xdoc)
  rm(tmpdir; recursive=true)
end

# --- FMU File Structure Validation ---
@testset "FMU File Structure" begin
  tmpdir = mktempdir()
  run(`unzip -o $(FMU_PATH) -d $(tmpdir)`)

  @test isdir(joinpath(tmpdir, "binaries"))
  @test isfile(joinpath(tmpdir, "modelDescription.xml"))

  if Sys.islinux()
    @test isdir(joinpath(tmpdir, "binaries", "linux64"))
    so_files = filter(f -> endswith(f, ".so"), readdir(joinpath(tmpdir, "binaries", "linux64")))
    @test length(so_files) >= 1
  elseif Sys.iswindows()
    @test isdir(joinpath(tmpdir, "binaries", "win64"))
    dll_files = filter(f -> endswith(f, ".dll"), readdir(joinpath(tmpdir, "binaries", "win64")))
    @test length(dll_files) >= 1
  end

  # No symlinks
  symlinks = 0
  for (rt, dirs, files) in walkdir(tmpdir; follow_symlinks=true)
    for file in files
      symlinks += islink(joinpath(rt, file))
    end
  end
  @test symlinks == 0

  rm(tmpdir; recursive=true)
end

# --- Simulation / FMI Tests ---
@testset "CoSimulation — Full Run" begin
  tspan = (0.0, 10.0)
  # SUBSTITUTE: simulateCS or simulateME; your output names
  sol_cs = FMI.simulateCS(fmu, tspan;
    recordValues=["x_1", "x_2"],
    dt=0.001)
  @test sol_cs !== nothing

  @testset "Solution has expected length" begin
    @test length(sol_cs.values.saveval) > 0
  end

  @testset "Outputs are finite" begin
    for vals in sol_cs.values.saveval
      @test all(isfinite, collect(vals))
    end
  end

  @testset "Outputs are non-trivial (not all zero)" begin
    all_x1 = [collect(v)[1] for v in sol_cs.values.saveval]
    all_x2 = [collect(v)[2] for v in sol_cs.values.saveval]
    @test !all(iszero, all_x1)
    @test !all(iszero, all_x2)
  end
end

@testset "CoSimulation — With Input Function" begin
  # SUBSTITUTE: your input function matching your model's inputs
  input_fn = function (t, u)
    u[1] = 0.01 * exp(-t)
    u[2] = 0.01 * cos(t)
  end

  # SUBSTITUTE: your input and output names
  sol_cs = FMI.simulateCS(fmu, (0.0, 5.0);
    inputFunction=input_fn,
    inputValueReferences=["u_1", "u_2"],
    recordValues=["x_1", "x_2"],
    dt=0.001)
  @test sol_cs !== nothing
  @test length(sol_cs.values.saveval) > 0

  for vals in sol_cs.values.saveval
    @test all(isfinite, collect(vals))
  end
end

@testset "CoSimulation — Short Interval" begin
  # SUBSTITUTE: your output names
  sol_cs = FMI.simulateCS(fmu, (0.0, 0.1);
    recordValues=["x_1", "x_2"],
    dt=0.001)
  @test sol_cs !== nothing
  @test length(sol_cs.values.saveval) > 0
end

@testset "CoSimulation — Different Step Sizes" begin
  for dt in [0.1, 0.01, 0.001]
    # SUBSTITUTE: your output names
    sol = FMI.simulateCS(fmu, (0.0, 1.0);
      recordValues=["x_1", "x_2"],
      dt=dt)
    @test sol !== nothing
    @test length(sol.values.saveval) > 0
  end
end

@testset "CoSimulation — Consistency Across Runs" begin
  # SUBSTITUTE: your output names
  sol1 = FMI.simulateCS(fmu, (0.0, 1.0);
    recordValues=["x_1", "x_2"],
    dt=0.01)
  sol2 = FMI.simulateCS(fmu, (0.0, 1.0);
    recordValues=["x_1", "x_2"],
    dt=0.01)

  vals1 = collect.(sol1.values.saveval)
  vals2 = collect.(sol2.values.saveval)
  @test vals1 ≈ vals2 rtol = 1e-10
end

@testset "Get/Set Variables" begin
  # SUBSTITUTE: fmi2 functions for FMI 2.0, fmi3 functions for FMI 3.0
  comp = FMI.fmi2Instantiate!(fmu)
  @test comp !== nothing

  FMI.fmi2SetupExperiment(comp, 0.0, 10.0)
  FMI.fmi2EnterInitializationMode(comp)

  @testset "Set and Get Inputs" begin
    # SUBSTITUTE: your input names
    input_refs = FMI.fmi2StringToValueReference(fmu.modelDescription, ["u_1", "u_2"])
    FMI.fmi2SetReal(comp, input_refs, [0.5, 0.3])
    vals = FMI.fmi2GetReal(comp, input_refs)
    @test vals ≈ [0.5, 0.3]
  end

  FMI.fmi2ExitInitializationMode(comp)

  @testset "Read Outputs" begin
    # SUBSTITUTE: your output names
    output_refs = FMI.fmi2StringToValueReference(fmu.modelDescription, ["x_1", "x_2"])
    vals = FMI.fmi2GetReal(comp, output_refs)
    @test all(isfinite, vals)
  end

  FMI.fmi2Terminate(comp)
  FMI.fmi2FreeInstance!(comp)
end

@testset "Reset and Re-simulate" begin
  # SUBSTITUTE: your output names
  sol1 = FMI.simulateCS(fmu, (0.0, 1.0);
    recordValues=["x_1", "x_2"],
    dt=0.01)

  sol2 = FMI.simulateCS(fmu, (0.0, 1.0);
    recordValues=["x_1", "x_2"],
    dt=0.01)

  vals1 = collect.(sol1.values.saveval)
  vals2 = collect.(sol2.values.saveval)
  @test vals1 ≈ vals2 rtol = 1e-10
end

FMI.unloadFMU(fmu)
