# =========================
#   SYSTEM STRUCTURE
# =========================
# IMPORTANT: Some functions need ModelingToolkit prefix
using ModelingToolkit

unknowns(sys)                              # Vector of symbolic unknowns (algebraic + differential)
parameters(sys)                            # Vector of parameters
observed(sys)                              # Vector of observed/measurement equations (outputs)
equations(sys)                             # Vector of all equations (Equation objects)
initialization_equations(sys)              # Vector of initialization equations (if defined on sys)

# Independent variable access (note: PLURAL for the function!)
ModelingToolkit.independent_variables(sys) # Returns Vector{Sym} (usually length 1)
ModelingToolkit.get_iv(sys)                # Returns single independent variable (e.g., t)

# Initial conditions, guesses, and bindings
ModelingToolkit.initial_conditions(sys)    # Dict of initial conditions and parameter values
ModelingToolkit.guesses(sys)              # Dict of guesses for algebraic variables
ModelingToolkit.bindings(sys)             # Dict of parameter bindings (immutable constraints)
ModelingToolkit.bound_parameters(sys)     # Inspect which parameters are bound (use on system after complete())
# Per-variable metadata:
ModelingToolkit.hasdefault(var)            # true if variable has a default value
ModelingToolkit.getdefault(var)            # Get the default value of a variable

# Subsystems
ModelingToolkit.get_systems(sys)           # Vector of subsystems

# =========================
#   SYMBOLIC INSPECTION
# =========================
# IMPORTANT: Import Symbolics from ModelingToolkit
using ModelingToolkit: Symbolics

# Working with Equation objects
eq = equations(sys)[i]             # Get an equation
eq.lhs                             # Left-hand side (FIELD access, not function)
eq.rhs                             # Right-hand side (FIELD access, not function)

# Extract all lhs/rhs from equations
[eq.lhs for eq in equations(sys)]  # LHS vector of all equations
[eq.rhs for eq in equations(sys)]  # RHS vector of all equations

# Working with symbolic expressions (NOT Equation objects)
expr = eq.rhs                      # Get expression from equation
Symbolics.istree(expr)             # true if expression is a tree (has operation)
Symbolics.arguments(expr)          # Children of expression (only if istree)
Symbolics.operation(expr)          # Operation at root of expression tree
Symbolics.get_variables(expr)      # Variables appearing in expr (returns Set)

ModelingToolkit.isdifferential(x)  # true if x is Differential(var)

# Finding variables in an equation (v11: use Symbolics.get_variables instead of ModelingToolkit.vars)
vars_in_eq = union(Symbolics.get_variables(eq.lhs), Symbolics.get_variables(eq.rhs))

# Substitution & simplification
Symbolics.substitute(expr, Dict(x => y))  # Substitute symbols in expr
Symbolics.expand(expr)                       # Algebraic expand
Symbolics.simplify(expr)                     # Algebraic simplify

# =========================
#   JACOBIANS & SPARSITY
# =========================
eqs = equations(sys)
vars = unknowns(sys)

# For Jacobian, need to work with expressions (rhs - lhs)
expr_vec = [eq.rhs - eq.lhs for eq in eqs]
J = ModelingToolkit.jacobian(expr_vec, vars)     # Symbolic Jacobian ∂eqs/∂vars (Matrix{Num})
S = Symbolics.jacobian_sparsity(expr_vec, vars) # Sparse pattern (SparseMatrixCSC{Bool,Int})
Symbolics.hessian(expr, vars)                    # Hessian for scalar expr

# Dependency utilities
ModelingToolkit.variable_dependencies(sys)   # BipartiteGraph (not a simple Dict!)
ModelingToolkit.equation_dependencies(sys)   # Vector{Vector} of variable indices per equation

# =========================
#   STRUCTURAL REDUCTION
# =========================
sys_expanded = expand_connections(sys)       # Expand connect() into KCL/KVL equations
sys_simpl = mtkcompile(sys)                 # Compiled/reduced DAE/ODE system
equations(sys_simpl)                         # Reduced equations
unknowns(sys_simpl)                          # Reduced unknowns
observed(sys_simpl)                          # Reduced observables

