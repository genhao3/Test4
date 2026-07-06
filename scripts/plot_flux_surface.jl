# ============================================================================
#  Flux Surface Plot — coil geometry only (top view + side view)
#  Reproduces the original lmc_flux_surface.png exactly.
#
#  Run:  julia --project=. scripts/plot_flux_surface.jl
# ============================================================================

include(joinpath(@__DIR__, "lmc_field_utils.jl"))
using Plots; gr()

function draw_coil_projection!(plt, center, normal, radius;
                               proj=:xy, n_pts=80, kw...)
    n̂  = normal / norm(normal)
    ref = abs(n̂[3]) < 0.9 ? [0.0, 0.0, 1.0] : [1.0, 0.0, 0.0]
    e1  = cross(n̂, ref); e1 /= norm(e1)
    e2  = cross(n̂, e1)

    θs = range(0, 2π, length=n_pts+1)
    xs = [center[1] + radius*(cos(θ)*e1[1] + sin(θ)*e2[1]) for θ in θs]
    ys = [center[2] + radius*(cos(θ)*e1[2] + sin(θ)*e2[2]) for θ in θs]
    zs = [center[3] + radius*(cos(θ)*e1[3] + sin(θ)*e2[3]) for θ in θs]

    if proj == :xy
        plot!(plt, xs, ys; label="", kw...)
    elseif proj == :xz
        plot!(plt, xs, zs; label="", kw...)
    end
end

function main()
    cs = make_coils()

    # ── (a) Top view x-y ──────────────────────────────────────────────────
    p1 = plot(title="(a) Top view of the linked mirror configuration",
              xlabel="x (m)", ylabel="y (m)", aspect_ratio=:equal,
              legend=false, grid=false, bg=:white)
    for i in eachindex(cs.positions)
        draw_coil_projection!(p1, cs.positions[i], cs.normals[i], cs.radius;
                              proj=:xy, color=:blue, linewidth=1)
    end

    # ── (b) Side view x-z ─────────────────────────────────────────────────
    p2 = plot(title="(b) Side view of the linked mirror configuration",
              xlabel="x (m)", ylabel="z (m)", aspect_ratio=:equal,
              legend=false, grid=false, bg=:white)
    for i in eachindex(cs.positions)
        draw_coil_projection!(p2, cs.positions[i], cs.normals[i], cs.radius;
                              proj=:xz, color=:blue, linewidth=1)
    end

    fig = plot(p1, p2, layout=(2,1), size=(1000, 1100), margin=5Plots.mm)

    outpath = joinpath(@__DIR__, "..", "lmc_flux_surface.png")
    savefig(fig, outpath)
    println("Saved → $outpath")
end

main()
