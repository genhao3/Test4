# plot_particles.jl
# Generates particles.gif — 2-panel (top + side view) animation showing the
# motion of 10,000 charged test particles in the steady-state magnetic field
# of the Linked Mirror Configuration (LMC) racetrack coil set.
#
# This is the particle-motion counterpart of plot_flux_transient.jl
# (which animates the magnetic field lines).  Here the field is held at its
# steady-state value and we instead push 10,000 test particles through it.
#
# Particle setup (per request):
#   • 10,000 test particles, each with kinetic energy E = 1 keV
#   • launched uniformly over the magnetic flux surface that passes through
#     (9.1, 0, 0)  (a point near the centre of the right semicircular section)
#   • isotropic initial velocity distribution
#   • lost when their minor radius (distance to the magnetic axis) reaches
#     rp = 0.99 r, where r = 1 m is the coil radius
#
# Species note:  with this toy coil set the on-axis field is ~7e-4 T, so a
# 1 keV electron has a gyro-radius of ~0.15 m (< 0.99 m boundary) and is
# confined, whereas a 1 keV proton has a gyro-radius of ~6.6 m and would be
# lost immediately.  The particles are therefore taken to be electrons.
# To use a different species, change PARTICLE_MASS / PARTICLE_CHARGE below.
#
# Usage:  julia --project=. scripts/plot_particles.jl
#   or:   click ▶ in VS Code (after setting Julia env to Test4)

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using Test4
using Plots
using Random
gr()

const OUTPUT_PATH = joinpath(@__DIR__, "..", "particles.gif")

# ══════════════════════════════════════════════════════════════════════
#  Physical constants and particle parameters
# ══════════════════════════════════════════════════════════════════════
const QE  = 1.602176634e-19      # C  – elementary charge
const ME  = 9.1093837015e-31     # kg – electron mass
const KEV = 1000 * QE            # J  – 1 keV in joules

const PARTICLE_ENERGY = 1 * KEV          # J  – kinetic energy of each particle
const PARTICLE_MASS   = ME               # kg – electron (see species note above)
const PARTICLE_CHARGE = -QE              # C  – electron charge (negative)
const V_PARTICLE = sqrt(2 * PARTICLE_ENERGY / PARTICLE_MASS)   # m/s
const QM = PARTICLE_CHARGE / PARTICLE_MASS                     # C/kg

const N_PARTICLES = 10_000
const COIL_RADIUS = 1.0          # m  – r
const RP_BOUNDARY = 0.99 * COIL_RADIUS   # m  – loss boundary (minor radius)
const FLUX_POINT  = [9.1, 0.0, 0.0]      # m  – defines the launch flux surface

# Time integration
const DT          = 3e-9         # s  – Boris step (~T_c/17 for 1 keV electron)
const N_STEPS     = 900          # → 2.7 µs total
const FRAME_EVERY = 15           # snapshot cadence → 61 animation frames

# ══════════════════════════════════════════════════════════════════════
#  Fast Biot–Savart field  (precomputed coil segments, allocation-free)
# ══════════════════════════════════════════════════════════════════════
const MU0_4PI = 1e-7             # μ₀ / 4π

function build_segments(; n_turns = 100, n_seg = 60)
    Px = Float64[]; Py = Float64[]; Pz = Float64[]
    Lx = Float64[]; Ly = Float64[]; Lz = Float64[]; NI = Float64[]
    for i in 1:42
        c = [Test4.racetrack_get_px(i), Test4.racetrack_get_py(i), Test4.racetrack_get_pz(i)]
        n = [Test4.racetrack_get_nx(i), Test4.racetrack_get_ny(i), Test4.racetrack_get_nz(i)]
        nhat = n ./ sqrt(sum(n .^ 2))
        ref  = abs(nhat[3]) < 0.9 ? [0.0, 0.0, 1.0] : [1.0, 0.0, 0.0]
        e1 = Test4.cross(nhat, ref); e1 ./= sqrt(sum(e1 .^ 2))
        e2 = Test4.cross(nhat, e1)
        dθ = 2π / n_seg
        cur = Test4.racetrack_get_current(i)
        for k in 1:n_seg
            θ  = (k - 0.5) * dθ
            P  = c .+ COIL_RADIUS .* (cos(θ) .* e1 .+ sin(θ) .* e2)
            dl = COIL_RADIUS .* (-sin(θ) .* e1 .+ cos(θ) .* e2) .* dθ
            push!(Px, P[1]); push!(Py, P[2]); push!(Pz, P[3])
            push!(Lx, dl[1]); push!(Ly, dl[2]); push!(Lz, dl[3]); push!(NI, n_turns * cur)
        end
    end
    return (Px, Py, Pz, Lx, Ly, Lz, NI)
end

const SEG = build_segments(; n_turns = 100, n_seg = 60)