# =========================
#   BUILDING PROBLEMS
# =========================
# ODE/DAE problems from system
using OrdinaryDiffEqDefault

prob = ODEProblem(sys_simpl, [], (t0, tf))                                       # ODEProblem using values from initial_conditions
prob = ODEProblem(sys_simpl, [sys_simpl.x => 0.0, sys_simpl.a => 1.0], (t0, tf)) # Override initial conditions and/or parameters

# Quick reads off the problem
prob.u0                                 # Initial state vector (Vector{Float64})
prob.p                                  # Parameter vector (MTKParameters struct)
prob.f                                  # ODEFunction (contains system info)

# Accessing prob.f fields
prob.f.mass_matrix                      # Mass matrix (if DAE system)
prob.f.sys                              # The system used to build the problem
prob.f.observed                         # ObservedFunctionCache for computing observables
prob.f.initialization_data              # Initialization problem data (if present)

# =========================
#   SOLVING & SOLUTION ACCESS
# =========================
sol = solve(prob)                       # Let `solve` pick the appropriate solver

# Time grid & raw arrays
sol.t                                   # Vector{Float64} of time points
sol.u                                   # Vector{Vector{Float64}} of state vectors

# SymbolicIndexingInterface: access variables by symbolic name
sol[sys_simpl.x]                        # Vector of x values over saved times
sol[sys_simpl.x][end]                   # Final value of x
sol[(sys_simpl.x, sys_simpl.y)]         # Tuple of vectors for multiple vars

# Interpolation at arbitrary time t
sol(t, idxs=sys_simpl.x)              # x(t) (0th derivative)
sol(t)                                  # Full state vector at time t

# Time-derivatives from the interpolant
sol(t, Val{1}, idxs=sys_simpl.x)      # dx/dt at time t (1st derivative)
sol(t, Val{2}, idxs=sys_simpl.x)      # d²x/dt² at time t (2nd derivative, if supported)

# =========================
#   INITIALIZATION INTROSPECTION
# =========================
# Equations & initial values used for consistent initialization
initialization_equations(sys)           # Initialization eqs attached to sys
ModelingToolkit.initial_conditions(sys) # Dict of initial conditions and parameter values
ModelingToolkit.guesses(sys)           # Dict of guesses (for algebraic variables)
ModelingToolkit.bindings(sys)          # Dict of bindings (immutable parameter constraints)

# From a built problem
prob.u0                                   # Evaluated initial conditions vector
prob.p                                    # Evaluated parameters (MTKParameters)
prob.f.sys                                # The system used to build the problem
prob.f.initialization_data                # Initialization data (OverrideInitData)
prob.f.initialization_data.initializeprob # NonlinearProblem, NonlinearLeastSquaresProblem, or SCCNonlinearProblem solved at t=0

# Residual checks at t0 (symbolic -> numeric)
iv = ModelingToolkit.get_iv(sys_simpl)
eqs = equations(sys_simpl)
eqs_at_t0 = [Symbolics.substitute(eq.lhs, Dict(iv => t0)) ~
    Symbolics.substitute(eq.rhs, Dict(iv => t0)) for eq in eqs]
# Now evaluate numerically using a Dict mapping variables/params to values

# For debugging inconsistent initial equations, substitute in all values
# Find equations which are impossible to satisfy, for example `1 ~ 0`
# These equations should then be highlighted as inconsistent either due to
# Having an extra condition on one of the internal variables or the equation itself
# Needs to be removed.
all_values = merge(Dict(ModelingToolkit.initial_conditions(sys)), Dict(iv => t0))
eqs_at_t0 = [Symbolics.substitute(eq.lhs, all_values) ~
    Symbolics.substitute(eq.rhs, all_values) for eq in eqs]

