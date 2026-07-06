# ============================================================================
#  LMC Field Utilities — shared by all plotting scripts
#  Biot-Savart coil field, racetrack geometry, field-line tracing, ι computation
# ============================================================================

using LinearAlgebra, Statistics

const μ₀ = 4π * 1e-7   # T·m/A

# ── Racetrack geometry ──────────────────────────────────────────────────────

"""
    CoilSet

Stores positions, normals, currents and radius for an array of circular coils.
"""
struct CoilSet
    positions ::Vector{Vector{Float64}}
    normals   ::Vector{Vector{Float64}}
    currents  ::Vector{Float64}
    radius    ::Float64
    n_turns   ::Int
end

"""
    make_coils(; Theta, L, d, r_coil, ratio, N_str, N_semi, n_turns)

Generate a `CoilSet` for the linked-mirror (racetrack) configuration.

# Convention D
- Straight segments: endpoint-inclusive spacing  `j/(N_str-1)`
- Semicircles: interior spacing  `(j+1)/(N_semi+1) * π`

# Current assignment
- Semicircle coils and the 2 end coils at each end of each straight → `I_high = 5 A`
- Middle coils of straight segments → `I_low = I_high / ratio`
"""
function make_coils(; Theta ::Float64 = π/20,
                      L     ::Float64 = 12.0,
                      d     ::Float64 = 3.0,
                      r_coil::Float64 = 1.0,
                      ratio ::Float64 = 5.0,
                      N_str ::Int     = 11,
                      N_semi::Int     = 10,
                      n_turns::Int    = 100)

    half_L = L / 2
    h      = half_L * tan(Theta)
    I_high = 5.0
    I_low  = I_high / ratio

    N_total = 2N_str + 2N_semi
    pos = Vector{Vector{Float64}}(undef, N_total)
    nrm = Vector{Vector{Float64}}(undef, N_total)
    cur = Vector{Float64}(undef, N_total)
    idx = 0

    # ── Straight 1 (y = +d) ──
    for j in 0:N_str-1
        idx += 1
        t = j / (N_str - 1)
        x = -half_L + L * t
        pos[idx] = [x, d, x * tan(Theta)]
        v = [1.0, 0.0, tan(Theta)]; nrm[idx] = v / norm(v)
        cur[idx] = (j ≤ 1 || j ≥ N_str - 2) ? I_high : I_low
    end

    # ── Right semicircle ──
    for j in 0:N_semi-1
        idx += 1
        φ = (j + 1) / (N_semi + 1) * π
        pos[idx] = [half_L + d*sin(φ),  d*cos(φ), h*cos(φ)]
        v = [d*cos(φ), -d*sin(φ), -h*sin(φ)]; nrm[idx] = v / norm(v)
        cur[idx] = I_high
    end

    # ── Straight 2 (y = -d) ──
    for j in 0:N_str-1
        idx += 1
        t = j / (N_str - 1)
        x = half_L - L * t
        pos[idx] = [x, -d, -x * tan(Theta)]
        v = [-1.0, 0.0, tan(Theta)]; nrm[idx] = v / norm(v)
        cur[idx] = (j ≤ 1 || j ≥ N_str - 2) ? I_high : I_low
    end

    # ── Left semicircle ──
    for j in 0:N_semi-1
        idx += 1
        φ = (j + 1) / (N_semi + 1) * π
        pos[idx] = [-half_L - d*sin(φ), -d*cos(φ), h*cos(φ)]
        v = [-d*cos(φ), d*sin(φ), -h*sin(φ)]; nrm[idx] = v / norm(v)
        cur[idx] = I_high
    end

    return CoilSet(pos, nrm, cur, r_coil, n_turns)
end

# ── Biot-Savart field computation ──────────────────────────────────────────

"""
In-place Biot-Savart: add field of one circular coil to `B`.
"""
function bs_coil!(B, r, center, normal, radius, current, n_turns, n_seg,
                  e1, e2, P, dl, rv)
    n̂ = normal / norm(normal)
    ref = abs(n̂[3]) < 0.9 ? [0.0, 0.0, 1.0] : [1.0, 0.0, 0.0]

    e1[1] = n̂[2]*ref[3] - n̂[3]*ref[2]
    e1[2] = n̂[3]*ref[1] - n̂[1]*ref[3]
    e1[3] = n̂[1]*ref[2] - n̂[2]*ref[1]
    mag = norm(e1); e1 ./= mag

    e2[1] = n̂[2]*e1[3] - n̂[3]*e1[2]
    e2[2] = n̂[3]*e1[1] - n̂[1]*e1[3]
    e2[3] = n̂[1]*e1[2] - n̂[2]*e1[1]

    dθ = 2π / n_seg
    NI = n_turns * current

    for k in 1:n_seg
        θ  = (k - 0.5) * dθ
        cθ = cos(θ); sθ = sin(θ)
        for d in 1:3
            P[d]  = center[d] + radius * (cθ * e1[d] + sθ * e2[d])
            dl[d] = radius * (-sθ * e1[d] + cθ * e2[d]) * dθ
            rv[d] = r[d] - P[d]
        end
        dist = norm(rv)
        dist < 1e-12 && continue
        fac  = (μ₀ / 4π) * NI / dist^3
        B[1] += fac * (dl[2]*rv[3] - dl[3]*rv[2])
        B[2] += fac * (dl[3]*rv[1] - dl[1]*rv[3])
        B[3] += fac * (dl[1]*rv[2] - dl[2]*rv[1])
    end
