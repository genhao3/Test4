# Racetrack (Linked Mirror Configuration) coil geometry helper functions
# Called by Dyad at model construction time to compute coil parameters.

# ── Geometry constants ────────────────────────────────────────────────
const _RT_STRAIGHT_LENGTH = 12.0        # m  – length of each straight mirror segment
const _RT_SEMI_RADIUS     = 3.0         # m  – half-separation / semicircle radius (d)
const _RT_COIL_RADIUS     = 1.0         # m  – radius of each individual coil (r)
const _RT_THETA           = π / 20      # rad – tilt angle Θ of each straight segment from z=0

# Derived
const _RT_HALF_L = _RT_STRAIGHT_LENGTH / 2   # L/2 = 6 m
const _RT_H      = _RT_HALF_L * tan(_RT_THETA)  # z-displacement at end of straight segment

# Coil counts
const _RT_N_STRAIGHT = 11
const _RT_N_SEMI     = 10
const _RT_N_TOTAL    = 42   # 2×11 + 2×10

# Current values  (semicircle : straight middle = 5 : 1)
const _RT_I_HIGH = 5.0    # A – semicircle coils and straight end coils
const _RT_I_LOW  = 1.0    # A – middle coils of straight sections

# Electrical parameters
const _RT_R_COIL = 5.0    # Ω – wire resistance per coil

# ── Internal: determine which segment a global coil index belongs to ─
function _rt_segment(i::Int)
    #  i =  1–11 → Straight 1     (top,    y = +d)
    #  i = 12–21 → Right semicircle
    #  i = 22–32 → Straight 2     (bottom, y = -d)
    #  i = 33–42 → Left semicircle
    if i <= 11
        return :straight1, i - 1        # j = 0…10
    elseif i <= 21
        return :right_semi, i - 12      # j = 0…9
    elseif i <= 32
        return :straight2, i - 22       # j = 0…10
    else
        return :left_semi, i - 33       # j = 0…9
    end
end

# ── Position getters (called from Dyad comprehension) ────────────────
# Convention: Straights use endpoint-inclusive spacing j/(N-1),
#             Semicircles use interior spacing (j+1)/(N+1) to avoid junction overlap.

function _rt_straight_frac(j::Int)::Float64
    # Endpoint-inclusive: j=0 at start, j=10 at end
    return j / (_RT_N_STRAIGHT - 1)
end

function _rt_semi_angle(j::Int)::Float64
    # Interior spacing: avoids φ=0 and φ=π (the junction endpoints)
    return (j + 1) / (_RT_N_SEMI + 1) * π
end

function racetrack_get_px(i::Int)::Float64
    seg, j = _rt_segment(i)
    L2 = _RT_HALF_L
    R  = _RT_SEMI_RADIUS
    if seg == :straight1
        t = _rt_straight_frac(j)
        return -L2 + _RT_STRAIGHT_LENGTH * t
    elseif seg == :right_semi
        φ = _rt_semi_angle(j)
        return L2 + R * sin(φ)
    elseif seg == :straight2
        t = _rt_straight_frac(j)
        return L2 - _RT_STRAIGHT_LENGTH * t
    else  # left_semi
        φ = _rt_semi_angle(j)
        return -L2 - R * sin(φ)
    end
end

function racetrack_get_py(i::Int)::Float64
    seg, j = _rt_segment(i)
    R = _RT_SEMI_RADIUS
    if seg == :straight1
        return R                        # y = +d
    elseif seg == :right_semi
        φ = _rt_semi_angle(j)
        return R * cos(φ)               # sweeps from +d to -d
    elseif seg == :straight2
        return -R                       # y = -d
    else  # left_semi
        φ = _rt_semi_angle(j)
        return -R * cos(φ)              # sweeps from -d to +d
    end
end

function racetrack_get_pz(i::Int)::Float64
    seg, j = _rt_segment(i)
    h = _RT_H   # (L/2) * tan(Θ)
    if seg == :straight1
        x = racetrack_get_px(i)
        return x * tan(_RT_THETA)                # z rises with x
    elseif seg == :right_semi
        φ = _rt_semi_angle(j)
        return h * cos(φ)                        # smooth: +h at φ=0 to -h at φ=π
    elseif seg == :straight2
        x = racetrack_get_px(i)
        return -x * tan(_RT_THETA)               # opposite tilt
    else  # left_semi
        φ = _rt_semi_angle(j)
        return h * cos(φ)
    end
end

# ── Normal-direction getters (tangent to the racetrack path) ─────────

function _rt_tangent_raw(i::Int)
    seg, j = _rt_segment(i)
    R = _RT_SEMI_RADIUS
    h = _RT_H
    tanΘ = tan(_RT_THETA)
    if seg == :straight1
        # Tangent: +x direction with upward tilt
        return (1.0, 0.0, tanΘ)
    elseif seg == :right_semi
        # x(φ) = L/2 + R*sin(φ), y(φ) = R*cos(φ), z(φ) = h*cos(φ)
        # dx/dφ = R*cos(φ), dy/dφ = -R*sin(φ), dz/dφ = -h*sin(φ)
        φ = _rt_semi_angle(j)
        return (R * cos(φ), -R * sin(φ), -h * sin(φ))
    elseif seg == :straight2
        # Tangent: -x direction with upward tilt (z = -x*tanΘ, going right to left)
        return (-1.0, 0.0, tanΘ)
    else  # left_semi
        # x(φ) = -L/2 - R*sin(φ), y(φ) = -R*cos(φ), z(φ) = h*cos(φ)
        # dx/dφ = -R*cos(φ), dy/dφ = R*sin(φ), dz/dφ = -h*sin(φ)
        φ = _rt_semi_angle(j)
        return (-R * cos(φ), R * sin(φ), -h * sin(φ))
    end