# =========================
#   I/O & OBSERVABLES
# =========================
observed(sys)                           # Vector of observed equations (before reduction)
observed(sys_simpl)                     # Observables after mtkcompile
# Often more observables after reduction!

# Accessing observable expressions
obs = observed(sys_simpl)
if length(obs) > 0
    first_obs = obs[1]                  # One observed equation (lhs ~ rhs)
    first_obs.lhs                       # Left-hand side (the observable symbol)
    first_obs.rhs                       # Right-hand side (how to compute it)
end

# Computing observables from solution
sol[obs[1].lhs]                         # Get time series of an observable

# =========================
#   FAST SUMMARIES & UTILITIES
# =========================
# Quick system balance checks
length(equations(sys)), length(unknowns(sys))     # Equation count vs unknown count

# Finding differential variables (states)
# Note: After mtkcompile, check the reduced system
eqs = equations(sys_simpl)
# Look for der(...) or D(...) in equations to identify differential states

# Variables referenced by each equation
[union(Symbolics.get_variables(eq.lhs), Symbolics.get_variables(eq.rhs)) for eq in equations(sys)]

# =========================
#   DIAGNOSTIC QUERIES: How to answer "Why did X fail?"
# =========================

# Debug mode: wrap system to catch domain errors with symbolic context
using ModelingToolkit: debug_system
sys_debug = debug_system(sys)
sys_debug_compiled = mtkcompile(sys_debug)

# Q: Which equations involve a specific variable?
target_var = unknowns(sys)[i]
eqs_with_var = [eq for eq in equations(sys) if target_var in Symbolics.get_variables(eq.rhs) || target_var in Symbolics.get_variables(eq.lhs)]

# Q: What's the residual of an equation at specific values?
# (Check if equation is satisfied)
# NOTE: Equations often contain observables, not just unknowns
# So symbolic substitution with only unknowns won't work!
# RECOMMENDED: Evaluate each term with sol() instead
eq = equations(sys_simpl)[i]
t_check = sol.t[end]
# Example: if eq is "0 ~ -q1.Ic(t) + rc.i(t)"
q1_Ic = sol(t_check, idxs=sys.q1.Ic)  # Evaluate observable
rc_i = sol(t_check, idxs=sys.rc.i)    # Evaluate observable
residual = -q1_Ic + rc_i  # Manual calculation matching equation structure
# residual ≈ 0 means equation is satisfied

# Q: Where/when did the solver fail?
sol.retcode                    # Check with: sol.retcode == ReturnCode.Success
sol.t[end]                     # Time when solver stopped
sol.u[end]                     # State vector at failure
# Common retcodes: ReturnCode.Unstable, ReturnCode.InitialFailure, ReturnCode.DtLessThanMin

# Q: Does my system have a mass matrix?
prob = ODEProblem(sys_simpl, [], (0.0, 1.0))
prob.f.mass_matrix !== nothing # true = mass_matrix exists

# Q: What variables need initial conditions vs guesses?
# Initial conditions: for differential states (variables with der(x) in equations)
# Guesses: for algebraic variables in cycles
# Check initialization problem:
prob.f.initialization_data.initializeprob  # The nonlinear problem for t=0

# Q: How do I isolate and solve the initialization problem in order to identify problematic equations?
init_sol = solve(prob.f.initialization_data.initializeprob)
# Values of the residual should be sufficiently close to zero, `init_sol.resid[i]` gives the initialization equations
# which are not sufficiently close
init_sol.resid
# To then identify which equation is the issue, look at the initialization system
init_sys = prob.f.initialization_data.initializeprob.f.sys
equations(init_sys)[i]
# This can be used to find and print which initialization equation is not being satisfied

# Q: Which variables are in a cyclic dependency? (from error message)
# Error shows: "rb2₊v(t) => 5.0 + (100000*r_timing1₊v(t))/..."
# → rb2₊v depends on r_timing1₊v which depends on rb2₊v
# FIX: Add guess in relations block to break cycle: guess v = 1.0

