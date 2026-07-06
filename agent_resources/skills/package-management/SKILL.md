---
name: package-management
description: Ensure all dependencies are present in the workspace before compiling a Dyad package. Load before executing `compile_tool`, when the user asks to compile, or to resolve "Package not found in path" error.
---

Before compiling a Dyad project with `compile_tool`, ensure all dependencies are in the workspace environment (Project.toml) and `using` statements are added to the module when applicable.

### Check and Add Dependencies

Check the environment when:
1. You define instances of components, methods, types, and connectors from Dyad libraries.
2. You use methods or types from Julia packages.

When modifying an existing project, scan all `.dyad` files for both cases above.

Verify they are present:
```julia
Pkg.status() # For entire list of deps
Pkg.status(["ElectricalComponents", "DyadData", "DataInterpolations"])  # For specific deps; adapt to actual deps
```

- This prints path to the Project.toml
- List of available packages (along with version and short git-tree-sha)
- Any missing package is simply not printed

Add the missing packages via `Pkg.add`.

### `using` Statements

The Dyad compiler auto-imports all Dyad libraries and these Julia packages: ModelingToolkit, Markdown, Moshi, OrdinaryDiffEqDefault, RuntimeGeneratedFunctions.
For all other packages, add `using <PackageName>` in the module file (`src/<ModuleName>.jl`).

### Further Reference
- **[libraries.md](../../docs/libraries.md)**: Adding and using Dyad libraries
- **[functions.md](../../docs/functions.md)**: Using Julia functions in Dyad
