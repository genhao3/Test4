---
name: forensic-debugging
description: Forensic debugging workflow for diagnosing structural errors, simulation failures, validation failures, and timeouts in Dyad/MTK models. Provides step-by-step procedures for isolating root causes, tracing computations, and testing fixes in the persistent Julia session before editing Dyad code. Load when julia_tool execution fails or produces unexpected results.
---

# Forensic Debugging

Investigation determines the fix through mathematical proof. The solver tells you exactly what it's doing — measure, don't guess.

## When to use

- Initialization issues: ODEProblem construction fails, contradictory constraints
- Structural issues: Unbalanced system, over/under-determined, circular dependencies
- Simulation failures: `using SciMLBase; !SciMLBase.successful_retcode(sol)` (Unstable, InitialFailure, DtLessThanMin, etc.)
- Validation failures: `SciMLBase.successful_retcode(sol)` returns true but physics is wrong

Do NOT use for: Syntax/compile errors (fix and recompile instead)

After identifying the root cause, if you are unclear how to implement the fix in Dyad:
1. Search agent_resources/docs/ for relevant documentation
2. Read the appropriate doc (syntax.md, initialization.md, arrays.md, functions.md, etc.)
3. Apply the solution using correct Dyad patterns — do not guess

Your core task when a failure occurs is to perform forensic analysis that traces it back to its origin through mathematical proof. Every failure is a symptom — your mission is to find the precise source.

## Objective: Find the Original Error

The target of your investigation is **ALWAYS** the **Original Error**: the single, **earliest event in the forward causal chain** where the model's behavior first deviates from correctness. This could be:
- A physical equation error (wrong term, sign, connection)
- An invalid initial condition or parameter
- A solver configuration inappropriate for the physics (wrong algorithm, tolerance, or initialization strategy)

Do not stop at downstream symptoms like an exponential curve or a NaN value; trace the causality back to its true, foundational source.

## Method: The Universal Backward Trace

You will use a **Backward Trace** to find this origin. This is your universal heuristic for all failures: structural, initialization, simulation, and validation.

1. **Isolate the Symptom:** Start with the specific error message, failed variable, equation, or structural imbalance. This is your first clue, not the final answer.

2. **Trace Back the Computation:** Identify the equation that produced this symptom. Calculate all of its inputs at the last valid moment before the failure using actual numerical values.

3. **Apply the Quantitative Physicality Test:** For each input, calculate the expected value from governing physics and compare to the actual value:
   * Use the physics that governs this domain: Ohm's law (V=IR), KCL (Σi=0), KVL (Σv=0), component equations (Q=CV, Φ=LI), conservation laws (energy, mass, momentum), or domain-specific relations
   * Calculate expected value in julia_tool, then compute: error = |actual - expected| / expected
   * If error is significant (>10%), the input is non-physical. The true error happened earlier. Pick the most erroneous input and repeat from Step 2.
   * If all inputs have acceptable error (<10%), you have found the source. The equation received valid inputs but produced invalid output - the equation itself is the flaw.

4. **Identify the Origin:** This backward trace must terminate when you identify the Original Error, which takes one of four forms:
   * **A Faulty Premise:** You have traced a nonsensical value all the way back to a user-defined initial condition, guess, or parameter that was physically invalid from the very start.
   * **A Faulty Computation:** You have found the specific equation that received physically valid inputs but produced a physically invalid output. Identify the specific term, sign, or connection that is wrong.
   * **A Faulty Configuration:** The physics and equations are correct, but the solver algorithm, tolerances, or initialization strategy is inappropriate for the problem's characteristics (stiffness, DAE index, conditioning, etc.).
   * **A Faulty Formulation:** When tracing backward, you encounter an algebraic equation where the Jacobian ∂f/∂x ≈ 0 for the variable being solved. This is not an incorrect equation - it's a conditioning problem. A nearly-flat function means tiny numerical errors in f produce huge errors in x. Investigation path: examine the mathematical relationship - is there a variable transformation or equation inversion that produces larger sensitivity (steeper slope)? Check the Jacobian for alternative formulations.

Your final proposed fix must be a direct and targeted correction of the single **Original Error** that you have proven through this trace. Do not guess, apply pattern-based patches, or modify symptoms. **Prove the origin, then fix the origin.** After fixing, simulate again. If a new failure occurs, repeat this protocol from the beginning.

