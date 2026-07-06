# plot_flux_surfaces.jl
# Generates lmc_flux_surface.png and lmc_flux_transient.gif
# matching the 2-panel (top view + side view) reference format.
#
# Usage:  julia --project=. scripts/plot_flux_surfaces.jl

using Test4
using CairoMakie

const OUTPUT_DIR = joinpath(@__DIR__, "..")

# ══════════════════════════════════════════════════════════════════════
#  Coil circle points (3D)
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

# ══════════════════════════════════════════════════════════════════════
#  RK4 field line tracer
# ══════════════════════════════════════════════════════════════════════
function trace_field_line(start_pos; ds=0.05, n_steps=3000, n_turns_coil=100)
    pos = copy(start_pos)
    trajectory = [copy(pos)]
    for _ in 1:n_steps
        B1 = Test4.compute_total_field(pos; n_turns=n_turns_coil, n_seg=80)
        mag1 = sqrt(sum(B1 .^ 2))
        mag1 < 1e-15 && break
        k1 = B1 ./ mag1

        p2 = pos .+ 0.5 * ds .* k1
        B2 = Test4.compute_total_field(p2; n_turns=n_turns_coil, n_seg=80)
        mag2 = sqrt(sum(B2 .^ 2))
        mag2 < 1e-15 && break
        k2 = B2 ./ mag2

        p3 = pos .+ 0.5 * ds .* k2
        B3 = Test4.compute_total_field(p3; n_turns=n_turns_coil, n_seg=80)
        mag3 = sqrt(sum(B3 .^ 2))
        mag3 < 1e-15 && break
        k3 = B3 ./ mag3

        p4 = pos .+ ds .* k3
        B4 = Test4.compute_total_field(p4; n_turns=n_turns_coil, n_seg=80)
        mag4 = sqrt(sum(B4 .^ 2))
        mag4 < 1e-15 && break
        k4 = B4 ./ mag4

        pos = pos .+ (ds / 6.0) .* (k1 .+ 2.0 .* k2 .+ 2.0 .* k3 .+ k4)
        push!(trajectory, copy(pos))
    end
    return trajectory
end

# ══════════════════════════════════════════════════════════════════════
#  Precompute coil circles (2D projections)
# ══════════════════════════════════════════════════════════════════════
println("Computing coil circles...")
coil_xy = Vector{Tuple{Vector{Float64}, Vector{Float64}}}()  # top view
coil_xz = Vector{Tuple{Vector{Float64}, Vector{Float64}}}()  # side view
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
#  Trace flux surface field lines
# ══════════════════════════════════════════════════════════════════════
# 16 lines from a circle of radius 0.3 m around the centerline at (0, 3, 0)
# in the x-z plane (perpendicular to the top straight arm)
const CENTER   = [0.0, 3.0, 0.0]
const N_LINES  = 16
const FLUX_R   = 0.3   # m – starting circle radius
const DS       = 0.05  # m – RK4 step size
const N_STEPS  = 2500  # enough for ~2 loops around the racetrack

println("Tracing $N_LINES flux surface field lines...")
trajectories = Vector{Vector{Vector{Float64}}}()
for k in 1:N_LINES
    θ = 2π * (k - 1) / N_LINES
    start_pt = CENTER .+ FLUX_R .* [cos(θ), 0.0, sin(θ)]
    println("  Line $k/$N_LINES...")
    traj = trace_field_line(start_pt; ds=DS, n_steps=N_STEPS, n_turns_coil=100)
    push!(trajectories, traj)
end

# 2D projections of all trajectories
flux_xy = [(Float64[p[1] for p in t], Float64[p[2] for p in t]) for t in trajectories]
flux_xz = [(Float64[p[1] for p in t], Float64[p[3] for p in t]) for t in trajectories]
println("All field lines traced.")

