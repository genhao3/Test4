# plot_flux_transient.jl
# Generates lmc_flux_transient.gif — 2-panel (top + side view) animation
# showing magnetic field lines progressively tracing around the racetrack
# as coil current ramps up (RL transient).
#
# Usage:  julia --project=. scripts/plot_flux_transient.jl
#   or:   click ▶ in VS Code (after setting Julia env to Test4)

# Activate project environment (makes ▶ button work regardless of VS Code setting)
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

# using Test4
using Plots
gr()

const OUTPUT_PATH = joinpath(@__DIR__, "..", "lmc_flux_transient2.gif")

# ══════════════════════════════════════════════════════════════════════
#  Helpers
# ══════════════════════════════════════════════════════════════════════
function coil_circle_points(cx, cy, cz, nx, ny, nz, r; npts=60)
    n_hat = [nx, ny, nz] / sqrt(nx^2 + ny^2 + nz^2)
    ref = abs(n_hat[3]) < 0.9 ? [0.0, 0.0, 1.0] : [1.0, 0.0, 0.0]
    e1 = Test4.cross(n_hat, ref); e1 = e1 / sqrt(sum(e1 .^ 2))
    e2 = Test4.cross(n_hat, e1)
    xs, ys, zs = Float64[], Float64[], Float64[]
    for k in 0:npts
        θ = 2π * k / npts
        p = [cx, cy, cz] .+ r .* (cos(θ) .* e1 .+ sin(θ) .* e2)
        push!(xs, p[1]); push!(ys, p[2]); push!(zs, p[3])
    end
    return xs, ys, zs
end

function trace_field_line(start_pos; ds=0.05, n_steps=3500, n_turns_coil=100)
    pos = copy(start_pos)
    trajectory = [copy(pos)]
    for _ in 1:n_steps
        B1 = Test4.compute_total_field(pos; n_turns=n_turns_coil, n_seg=80)
        mag1 = sqrt(sum(B1 .^ 2)); mag1 < 1e-15 && break
        k1 = B1 ./ mag1
        p2 = pos .+ 0.5*ds.*k1
        B2 = Test4.compute_total_field(p2; n_turns=n_turns_coil, n_seg=80)
        mag2 = sqrt(sum(B2 .^ 2)); mag2 < 1e-15 && break
        k2 = B2 ./ mag2
        p3 = pos .+ 0.5*ds.*k2
        B3 = Test4.compute_total_field(p3; n_turns=n_turns_coil, n_seg=80)
        mag3 = sqrt(sum(B3 .^ 2)); mag3 < 1e-15 && break
        k3 = B3 ./ mag3
        p4 = pos .+ ds.*k3
        B4 = Test4.compute_total_field(p4; n_turns=n_turns_coil, n_seg=80)
        mag4 = sqrt(sum(B4 .^ 2)); mag4 < 1e-15 && break
        k4 = B4 ./ mag4
        pos = pos .+ (ds/6.0).*(k1 .+ 2.0.*k2 .+ 2.0.*k3 .+ k4)
        push!(trajectory, copy(pos))
    end
    return trajectory
end

# ══════════════════════════════════════════════════════════════════════
#  Precompute coil circles (2D projections)
# ══════════════════════════════════════════════════════════════════════
println("Computing coil circles...")
coil_xy = Vector{Tuple{Vector{Float64}, Vector{Float64}}}()
coil_xz = Vector{Tuple{Vector{Float64}, Vector{Float64}}}()
for i in 1:42
    cx = Test4.racetrack_get_px(i)
    cy = Test4.racetrack_get_py(i)
    cz = Test4.racetrack_get_pz(i)
    nx = Test4.racetrack_get_nx(i)
    ny = Test4.racetrack_get_ny(i)
    nz = Test4.racetrack_get_nz(i)
    xs, ys, zs = coil_circle_points(cx, cy, cz, nx, ny, nz, 1.0; npts=60)
    push!(coil_xy, (xs, ys))
    push!(coil_xz, (xs, zs))
end

# ══════════════════════════════════════════════════════════════════════
#  Trace 8 long field lines (~2 full loops each)
# ══════════════════════════════════════════════════════════════════════
const CENTER   = [9.0, 0.0, 0.0]
const N_LINES  = 8
const FLUX_R   = 0.3   # m — starting circle radius default=0.3
const DS       = 0.05  # m — RK4 step size
const N_STEPS  = 3500  # ~2 full racetrack loops