function bfield(x, y, z, seg)
    Px, Py, Pz, Lx, Ly, Lz, NI = seg
    Bx = 0.0; By = 0.0; Bz = 0.0
    @inbounds @simd for k in 1:length(Px)
        rx = x - Px[k]; ry = y - Py[k]; rz = z - Pz[k]
        d2 = rx * rx + ry * ry + rz * rz; d = sqrt(d2); inv = 1.0 / (d2 * d)
        cx = Ly[k] * rz - Lz[k] * ry
        cy = Lz[k] * rx - Lx[k] * rz
        cz = Lx[k] * ry - Ly[k] * rx
        f = MU0_4PI * NI[k] * inv
        Bx += f * cx; By += f * cy; Bz += f * cz
    end
    return (Bx, By, Bz)
end

# ══════════════════════════════════════════════════════════════════════
#  Precompute B on a 3D grid → trilinear interpolation for the pusher
# ══════════════════════════════════════════════════════════════════════
const GX = -10.6:0.1:10.6
const GY = -4.0:0.1:4.0
const GZ = -3.0:0.1:3.0
const NX = length(GX); const NY = length(GY); const NZ = length(GZ)
const X0 = first(GX); const Y0 = first(GY); const Z0 = first(GZ); const DXY = 0.1

println("Building field grid ($NX×$NY×$NZ = $(NX*NY*NZ) points)...")
const BGX = Array{Float64}(undef, NX, NY, NZ)
const BGY = similar(BGX)
const BGZ = similar(BGX)
let tg = @elapsed begin
        @inbounds for k in 1:NZ, j in 1:NY, i in 1:NX
            bx, by, bz = bfield(GX[i], GY[j], GZ[k], SEG)
            BGX[i, j, k] = bx; BGY[i, j, k] = by; BGZ[i, j, k] = bz
        end
    end
    println("  grid built in $(round(tg, digits=2)) s")
end

@inline function binterp(x, y, z)
    fx = (x - X0) / DXY; fy = (y - Y0) / DXY; fz = (z - Z0) / DXY
    i = floor(Int, fx); j = floor(Int, fy); k = floor(Int, fz)
    (i < 1 || i >= NX || j < 1 || j >= NY || k < 1 || k >= NZ) && return (0.0, 0.0, 0.0)
    tx = fx - i; ty = fy - j; tz = fz - k; i += 1; j += 1; k += 1
    @inbounds begin
        c00x = BGX[i,j,k]*(1-tx)+BGX[i+1,j,k]*tx;     c10x = BGX[i,j+1,k]*(1-tx)+BGX[i+1,j+1,k]*tx
        c01x = BGX[i,j,k+1]*(1-tx)+BGX[i+1,j,k+1]*tx; c11x = BGX[i,j+1,k+1]*(1-tx)+BGX[i+1,j+1,k+1]*tx
        bx = (c00x*(1-ty)+c10x*ty)*(1-tz)+(c01x*(1-ty)+c11x*ty)*tz
        c00y = BGY[i,j,k]*(1-tx)+BGY[i+1,j,k]*tx;     c10y = BGY[i,j+1,k]*(1-tx)+BGY[i+1,j+1,k]*tx
        c01y = BGY[i,j,k+1]*(1-tx)+BGY[i+1,j,k+1]*tx; c11y = BGY[i,j+1,k+1]*(1-tx)+BGY[i+1,j+1,k+1]*tx
        by = (c00y*(1-ty)+c10y*ty)*(1-tz)+(c01y*(1-ty)+c11y*ty)*tz
        c00z = BGZ[i,j,k]*(1-tx)+BGZ[i+1,j,k]*tx;     c10z = BGZ[i,j+1,k]*(1-tx)+BGZ[i+1,j+1,k]*tx
        c01z = BGZ[i,j,k+1]*(1-tx)+BGZ[i+1,j,k+1]*tx; c11z = BGZ[i,j+1,k+1]*(1-tx)+BGZ[i+1,j+1,k+1]*tx
        bz = (c00z*(1-ty)+c10z*ty)*(1-tz)+(c01z*(1-ty)+c11z*ty)*tz
    end
    return (bx, by, bz)
end

# ══════════════════════════════════════════════════════════════════════
#  Magnetic axis (racetrack centerline) → minor-radius loss criterion
# ══════════════════════════════════════════════════════════════════════
const L2    = 6.0          # half straight length
const RSEMI = 3.0          # semicircle radius
const THETA = π / 20       # tilt angle
const HH    = L2 * tan(THETA)