## Investigation Tools: How to Execute the Trace

Your backward trace requires **NUMERICAL PROOF**. All investigation tools are documented in agent_resources/mtk_cheatsheet.jl. Use them.

Before any trace, run: equations(sys), unknowns(sys), observed(sys) to understand system structure.

### 1. Calculate Residuals

To verify if an equation is satisfied:

```julia
eq = equations(sys)[i]
println("Equation [$i]: ", eq)

t_check = sol.t[end]
q1_Ic = sol(t_check, idxs=sys.q1.Ic)
rc_i = sol(t_check, idxs=sys.rc.i)

residual = -q1_Ic + rc_i

println("  q1.Ic = ", q1_Ic, " A")
println("  rc.i = ", rc_i, " A")
println("  Residual = ", residual, " A")
println("  Satisfied: ", abs(residual) < 1e-6 ? "✓" : "✗")
```

**Required in trace:** Show actual residual values, not just "equation failed"

**Note:** Direct symbolic substitution fails for observables. Use sol(t, idxs=variable) to evaluate.

### 2. Substitute Values Into Expressions

To find how a variable is computed and evaluate it:

```julia
obs = observed(sys)
target_variable = sys.q1.Ib

for o in obs
    if isequal(o.lhs, target_variable)
        println("Found: ", o.lhs, " = ", o.rhs)
        t_check = 0.002
        calculated_value = sol(t_check, idxs=target_variable)
        println("At t = ", t_check, " s:")
        println("  ", target_variable, " = ", calculated_value, " A")
        break
    end
end
```

**Required in trace:** Show the expression and the numerical value at the time of interest

**Note:** Use isequal() not == for symbolic comparison to avoid creating symbolic booleans

### 3. Trace Dependencies

To find what equation computes a variable:

```julia
target_var = sys.q1.Vbe

println("Looking for: ", target_var)
for o in observed(sys)
    if isequal(o.lhs, target_var)
        println("  Found: ", o.lhs, " = ", o.rhs)
        vars_in_expr = Symbolics.get_variables(o.rhs)
        println("  Depends on: ", vars_in_expr)
        break
    end
end

println("\nIn equations:")
for (i, eq) in enumerate(equations(sys))
    vars_in_eq = union(Symbolics.get_variables(eq.lhs), Symbolics.get_variables(eq.rhs))
    if target_var in vars_in_eq
        println("  Equation [$i] involves ", target_var)
    end
end
```

**Required in trace:** Show the computational chain and dependencies explicitly

**Note:** Use Symbolics.get_variables() to extract all variables from an expression

### 4. Verify Conservation Laws

Check KCL/KVL/energy conservation:

```julia
t_check = 0.002

rb_i = sol(t_check, idxs=sys.rb.i)
q1_b_i = sol(t_check, idxs=sys.q1.b.i)

println("At base node:")
println("  rb.i = ", rb_i, " A")
println("  q1.b.i = ", q1_b_i, " A")

kcl_sum = rb_i - q1_b_i

println("\nKCL check: rb.i - q1.b.i = ", kcl_sum, " A")
println("  Satisfied: ", abs(kcl_sum) < 1e-12 ? "✓" : "✗")
```

**Required in trace:** Show numerical verification of conservation laws with explicit sign reasoning

## Proving the Origin

Your investigation is complete when you can state:
- **The specific element:** Which equation/parameter/configuration is wrong
- **The actual values:** What the inputs/outputs are (extracted via julia_tool)
- **The expected values:** What they should be based on governing physics (calculated via julia_tool)
- **The error:** The specific term/sign/coefficient/value that causes actual to deviate from expected

Use julia_tool to extract all data and perform all calculations. Your proof is the numerical demonstration that this specific element produces the observed symptom when all other elements are physically sound.

**Before proposing any fix:**

For runtime failures (InitialFailure, Unstable, DtLessThanMin, validation failures), demonstrate in julia_tool:
1. The equation/parameter that is wrong
2. Its actual numerical value at the failure point
3. The expected value from physics
4. The quantitative error

For structural failures (BalanceException, cyclic dependencies, structural singularity), demonstrate in julia_tool:
1. The structural problem: count mismatch, circular chain, or singular variables
2. Which specific variables/equations are involved
3. What physical constraint or connection is missing/wrong

If you cannot extract and print these items using julia_tool, you have not completed the investigation.

## Applying the Method to Specific Errors

