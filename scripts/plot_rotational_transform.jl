# ============================================================================
#  Figure 4 — Rotational Transform ι profile vs radial position x
#
#  Run:  julia --project=. scripts/plot_rotational_transform.jl
#  Takes ~30 seconds.
# ============================================================================

include(joinpath(@__DIR__, "lmc_field_utils.jl"))
using Plots; gr()

function main()
    cs = make_coils()   # baseline

    # ── Find magnetic axis ─────────────────────────────────────────────────
    perim     = 2*12.0 + 2π*3.0
    max_steps = Int(ceil(15 * perim / 0.08)) + 3000

    x_ax = 9.02; z_ax = 0.0
    for _ in 1:3
        cx, cz = trace_crossings([x_ax, 0.0, z_ax], cs; ds=0.08, max_steps)
        length(cx) < 3 && error("Not enough crossings to find axis")
        x_ax = mean(cx); z_ax = mean(cz)
    end
    println("Magnetic axis at x = $(round(x_ax, digits=4))")

    # ── Compute ι at several radial offsets ────────────────────────────────
    offsets = [0.02, 0.03, 0.05, 0.08, 0.10, 0.12, 0.15, 0.18, 0.20]
    x_vals  = Float64[]
    ι_vals  = Float64[]

    for off in offsets
        print("  offset=$off → ")
        cx2, cz2 = trace_crossings([x_ax + off, 0.0, z_ax], cs; ds=0.08, max_steps)
        if length(cx2) < 4
            println("too few crossings, skipping"); continue
        end

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
        nn < 3 && (println("too few data, skipping"); continue)

        xf = collect(1:nn)
        yf = unwrapped[n_skip+1:end] .- unwrapped[n_skip+1]
        slope = (nn*sum(xf .* yf) - sum(xf)*sum(yf)) /
                (nn*sum(xf .^ 2) - sum(xf)^2)
        ι = abs(slope) / (2π)

        x_pos = x_ax + off
        println("x=$(round(x_pos, digits=3)), ι=$(round(ι, digits=6))")
        push!(x_vals, x_pos)
        push!(ι_vals, ι)
    end

    # ── Plot ───────────────────────────────────────────────────────────────
    fig = plot(x_vals, ι_vals,
               xlabel="x (m)", ylabel="ι",
               title="Rotational Transform vs x",
               marker=:circle, markersize=4, linewidth=2,
               color=:black, legend=false,
               grid=true, gridalpha=0.3,
               size=(700, 500))

    outpath = joinpath(@__DIR__, "..", "lmc_rotational_transform.png")
    savefig(fig, outpath)
    println("Saved → $outpath")
end

main()