end

"""
    total_B!(B, r, cs; n_seg=40)

Compute total magnetic field from all coils in `cs` at point `r`.
Result is stored in pre-allocated vector `B`.
"""
function total_B!(B, r, cs::CoilSet; n_seg::Int=40)
    B[1] = B[2] = B[3] = 0.0
    e1 = zeros(3); e2 = zeros(3); P = zeros(3); dl = zeros(3); rv = zeros(3)
    for i in eachindex(cs.positions)
        bs_coil!(B, r, cs.positions[i], cs.normals[i], cs.radius,
                 cs.currents[i], cs.n_turns, n_seg, e1, e2, P, dl, rv)
    end
end

"""
    total_B(r, cs; n_seg=40) -> Vector{Float64}

Allocating convenience wrapper.
"""
function total_B(r, cs::CoilSet; n_seg::Int=40)
    B = zeros(3); total_B!(B, r, cs; n_seg); return B
end

# ── Field-line tracing (RK4) ──────────────────────────────────────────────

"""
    trace_field_line(start, cs; ds, max_steps, n_seg)

Trace a magnetic field line from `start`, returning all points.
"""
function trace_field_line(start_pt::Vector{Float64}, cs::CoilSet;
                          ds::Float64=0.08, max_steps::Int=50000,
                          n_seg::Int=40)
    pts = [copy(start_pt)]
    r   = copy(start_pt)
    B   = zeros(3)
    b1 = zeros(3); b2 = zeros(3); b3 = zeros(3); b4 = zeros(3)
    rtmp = zeros(3)

    for _ in 1:max_steps
        total_B!(B, r, cs; n_seg); mag = norm(B); b1 .= B ./ mag
        rtmp .= r .+ 0.5 .* ds .* b1
        total_B!(B, rtmp, cs; n_seg); mag = norm(B); b2 .= B ./ mag
        rtmp .= r .+ 0.5 .* ds .* b2
        total_B!(B, rtmp, cs; n_seg); mag = norm(B); b3 .= B ./ mag
        rtmp .= r .+ ds .* b3
        total_B!(B, rtmp, cs; n_seg); mag = norm(B); b4 .= B ./ mag

        r .+= (ds / 6) .* (b1 .+ 2 .* b2 .+ 2 .* b3 .+ b4)
        push!(pts, copy(r))
    end
    return pts
end

"""
    trace_crossings(start, cs; ds, max_steps, n_seg)

Trace a field line and record y=0 crossings (y: + → −) with x > 0.
Returns `(cross_x, cross_z)`.
"""
function trace_crossings(start_pt::Vector{Float64}, cs::CoilSet;
                         ds::Float64=0.08, max_steps::Int=20000,
                         n_seg::Int=40)
    r = copy(start_pt); r_prev = copy(start_pt)
    B = zeros(3)
    b1 = zeros(3); b2 = zeros(3); b3 = zeros(3); b4 = zeros(3)
    rtmp = zeros(3)

    cx = Float64[]; cz = Float64[]

    for _ in 1:max_steps
        r_prev .= r
        total_B!(B, r, cs; n_seg); mag = norm(B); b1 .= B ./ mag
        rtmp .= r .+ 0.5 .* ds .* b1
        total_B!(B, rtmp, cs; n_seg); mag = norm(B); b2 .= B ./ mag
        rtmp .= r .+ 0.5 .* ds .* b2
        total_B!(B, rtmp, cs; n_seg); mag = norm(B); b3 .= B ./ mag
        rtmp .= r .+ ds .* b3
        total_B!(B, rtmp, cs; n_seg); mag = norm(B); b4 .= B ./ mag
        r .+= (ds / 6) .* (b1 .+ 2 .* b2 .+ 2 .* b3 .+ b4)

        # Detect y crossing from + to − with x > 0
        if r_prev[2] > 0 && r[2] ≤ 0 && r[1] > 0
            frac = abs(r_prev[2]) / (abs(r_prev[2]) + abs(r[2]))
            push!(cx, r_prev[1] + frac * (r[1] - r_prev[1]))
            push!(cz, r_prev[3] + frac * (r[3] - r_prev[3]))
        end
    end
    return cx, cz