### Unstable Error or DT_LESS_THAN_MIN

* **Symptom:** The solver is forced to take infinitesimally small time steps because a state variable is changing at a physically impossible rate.
* **Data Source:** Examine final derivatives to identify the unstable variable: `final_der = prob.f(sol.u[end], prob.p, sol.t[end])`. Outlier values in `final_der` indicate which state has unstable growth. Start your trace from that variable's equation.
* **Method:** Start your backward trace from the equation that calculates the derivative of the unstable state. Calculate all inputs to this equation at the last valid time step. Apply the quantitative physicality test to each input. Keep tracing backward through equations that produce non-physical values until you find the equation where physical inputs produce non-physical output.
* **Eigenvalue escape hatch:** If all inputs to the derivative equation are physically valid and the equation itself is correct, the instability is systemic, not local. Compute the eigenvalues of the linearized system at the operating point:

```julia
u_eq = sol.u[end]; t_eq = sol.t[end]
h = 1e-8
f0 = zeros(length(u_eq)); prob.f(f0, u_eq, prob.p, t_eq)
J = zeros(length(u_eq), length(u_eq))
for j in 1:length(u_eq)
    u_pert = copy(u_eq); u_pert[j] += h
    f_pert = zeros(length(u_eq)); prob.f(f_pert, u_pert, prob.p, t_eq)
    J[:, j] = (f_pert - f0) / h
end
eigvals(J)
```

For DAE systems (mixed differential-algebraic), partition into ODE and algebraic blocks and compute the effective ODE Jacobian: `J_eff = J_oo - J_oa * inv(J_aa) * J_ao`. Positive eigenvalues indicate a **Faulty Formulation** — the equations are individually correct but the coupled system is unstable. The fix is to reformulate the state variables, not to correct any single equation.

### InitialFailure

* **Symptom:** The solver cannot find a consistent state at t=0. The initial conditions, parameters, and static equations contradict each other.
* **Data Source:** Inspect the initialization problem: `init_sol = solve(prob.f.initialization_data.initializeprob)` and check `init_sol.resid` to see which initialization equations have large residuals. Access the initialization system with `init_sys = prob.f.initialization_data.initializeprob.f.sys` and use `equations(init_sys)[i]` to inspect the failing equations.
* **Method:** This is a trace through the static dependency graph at t=0. Start with the equation that has the largest residual at initialization. Calculate what each variable in this equation SHOULD be based on initial conditions and parameters. Trace backward through the equations that compute variables with the largest error until you find conflicting constraints or invalid initial values.

### Cyclic Error

* **Symptom:** A circular dependency exists where variable a depends on b, and b depends back on a. The solver cannot determine computation order.
* **Method:** You are tracing dependencies, not values. Start with variable a. Trace: "What equation computes a?" Find it depends on b. Trace: "What equation computes b?" Find it depends on a. Document the complete dependency chain that forms the loop. Identify which dependency is physically incorrect or where the cycle should be broken.

### BalanceException (Over/Under-determined System)

* **Symptom:** Structural mismatch between number of equations and unknowns.
* **Data Source:** BalanceException occurs DURING mtkcompile(), so you cannot use the compiled system. Inspect the UNSIMPLIFIED model first: `unknowns(model)`, `equations(model)`. If the model uses `connect()`, expand connections to see the generated equations: `equations(expand_connections(model))`. List ALL equations explicitly to identify which unknowns have no corresponding equations.
* **Method:** You are tracing constraints, not values.
  * **Over-determined:** Find the variable with multiple equations attempting to set its value. Trace each equation to understand what physical principle it represents. Identify which equation is redundant or contradictory.
  * **Under-determined:** Find the floating variable with no equation setting its value. Trace backward: what physical principle SHOULD constrain this variable? Identify the missing connection, reference, or constraint.

### Validation Failure (Success but Wrong Physics)

* **Symptom:** SciMLBase.successful_retcode(sol) returns true, but numerical results violate physical expectations (wrong steady-state, incorrect time constants, conservation law violations, unrealistic magnitudes).
* **Method:** You are tracing through correct computational structure to find incorrect physics. Start with the specific validation check that failed (e.g., "Vbe steady-state should be 0.7V, got 3.2V"). Trace backward: what equation computes Vbe? Calculate all inputs at steady-state using actual values. Apply the quantitative physicality test: does each input match physical expectations? If yes, the equation itself has wrong physics (sign, term, coefficient). If no, trace that input's computation backward. The origin is either: (1) a specific equation or parameter where valid physics was first violated, or (2) a solver configuration (algorithm, tolerance, initialization strategy) that cannot accurately resolve the physics for this problem.