function centerline_points(; nstr = 200, nsemi = 200)
    pts = Vector{Vector{Float64}}()
    for k in 0:nstr; x = -L2 + 12.0 * k / nstr; push!(pts, [x, RSEMI, x * tan(THETA)]); end
    for k in 1:nsemi-1; φ = π * k / nsemi; push!(pts, [L2 + RSEMI * sin(φ), RSEMI * cos(φ), HH * cos(φ)]); end
    for k in 0:nstr; x = L2 - 12.0 * k / nstr; push!(pts, [x, -RSEMI, -x * tan(THETA)]); end
    for k in 1:nsemi-1; φ = π * k / nsemi; push!(pts, [-L2 - RSEMI * sin(φ), -RSEMI * cos(φ), HH * cos(φ)]); end
    return pts
end

const _AX = reduce(hcat, centerline_points())
const AXN = size(_AX, 2)
const AXx = collect(_AX[1, :]); const AXy = collect(_AX[2, :]); const AXz = collect(_AX[3, :])

@inline function minor_radius(x, y, z)
    best = Inf
    @inbounds for j in 1:AXN
        dx = x - AXx[j]; dy = y - AXy[j]; dz = z - AXz[j]
        d2 = dx * dx + dy * dy + dz * dz
        d2 < best && (best = d2)
    end
    return sqrt(best)
end

# ══════════════════════════════════════════════════════════════════════
#  Initial particle positions — trace the flux surface through FLUX_POINT
# ══════════════════════════════════════════════════════════════════════
# A field line launched from FLUX_POINT winds both toroidally (around the
# racetrack) and poloidally, densely covering its flux surface.  Sampling
# N_PARTICLES points uniformly along it gives a uniform distribution over
# that surface.
function trace_field_line(start; ds = 0.05, n = 12000)
    x, y, z = start
    out = Vector{NTuple{3,Float64}}(undef, n + 1); out[1] = (x, y, z)
    for s in 1:n
        b1 = bfield(x, y, z, SEG);                                  m1 = sqrt(sum(b1 .^ 2)); k1 = b1 ./ m1
        b2 = bfield(x+0.5ds*k1[1], y+0.5ds*k1[2], z+0.5ds*k1[3], SEG); m2 = sqrt(sum(b2 .^ 2)); k2 = b2 ./ m2
        b3 = bfield(x+0.5ds*k2[1], y+0.5ds*k2[2], z+0.5ds*k2[3], SEG); m3 = sqrt(sum(b3 .^ 2)); k3 = b3 ./ m3
        b4 = bfield(x+ds*k3[1],   y+ds*k3[2],   z+ds*k3[3],   SEG);  m4 = sqrt(sum(b4 .^ 2)); k4 = b4 ./ m4
        x += ds/6*(k1[1]+2k2[1]+2k3[1]+k4[1])
        y += ds/6*(k1[2]+2k2[2]+2k3[2]+k4[2])
        z += ds/6*(k1[3]+2k2[3]+2k3[3]+k4[3])
        out[s+1] = (x, y, z)
    end
    return out
end

println("Tracing launch flux surface through $(FLUX_POINT)...")
const _FL  = trace_field_line(FLUX_POINT; ds = 0.05, n = 12000)
const _IDX = round.(Int, range(1, length(_FL), length = N_PARTICLES))
const POS0 = [_FL[i] for i in _IDX]

# Isotropic initial velocity directions, all with speed V_PARTICLE
function isotropic_velocities(n, speed)
    vx = Vector{Float64}(undef, n); vy = similar(vx); vz = similar(vx)
    for i in 1:n
        u = 2rand() - 1; φ = 2π * rand(); s = sqrt(1 - u * u)
        vx[i] = speed * s * cos(φ); vy[i] = speed * s * sin(φ); vz[i] = speed * u
    end
    return vx, vy, vz
end

# ══════════════════════════════════════════════════════════════════════
#  Boris pusher  (E = 0 → magnetic rotation, exactly energy-conserving) 
# ══════════════════════════════════════════════════════════════════════
function run_simulation(pos0, nstep, dt, frame_every; rp = RP_BOUNDARY)
    np = length(pos0)
    X = [p[1] for p in pos0]; Y = [p[2] for p in pos0]; Z = [p[3] for p in pos0]
    VX, VY, VZ = isotropic_velocities(np, V_PARTICLE)
    alive = trues(np)
    snaps = Vector{Tuple{Vector{Float64},Vector{Float64},Vector{Float64},BitVector}}()
    push!(snaps, (copy(X), copy(Y), copy(Z), copy(alive)))
    half = 0.5 * dt
    for step in 1:nstep
        @inbounds for i in 1:np
            alive[i] || continue
            # 求对应位置的磁场
            bx, by, bz = binterp(X[i], Y[i], Z[i])
            # 求解无电场洛伦兹方程
            tx = QM * bx * half; ty = QM * by * half; tz = QM * bz * half
            # 旋转缩放修正系数
            t2 = tx*tx + ty*ty + tz*tz; sfac = 2.0 / (1.0 + t2)
            vx = VX[i]; vy = VY[i]; vz = VZ[i]
            # 半步预速度，本质是用叉乘离散逼近洛伦兹力带来的速度导数
            vpx = vx + (vy*tz - vz*ty); vpy = vy + (vz*tx - vx*tz); vpz = vz + (vx*ty - vy*tx)
            # 更新速度
            VX[i] = vx + (vpy*(sfac*tz) - vpz*(sfac*ty))
            VY[i] = vy + (vpz*(sfac*tx) - vpx*(sfac*tz))
            VZ[i] = vz + (vpx*(sfac*ty) - vpy*(sfac*tx))
            X[i] += VX[i]*dt; Y[i] += VY[i]*dt; Z[i] += VZ[i]*dt
        end
        if step % 10 == 0    # loss check
            @inbounds for i in 1:np
                alive[i] || continue
                minor_radius(X[i], Y[i], Z[i]) >= rp && (alive[i] = false)
            end
        end
        if step % frame_every == 0
            push!(snaps, (copy(X), copy(Y), copy(Z), copy(alive)))
        end
    end
    return snaps