end

"""
    trace_crossings_phi90(start, cs; ds, max_steps, n_seg)

Same as `trace_crossings` but detects x=0 crossings (x: + → −) with y > 0.
Returns `(cross_y, cross_z)`.
"""
function trace_crossings_phi90(start_pt::Vector{Float64}, cs::CoilSet;
                               ds::Float64=0.08, max_steps::Int=20000,
                               n_seg::Int=40)
    r = copy(start_pt); r_prev = copy(start_pt)
    B = zeros(3)
    b1 = zeros(3); b2 = zeros(3); b3 = zeros(3); b4 = zeros(3)
    rtmp = zeros(3)

    cy = Float64[]; cz = Float64[]

    for _ in 1:max_steps
        r_prev .= r
        total_B!(B, r, cs; n_seg); mag = norm(B); b1 .= B ./ mag
        rtmp .= r .+ 0.5 .* ds .* b1
        total_B!(B, rtmp, cs; n_seg); mag = norm(B); b2 .= B ./ mag
        rtmp .= r .+ 0.5 .* ds .* b2
        total_B!(B, rtmp, cs; n_seg); mag = norm(B); b3 .= B ./ mag
        rtmp .= r .+ ds .* b3
        total_B!(B, rtmp, cs; n_seg); mag = norm(B); b4 .= B ./ mag
        r .+= (ds / 6) .* (b1 .+ 2 .* b2 .+ 2 .* b3 .+ b4)

        # x crossing from − to + with y > 0  (top straight, moving in +x)
        if r_prev[1] < 0 && r[1] ≥ 0 && r[2] > 0
            frac = abs(r_prev[1]) / (abs(r_prev[1]) + abs(r[1]))
            push!(cy, r_prev[2] + frac * (r[2] - r_prev[2]))
            push!(cz, r_prev[3] + frac * (r[3] - r_prev[3]))
        end
    end
    return cy, cz
end

# ── Rotational-transform computation ──────────────────────────────────────

"""
    compute_iota(; Theta, L, d, r_coil, ratio, n_transits, ds, axis_iters)

Compute the rotational transform ι at baseline parameters.
Uses iterative axis finding and angle-unwrapped linear fit.
"""
function compute_iota(; Theta  ::Float64 = π/20,
                        L      ::Float64 = 12.0,
                        d      ::Float64 = 3.0,
                        r_coil ::Float64 = 1.0,
                        ratio  ::Float64 = 5.0,
                        n_transits::Int  = 12,
                        ds     ::Float64 = 0.08,
                        axis_iters::Int  = 3)

    cs   = make_coils(Theta=Theta, L=L, d=d, r_coil=r_coil, ratio=ratio)
    perim    = 2L + 2π*d
    max_steps = Int(ceil(n_transits * perim / ds)) + 3000

    # ── Iterative axis finding ──
    x_ax = L/2 + d + 0.02
    z_ax = 0.0
    for _ in 1:axis_iters
        cx, cz = trace_crossings([x_ax, 0.0, z_ax], cs; ds, max_steps)
        length(cx) < 3 && return NaN
        x_ax = mean(cx)
        z_ax = mean(cz)
    end

    # ── Offset field-line ──
    cx2, cz2 = trace_crossings([x_ax + 0.03, 0.0, z_ax], cs; ds, max_steps)
    length(cx2) < 4 && return NaN

    # ── Angle unwrap + linear fit ──
    angles = [atan(cz2[k] - z_ax, cx2[k] - x_ax) for k in eachindex(cx2)]
    unwrapped = [angles[1]]
    for k in 2:length(angles)
        da = angles[k] - angles[k-1]
        while da >  π; da -= 2π; end
        while da < -π; da += 2π; end
        push!(unwrapped, unwrapped[end] + da)
    end

    n_skip = min(2, length(unwrapped) - 3)
    nn = length(unwrapped) - n_skip
    nn < 3 && return NaN

    xf = collect(1:nn)
    yf = unwrapped[n_skip+1:end] .- unwrapped[n_skip+1]
    slope = (nn * sum(xf .* yf) - sum(xf) * sum(yf)) /
            (nn * sum(xf .^ 2) - sum(xf)^2)

    return abs(slope) / (2π)
end

println("lmc_field_utils.jl loaded.")