## Critical Rules

1. **NEVER use pattern matching**
   - Do not assume "Unstable usually means X"
   - Derive the cause from first principles every time

2. **NEVER modify symptoms**
   - If Vbe explodes, don't add damping to Vbe
   - Find WHY Vbe explodes and fix that

3. **The fix must be a single, targeted change**
   - Change the specific wrong term/sign/connection proven by trace
   - Not multiple "improvements" or "safety measures"

## Fix Verification Workflow

After identifying the root cause:

IF the fix is testable in Julia (initial conditions, guesses, parameters, solver algorithms, tolerances, initialization strategies):
1. **Test** the fix in the persistent Julia session — change the value/config directly, re-run solve()
2. **Verify** it solves the problem numerically — check `SciMLBase.successful_retcode(sol)`, verify physics
3. **Only then** edit Dyad code with the proven fix and recompile

Skip verification only if the fix cannot be tested in Julia. The persistent Julia session is your laboratory — use it.

## Julia Code Quality

When writing Julia code for investigation:
- Use simple if/else statements, not complex ternary chains
- Check return codes: `if SciMLBase.successful_retcode(sol)`
- Print values clearly: `println("Vc = ", round(Vc, digits=2), " V")`
- Don't wrap solve() in try-catch unless you need to inspect failed solutions

## Example: Forensic Investigation with Backward Trace

Context: NPN transistor simulation failed with Unstable retcode at t=0.00157s.

**Step 1 — Identify the symptom:**
```julia
println("=== SYMPTOM ANALYSIS ===")
println("retcode: ", sol.retcode)
println("Failed at t = ", sol.t[end], " s")

t_fail = sol.t[end]
println("\nVariable values at failure:")
println("Vbe = ", sol(t_fail, idxs=sys.q1.Vbe), " V")
println("Ib = ", sol(t_fail, idxs=sys.q1.Ib), " A")
println("Ic = ", sol(t_fail, idxs=sys.q1.Ic), " A")
```

Result: Vbe = 4.19 V, Ib = 1.55e9 A, Ic = 2.32e11 A

Ib = 1.55e9 A is unphysical (expected: μA range).

**Step 2 — KCL at base node + trace dependency:**
```julia
println("=== KCL at Base Node ===")
t_check = 0.00157

rb_i = sol(t_check, idxs=sys.rb.i)
q1_b_i = sol(t_check, idxs=sys.q1.b.i)

println("rb.i = ", rb_i, " A")
println("q1.b.i = ", q1_b_i, " A")
println("KCL sum = ", rb_i + q1_b_i, " A")
println("Satisfied: ", abs(rb_i + q1_b_i) < 1e-12 ? "✓" : "✗")
```

Result: rb.i = -1.55e9 A, q1.b.i = 1.55e9 A, KCL sum = -3.4e-6 A (satisfied)

```julia
println("=== Trace q1.b.i dependency ===")
target_var = sys.q1.b.i
for o in observed(sys)
    if isequal(o.lhs, target_var)
        println("Found: ", o.lhs, " = ", o.rhs)
        vars_in_expr = Symbolics.get_variables(o.rhs)
        println("Depends on: ", vars_in_expr)
        break
    end
end
```

Result: q1.b.i = -q1.Ib

**Step 3 — Origin found:**

The equation q1.b.i = -Ib has the wrong sign.

- KCL is satisfied mathematically, but rb.i = -1.55e9 A means current flows OUT of resistor into voltage source
- This creates positive feedback: higher Ib → higher Vbe → higher Ib → runaway
- By MTK convention: pin.i > 0 means current INTO component
- Current flows INTO the base pin, so b.i should be +Ib, not -Ib

Trace completion:
1. Equation: b.i = -Ib (observed equation)
2. Numerical values: Ib = 1.55e9 A (unphysical, expected ~μA range)
3. Expected: Ib ~μA, Vbe ~0.7V based on transistor physics
4. Incorrect term: Negative sign in -Ib
5. Why incorrect: Creates Vbe = V_supply + Rb*Ib (positive feedback) instead of Vbe = V_supply - Rb*Ib (negative feedback)
