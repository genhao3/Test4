# Quick metadata-only inspection of an FMU via FMI.jl.
# Usage: julia --project=<dyad-library-project> fmu_inspect.jl <path/to.fmu>
#
# Prints FMI version, CS/ME support, model identifier, inputs, and outputs.
# Does not run the solver, so it is safe to call in-process or as a subprocess.

using FMI

length(ARGS) == 1 || error("usage: julia fmu_inspect.jl <path/to.fmu>")
fmu_path = ARGS[1]
isfile(fmu_path) || error("FMU not found: $fmu_path")

fmu = FMI.loadFMU(fmu_path)
try
    md = fmu.modelDescription
    println("fmiVersion       : ", md.fmiVersion)
    println("modelName        : ", md.modelName)
    println("CoSimulation     : ", md.coSimulation === nothing ? "no" : "yes")
    println("ModelExchange    : ", md.modelExchange === nothing ? "no" : "yes")

    inputs  = sort!(collect(v.name for v in md.modelVariables if v.causality == "input"))
    outputs = sort!(collect(v.name for v in md.modelVariables if v.causality == "output"))
    println("inputs  (", length(inputs),  ") : ", inputs)
    println("outputs (", length(outputs), ") : ", outputs)
finally
    FMI.unloadFMU(fmu)
end