end

function racetrack_get_nx(i::Int)::Float64
    tx, ty, tz = _rt_tangent_raw(i)
    mag = sqrt(tx^2 + ty^2 + tz^2)
    return tx / mag
end

function racetrack_get_ny(i::Int)::Float64
    tx, ty, tz = _rt_tangent_raw(i)
    mag = sqrt(tx^2 + ty^2 + tz^2)
    return ty / mag
end

function racetrack_get_nz(i::Int)::Float64
    tx, ty, tz = _rt_tangent_raw(i)
    mag = sqrt(tx^2 + ty^2 + tz^2)
    return tz / mag
end

# ── Current getter ───────────────────────────────────────────────────

function racetrack_get_current(i::Int)::Float64
    seg, j = _rt_segment(i)
    # All semicircle coils → high current
    if seg == :right_semi || seg == :left_semi
        return _RT_I_HIGH
    end
    # Straight segment: 4 end coils per segment (2 at each end) → high current
    # j = 0,1 (first two) and j = 9,10 (last two)
    if j <= 1 || j >= _RT_N_STRAIGHT - 2
        return _RT_I_HIGH
    end
    return _RT_I_LOW
end

# ── Voltage getter (for Dyad Step signal: V = I_ss * R) ─────────────

function racetrack_get_voltage(i::Int)::Float64
    return racetrack_get_current(i) * _RT_R_COIL
end

# ── Array versions (for use from Julia post-processing) ──────────────

function racetrack_all_positions()
    px = [racetrack_get_px(i) for i in 1:_RT_N_TOTAL]
    py = [racetrack_get_py(i) for i in 1:_RT_N_TOTAL]
    pz = [racetrack_get_pz(i) for i in 1:_RT_N_TOTAL]
    return px, py, pz
end

function racetrack_all_normals()
    nx = [racetrack_get_nx(i) for i in 1:_RT_N_TOTAL]
    ny = [racetrack_get_ny(i) for i in 1:_RT_N_TOTAL]
    nz = [racetrack_get_nz(i) for i in 1:_RT_N_TOTAL]
    return nx, ny, nz
end

function racetrack_all_currents()
    return [racetrack_get_current(i) for i in 1:_RT_N_TOTAL]
end

# ── Biot-Savart magnetic field computation ───────────────────────────

const μ₀ = 4π * 1e-7   # T·m/A – vacuum permeability

# Cross product helper (to avoid depending on LinearAlgebra at module load)
function cross(a, b)
    return [a[2]*b[3] - a[3]*b[2],
            a[3]*b[1] - a[1]*b[3],
            a[1]*b[2] - a[2]*b[1]]
end

"""
    biot_savart_coil(r, center, normal, radius, current; n_turns=1, n_seg=100)

Compute the magnetic field vector B [T] at point `r` due to a circular coil
using the Biot-Savart law.
"""
function biot_savart_coil(r::AbstractVector, center::AbstractVector,
                          normal::AbstractVector, radius::Float64,
                          current::Float64; n_turns::Int=1, n_seg::Int=100)
    # Build orthonormal basis for the coil plane
    n̂ = normal / sqrt(sum(normal .^ 2))
    ref = abs(n̂[3]) < 0.9 ? [0.0, 0.0, 1.0] : [1.0, 0.0, 0.0]
    e1 = cross(n̂, ref)
    e1 = e1 / sqrt(sum(e1 .^ 2))
    e2 = cross(n̂, e1)

    B = [0.0, 0.0, 0.0]
    dθ = 2π / n_seg
    NI = n_turns * current

    for k in 1:n_seg
        θ  = (k - 0.5) * dθ
        P  = center .+ radius .* (cos(θ) .* e1 .+ sin(θ) .* e2)
        dl = radius .* (-sin(θ) .* e1 .+ cos(θ) .* e2) .* dθ
        rv = r .- P
        dist = sqrt(sum(rv .^ 2))
        if dist < 1e-12
            continue
        end
        dB = (μ₀ / (4π)) * NI .* cross(dl, rv) ./ dist^3
        B .+= dB
    end
    return B
end

"""
    compute_total_field(r; currents=nothing, n_turns=100, n_seg=100)

Compute the total magnetic field at point `r` from all 42 racetrack coils.
Optionally provide a `currents` vector to override the default current values.
`n_turns` is the number of turns per coil (default 100, matching the Dyad model).
"""
function compute_total_field(r::AbstractVector; currents::Union{Nothing,AbstractVector}=nothing,
                             n_turns::Int=100, n_seg::Int=100)
    B_total = [0.0, 0.0, 0.0]
    for i in 1:_RT_N_TOTAL
        center = [racetrack_get_px(i), racetrack_get_py(i), racetrack_get_pz(i)]
        normal = [racetrack_get_nx(i), racetrack_get_ny(i), racetrack_get_nz(i)]
        I = isnothing(currents) ? racetrack_get_current(i) : currents[i]
        B = biot_savart_coil(r, center, normal, _RT_COIL_RADIUS, I; n_turns=n_turns, n_seg=n_seg)
        B_total .+= B
    end
    return B_total
end