# Q: What are the actual equation residuals at a point?
# NOTE: Symbolic substitution won't work if equations contain observables
# RECOMMENDED: Manually evaluate each term in the equation with sol()
t_check = 0.5
for (i, eq) in enumerate(equations(sys_simpl))
    println("Equation [$i]: ", eq)
    # Extract terms from equation and evaluate each with sol()
    # Example for "0 ~ -q1.Ic(t) + rc.i(t)":
    # q1_Ic = sol(t_check, idxs=sys.q1.Ic)
    # rc_i = sol(t_check, idxs=sys.rc.i)
    # res = -q1_Ic + rc_i
    # println("  Residual: ", res, " ", abs(res) < 1e-6 ? "✓" : "✗")
end

# Alternative (advanced): Full symbolic substitution with observables+parameters
# Requires: unknowns, time, all observables, all parameters with correct refs
# Needs 5-10 substitution passes for nested observables
# Generally NOT recommended - use sol() approach above instead

# Q: Which equations are differential vs algebraic?
eqs = equations(sys_simpl)
is_differential = ModelingToolkit.is_diff_equation.(eqs)  # Returns Bool mask
# Differential equations: indices where is_differential[i] == true
# IMPORTANT: Use the MTK API, NOT string parsing like occursin("der", string(eq))

# Q: What's the sparsity pattern? (which vars appear in which eqs, known as the incidence matrix)
vars = unknowns(sys_simpl)
eqs = equations(sys_simpl)
for (i, eq) in enumerate(eqs)
    vars_in_eq = union(Symbolics.get_variables(eq.lhs), Symbolics.get_variables(eq.rhs))
    println("Eq $i uses: ", vars_in_eq)
end

# Q: What observables can I access after solving?
obs = observed(sys_simpl)
observable_symbols = [o.lhs for o in obs]  # These are accessible via sol[symbol]

# Q: How do I check conservation laws?
# Example: Kirchhoff's current law at a node
# Sum currents at node
node_currents = [sys_simpl.comp1.p.i, sys_simpl.comp2.n.i, sys_simpl.comp3.p.i]
kcl_check = sum(sol[c] for c in node_currents)  # Should be ≈ 0 at all times

# Q: What's causing a variable to diverge?
# Check the equation that defines it
diverging_var = sys_simpl.my_var
eq_defining_var = findfirst(eq -> eq.lhs == diverging_var, equations(sys_simpl))
equations(sys_simpl)[eq_defining_var]  # Inspect this equation
# Check for: positive feedback, zero derivative, missing damping

# Q: How do I find which component a variable belongs to?
var = unknowns(sys_simpl)[i]
var_name = string(var)  # Shows full hierarchical name like "comp₊subcomp₊x(t)"
# Parse the ₊ separators to see component hierarchy

# Q: My ODE solve is failing because of a bad return like dt<dtmin or divergence when in theory it should not
# How do I find out which variables or equations are the issue?
final_value = sol.u[end]
final_der = prob.f(final_value, prob.p, sol.t[end])
# Look at the final derivative values, outliers are the likely cause of the issue

# =========================
#   COMMON WORKFLOW SUMMARY
# =========================
# 1. Build system
# sys = MyComponent(name=:mysys)

# 2. Expand connections (if using connect())
# sys_expanded = expand_connections(sys)

# 3. Compile/simplify structure
# sys_simpl = mtkcompile(sys)

# Or combine steps 1+3 with the macro: @mtkcompile sys_simpl = MyComponent()

# 4. Inspect reduced system
# unknowns(sys_simpl)    # What variables remain?
# equations(sys_simpl)   # What equations remain?
# observed(sys_simpl)    # What can be computed from states?

# 5. Build problem
# prob = ODEProblem(sys_simpl, [], (0.0, 10.0))

# 6. Solve (use DAE solver if mass matrix present!)
# sol = solve(prob)

# 7. Access results
# sol[sys_simpl.my_var]  # Time series of a variable
# sol(5.0, idxs=sys_simpl.my_var)  # Value at t=5.0
