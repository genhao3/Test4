# ============================================================================
#  Figure 5 — Rotational Transform ι vs four parameters
#  (a) 2Θ/π   (b) L   (c) d   (d) current ratio
#
#  Run:  julia --project=. scripts/plot_figure5.jl
#  Takes ~2-3 minutes (38 parameter points × ~2 s each).
# ============================================================================

include(joinpath(@__DIR__, "lmc_field_utils.jl"))
using Plots; gr()

function main()
    # ── (a) ι vs 2Θ/π ─────────────────────────────────────────────────────
    println("Scan (a): ι vs Θ ...")
    theta_x = [0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50]
    iota_theta = Float64[]
    for tv in theta_x
        ι = compute_iota(Theta = tv * π / 2, n_transits = 15)
        println("  2Θ/π=$tv → ι=$(round(ι, digits=5))")
        push!(iota_theta, ι)
    end

    # ── (b) ι vs L ─────────────────────────────────────────────────────────
    println("Scan (b): ι vs L ...")
    L_vals = [4.0, 6.0, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0]
    iota_L = Float64[]
    for Lv in L_vals
        ι = compute_iota(L = Lv, n_transits = 15)
        println("  L=$Lv → ι=$(round(ι, digits=5))")
        push!(iota_L, ι)
    end

    # ── (c) ι vs d ─────────────────────────────────────────────────────────
    println("Scan (c): ι vs d ...")
    d_vals = [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
    iota_d = Float64[]
    for dv in d_vals
        ι = compute_iota(d = dv, n_transits = 15)
        println("  d=$dv → ι=$(round(ι, digits=5))")
        push!(iota_d, ι)
    end

    # ── (d) ι vs current ratio ────────────────────────────────────────────
    println("Scan (d): ι vs ratio ...")
    ratio_vals = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
    iota_ratio = Float64[]
    for rv in ratio_vals
        ι = compute_iota(ratio = rv, n_transits = 15)
        println("  ratio=$rv → ι=$(round(ι, digits=5))")
        push!(iota_ratio, ι)
    end

    # ── Plot 2×2 ───────────────────────────────────────────────────────────
    p1 = plot(theta_x, iota_theta,
        xlabel="2Θ/π", ylabel="ι",
        title="(a) ι vs tilt angle Θ",
        marker=:circle, markersize=4, linewidth=2,
        label="Biot-Savart model", color=:blue,
        legend=:topleft, xlim=(0, 0.55), ylim=(0, 0.7))
    θr = collect(range(0, 0.5, length=50))
    plot!(p1, θr, 1.15 .* θr, linestyle=:dash, color=:red,
          label="Paper trend (approx)", linewidth=1.5)

    p2 = plot(L_vals, iota_L,
        xlabel="L [m]", ylabel="ι",
        title="(b) ι vs straight length L",
        marker=:circle, markersize=4, linewidth=2,
        label="Biot-Savart", color=:blue, legend=:topleft)

    p3 = plot(d_vals, iota_d,
        xlabel="d [m]", ylabel="ι",
        title="(c) ι vs half-separation d",
        marker=:circle, markersize=4, linewidth=2,
        label="Biot-Savart", color=:blue, legend=:topright)

    p4 = plot(ratio_vals, iota_ratio,
        xlabel="I_torus / I_tube", ylabel="ι",
        title="(d) ι vs current ratio",
        marker=:circle, markersize=4, linewidth=2,
        label="Biot-Savart", color=:blue, legend=:topright,
        ylim=(0.0, 0.3))

    fig = plot(p1, p2, p3, p4, layout=(2,2), size=(1000, 800),
        plot_title="Figure 5: Rotational Transform ι Parameter Dependence",
        plot_titlefontsize=12, margin=5Plots.mm)

    outpath = joinpath(@__DIR__, "..", "lmc_figure5.png")
    savefig(fig, outpath)
    println("Saved → $outpath")
end

main()
