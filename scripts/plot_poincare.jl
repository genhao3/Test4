# ============================================================================
#  Figure 2 — Poincaré Cross-sections at φ=0 and φ=π/2
#  4 inner (blue) + 2 outer (red) flux surfaces.
#
#  Run:  julia --project=. scripts/plot_poincare.jl
#  Takes ~3-4 minutes (field-line tracing for 6 surfaces × 2 sections).
# ============================================================================

include(joinpath(@__DIR__, "lmc_field_utils.jl"))
using Plots; gr()

function main()
    cs = make_coils()   # baseline

    # ── Parameters ─────────────────────────────────────────────────────────
    axis_x = 9.019
    inner_offsets = [0.01, 0.03, 0.06, 0.10]   # blue
    outer_offsets = [0.20, 0.35]                 # red

    n_transits = 60
    ds         = 0.08
    perim      = 2*12.0 + 2π*3.0
    max_steps  = Int(ceil(n_transits * perim / ds)) + 3000

    println("Tracing 6 flux surfaces ($n_transits transits each)...")

    # Storage
    poincare_data = []

    for (offsets, clr, label) in [(inner_offsets, :blue, "inner"),
                                   (outer_offsets, :red,  "outer")]
        for off in offsets
            start = [axis_x + off, 0.0, 0.0]
            println("  offset=$off ($label) ...")

            cx0, cz0   = trace_crossings(start, cs; ds, max_steps)
            cy90, cz90 = trace_crossings_phi90(start, cs; ds, max_steps)

            push!(poincare_data, (; off, clr, cx0, cz0, cy90, cz90))
        end
    end

    # ── Plot ───────────────────────────────────────────────────────────────
    p1 = plot(title="(a) Cross-section at φ = 0",
              xlabel="x (m)", ylabel="z (m)", aspect_ratio=:equal,
              legend=false, grid=false)
    scatter!(p1, [axis_x], [0.0], color=:darkblue, markersize=5,
             markerstrokewidth=0)
    for d in poincare_data
        scatter!(p1, d.cx0, d.cz0; color=d.clr, markersize=1.5,
                 markerstrokewidth=0)
    end

    p2 = plot(title="(b) Cross-section at φ = π/2",
              xlabel="y (m)", ylabel="z (m)", aspect_ratio=:equal,
              legend=false, grid=false)
    axis_y_est = isempty(poincare_data[1].cy90) ? 3.18 :
                 mean(poincare_data[1].cy90)
    scatter!(p2, [axis_y_est], [0.0], color=:darkblue, markersize=5,
             markerstrokewidth=0)
    for d in poincare_data
        scatter!(p2, d.cy90, d.cz90; color=d.clr, markersize=1.5,
                 markerstrokewidth=0)
    end

    fig = plot(p1, p2, layout=(1,2), size=(1400, 500), margin=5Plots.mm)

    outpath = joinpath(@__DIR__, "..", "lmc_poincare.png")
    savefig(fig, outpath)
    println("Saved → $outpath")
end

main()