end

Random.seed!(20240601)
println("Pushing $N_PARTICLES particles ($(round(N_STEPS*DT*1e6, digits=2)) µs, dt=$(DT*1e9) ns)...")
const SNAPS = let t = @elapsed (global SNAPS_ = run_simulation(POS0, N_STEPS, DT, FRAME_EVERY))
    println("  simulation done in $(round(t, digits=2)) s, $(length(SNAPS_)) frames")
    SNAPS_
end

# ══════════════════════════════════════════════════════════════════════
#  Precompute coil circles (2D projections) for the background
# ══════════════════════════════════════════════════════════════════════
function coil_circle_points(cx, cy, cz, nx, ny, nz, r; npts = 60)
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

println("Computing coil circles...")
coil_xy = Vector{Tuple{Vector{Float64},Vector{Float64}}}()
coil_xz = Vector{Tuple{Vector{Float64},Vector{Float64}}}()
for i in 1:42
    xs, ys, zs = coil_circle_points(
        Test4.racetrack_get_px(i), Test4.racetrack_get_py(i), Test4.racetrack_get_pz(i),
        Test4.racetrack_get_nx(i), Test4.racetrack_get_ny(i), Test4.racetrack_get_nz(i),
        COIL_RADIUS; npts = 60)
    push!(coil_xy, (xs, ys))
    push!(coil_xz, (xs, zs))
end

# ══════════════════════════════════════════════════════════════════════
#  Animation — particle cloud streaming and depleting in time
# ══════════════════════════════════════════════════════════════════════
const FRAMERATE = 8
const N_FRAMES  = length(SNAPS)

println("Generating GIF ($N_FRAMES frames)...")
anim = @animate for fi in 1:N_FRAMES
    X, Y, Z, alive = SNAPS[fi]
    t_us = (fi - 1) * FRAME_EVERY * DT * 1e6
    keep = findall(alive)
    n_alive = length(keep)

    # ── (a) Top view ───────────────────────────────────────────
    p1 = plot(title = "(a) Top view", xlabel = "x (a.u.)", ylabel = "y (a.u.)",
              aspect_ratio = :equal, legend = false, titlefontsize = 12,
              ylims = (-4.6, 4.6), grid = true, framestyle = :box)
    for (xs, ys) in coil_xy
        plot!(p1, xs, ys, color = :blue, lw = 1.2)
    end
    scatter!(p1, X[keep], Y[keep], color = :darkorange, markersize = 1.0,
             markerstrokewidth = 0, markeralpha = 0.5)

    # ── (b) Side view ──────────────────────────────────────────
    p2 = plot(title = "(b) Side view", xlabel = "x (a.u.)", ylabel = "z (a.u.)",
              legend = false, titlefontsize = 12,
              ylims = (-2.2, 2.2), grid = true, framestyle = :box)
    for (xs, zs) in coil_xz
        plot!(p2, xs, zs, color = :blue, lw = 1.2)
    end
    scatter!(p2, X[keep], Z[keep], color = :darkorange, markersize = 1.0,
             markerstrokewidth = 0, markeralpha = 0.5)

    # ── Combine ────────────────────────────────────────────────
    plot(p1, p2, layout = @layout([a; b]), size = (1150, 950),
         plot_title = "LMC — 10,000 test particles (E = 1 keV)   " *
                      "t = $(round(t_us, digits=2)) µs,  " *
                      "confined = $n_alive / $N_PARTICLES",
         plot_titlefontsize = 13)

    if fi % 10 == 0
        println("  Frame $fi/$N_FRAMES  alive=$n_alive")
    end
end

gif(anim, OUTPUT_PATH, fps = FRAMERATE)
println("Saved $OUTPUT_PATH")
println("Done!")