println("Tracing $N_LINES field lines (n_steps=$N_STEPS each)...")
trajectories = Vector{Vector{Vector{Float64}}}()
for k in 1:N_LINES
    θ = 2π * (k - 1) / N_LINES
    start_pt = CENTER .+ FLUX_R .* [cos(θ), 0.0, sin(θ)]
    println("  Line $k/$N_LINES...")
    traj = trace_field_line(start_pt; ds=DS, n_steps=N_STEPS, n_turns_coil=100)
    push!(trajectories, traj)
end

flux_xy = [(Float64[p[1] for p in t], Float64[p[2] for p in t]) for t in trajectories]
flux_xz = [(Float64[p[1] for p in t], Float64[p[3] for p in t]) for t in trajectories]
n_pts = minimum(length.(trajectories))
println("All lines traced. Min length = $n_pts points.")

# ══════════════════════════════════════════════════════════════════════
#  RL time constant
# ══════════════════════════════════════════════════════════════════════
#   L = μ₀ N² π r² / ℓ  ≈ 0.7896 H   (N=100, r=1 m, ℓ=0.05 m)
#   R = 5 Ω  →  τ ≈ 0.158 s
#   I(t)/I_ss = 1 − exp(−t/τ)
const MU0    = 4π * 1e-7
const L_COIL = MU0 * 100.0^2 * π * 1.0^2 / 0.05
const R_COIL = 5.0
const TAU    = L_COIL / R_COIL
println("τ = $(round(TAU*1000, digits=1)) ms")

# ══════════════════════════════════════════════════════════════════════
#  Animation — progressive reveal
# ══════════════════════════════════════════════════════════════════════
const N_FRAMES  = 50
const T_END     = 1.0      # seconds
const FRAMERATE = 8
times = range(0.0, T_END, length=N_FRAMES)

println("Generating GIF ($N_FRAMES frames)...")

anim = @animate for frame_idx in 1:N_FRAMES
    t      = times[frame_idx]
    I_frac = 1.0 - exp(-t / TAU)
    t_ms   = t * 1000.0

    # Linear reveal: frame 1 → 0 points, frame N → all points
    frac   = (frame_idx - 1) / (N_FRAMES - 1)
    n_show = round(Int, frac * n_pts)

    # ── (a) Top view ───────────────────────────────────────────
    p1 = plot(title="(a) Top view", xlabel="x (a.u.)", ylabel="y (a.u.)",
              aspect_ratio=:equal, legend=false, titlefontsize=12,ylims=(-4.6, 4.6),
              grid=true, framestyle=:box)
    for (xs, ys) in coil_xy
        plot!(p1, xs, ys, color=:blue, lw=1.2)
    end
    if n_show >= 2
        for (xs, ys) in flux_xy
            n_avail = min(n_show, length(xs))
            plot!(p1, xs[1:n_avail], ys[1:n_avail],
                  color=:darkorange, lw=1.0)
        end
    end

    # ── (b) Side view ──────────────────────────────────────────
    p2 = plot(title="(b) Side view", xlabel="x (a.u.)", ylabel="z (a.u.)",
              legend=false, titlefontsize=12,
              ylims=(-2.2, 2.2), grid=true, framestyle=:box)
    for (xs, zs) in coil_xz
        plot!(p2, xs, zs, color=:blue, lw=1.2)
    end
    if n_show >= 2
        for (xs, zs) in flux_xz
            n_avail = min(n_show, length(xs))
            plot!(p2, xs[1:n_avail], zs[1:n_avail],
                  color=:darkorange, lw=1.0)
        end
    end

    # ── Combine ────────────────────────────────────────────────
    plot(p1, p2, layout=@layout([a; b]), size=(1150, 950),
         plot_title="Linked Mirror Configuration — " *
                    "t = $(round(t_ms, digits=1)) ms, " *
                    "I/I_ss = $(round(I_frac*100, digits=1))%",
         plot_titlefontsize=13)

    if frame_idx % 10 == 0
        println("  Frame $frame_idx/$N_FRAMES  n_show=$n_show/$n_pts")
    end
end

gif(anim, OUTPUT_PATH, fps=FRAMERATE)
println("Saved $OUTPUT_PATH")
println("Done!")