# ══════════════════════════════════════════════════════════════════════
#  Frame drawing helper
# ══════════════════════════════════════════════════════════════════════
function draw_frame!(fig, t_ms, I_frac; show_flux=true)
    empty!(fig)

    # Title
    Label(fig[0, 1],
        "Linked Mirror Configuration — t = $(round(t_ms, digits=1)) ms, " *
        "I/I_ss = $(round(I_frac*100, digits=1))%",
        fontsize=18, font=:bold)

    # (a) Top view  (x-y)
    ax_top = Axis(fig[1, 1],
        title="(a) Top view",
        xlabel="x (m)", ylabel="y (m)",
        aspect=DataAspect(),
        xlabelsize=14, ylabelsize=14)
    xlims!(ax_top, -11, 11)
    ylims!(ax_top, -5, 5)

    for (xs, ys) in coil_xy
        lines!(ax_top, xs, ys, color=:blue, linewidth=1.2)
    end
    if show_flux && I_frac > 0.01
        α = clamp(I_frac, 0.0, 1.0)
        for (xs, ys) in flux_xy
            lines!(ax_top, xs, ys, color=(:orange, α), linewidth=1.0)
        end
    end

    # (b) Side view  (x-z)
    ax_side = Axis(fig[2, 1],
        title="(b) Side view",
        xlabel="x (m)", ylabel="z (m)",
        aspect=DataAspect(),
        xlabelsize=14, ylabelsize=14)
    xlims!(ax_side, -11, 11)
    ylims!(ax_side, -4, 4)

    for (xs, zs) in coil_xz
        lines!(ax_side, xs, zs, color=:blue, linewidth=1.2)
    end
    if show_flux && I_frac > 0.01
        α = clamp(I_frac, 0.0, 1.0)
        for (xs, zs) in flux_xz
            lines!(ax_side, xs, zs, color=(:orange, α), linewidth=1.0)
        end
    end

    return fig
end

# ══════════════════════════════════════════════════════════════════════
#  1) Static figure  —  lmc_flux_surface.png  (steady state)
# ══════════════════════════════════════════════════════════════════════
println("Generating lmc_flux_surface.png...")
fig_static = Figure(size=(1000, 1000), backgroundcolor=:white)
draw_frame!(fig_static, 1000.0, 1.0; show_flux=true)
save(joinpath(OUTPUT_DIR, "lmc_flux_surface.png"), fig_static, px_per_unit=2)
println("Saved lmc_flux_surface.png")

# ══════════════════════════════════════════════════════════════════════
#  2) Animated GIF  —  lmc_flux_transient.gif
# ══════════════════════════════════════════════════════════════════════
# RL time constant:  τ = L / R
#   L = μ₀ N² π r² / ℓ  ≈ 0.7896 H   (N=100, r=1 m, ℓ=0.05 m)
#   R = 5 Ω  →  τ ≈ 0.158 s
# I(t) / I_ss  =  1 − exp(−t / τ)
# Simulate 0 → 1.0 s  (≈ 6.3 τ, full ramp-up)

const MU0    = 4π * 1e-7
const L_COIL = MU0 * 100.0^2 * π * 1.0^2 / 0.05
const R_COIL = 5.0
const TAU    = L_COIL / R_COIL
println("τ = $(round(TAU*1000, digits=1)) ms")

const N_FRAMES  = 50
const T_END     = 1.0   # seconds
const FRAMERATE = 8

times = range(0.0, T_END, length=N_FRAMES)

println("Generating lmc_flux_transient.gif ($N_FRAMES frames)...")
fig_anim = Figure(size=(1000, 1000), backgroundcolor=:white)

record(fig_anim, joinpath(OUTPUT_DIR, "lmc_flux_transient.gif"),
       1:N_FRAMES; framerate=FRAMERATE) do frame_idx
    t      = times[frame_idx]
    I_frac = 1.0 - exp(-t / TAU)
    t_ms   = t * 1000.0
    draw_frame!(fig_anim, t_ms, I_frac; show_flux=true)
    if frame_idx % 10 == 0
        println("  Frame $frame_idx/$N_FRAMES  " *
                "(t=$(round(t_ms, digits=1)) ms, I/I_ss=$(round(I_frac*100, digits=1))%)")
    end
end

println("Saved lmc_flux_transient.gif")
println("Done!")
