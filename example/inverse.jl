using JuliaSourceMechanism, JLD2, LinearAlgebra, Printf, Dates

prefix = ARGS[1]

@info "Load buffer"
(env, status) = let
    t = load(joinpath(@__DIR__, "..", prefix * ".jld2"))
    (t["env"], t["status"])
end

@info "Copy data"
nenv = Setting()
nenv["dataroot"] = abspath("..")
nenv["algorithm"] = env["algorithm"]
nenv["event"] = env["event"]
nenv["stations"] = Setting[]
for s in env["stations"]
    # if s["network"] * "." * s["station"] ∈ status["stationlist_selected"]
        t = deepcopy(s)
        push!(nenv["stations"], t)
    # end
end
# @info "Change parameter"
# nenv["algorithm"]["misfit"] = ["xcorr", "pol"]
nenv["algorithm"]["weight"] = [1.0, 0.4]
# for s in nenv["stations"]
#     s["green_tsource"] = 0.04
#     s["green_t0"] = -2.0 * s["green_tsource"]
#     for p in s["phases"]
#         dt = s["meta_dt"]
#         tl = p["xcorr_trim"][2] - p["xcorr_trim"][1]
#         while (dt + 1e-3) * 200 < tl
#             dt += 1e-3
#         end
#         p["xcorr_dt"] = dt
#     end
# end

for s in nenv["stations"]
    for p in s["phases"]
        if p["type"] == "P"
            p["xcorr_trim"] = [-2.0, 3.0] ./ p["xcorr_band"][2]
        else
            p["xcorr_trim"] = [-4.0, 6.0] ./ p["xcorr_band"][2]
        end
        p["xcorr_dt"] = max(s["green_dt"], s["meta_dt"], (p["xcorr_trim"][2] - p["xcorr_trim"][1])/100)
    end
end

misfits = Module[]
for m in nenv["algorithm"]["misfit"], f in [XCorr, Polarity, PSR, DTW, AbsShift, RelShift]
    if m in f.tags
        push!(misfits, f)
    end
end

@info "Run"
JuliaSourceMechanism.calcgreen!(nenv)

for s in nenv["stations"]
    ot = Millisecond(nenv["event"]["origintime"] - s["base_begintime"]).value * 1e-3
    (meta, _) = JuliaSourceMechanism.Green.scangreenfile(normpath(nenv["dataroot"],
                                                                "greenfun",
                                                                @sprintf("%s-%.4f", s["green_model"],
                                                                        nenv["algorithm"]["searchdepth"]),
                                                                s["network"] * "." * s["station"] * "." *
                                                                s["component"] * ".gf"))
    for p in s["phases"]
        if p["type"] == "P"
            p["tt"] = meta["tp"] + ot
        elseif p["type"] == "S"
            p["tt"] = meta["ts"] + ot
        end
    end
end

preprocess!(nenv, misfits)
(sdr, phaselist, misfit, misfitdetail) = inverse!(nenv, misfits, Grid)
weight = normalize(map(x -> x[1].weight(x[2], env, env), phaselist), 1)
weight_xcorr = normalize(map(x->x[1] == XCorr ? 1.0 : 0.0, phaselist), 1)
weight_pol = normalize(map(x->x[1] == Polarity ? 1.0 : 0.0, phaselist), 1)
totalmisfit = replace(misfitdetail, NaN => 0.0) * weight
mis_xcorr = replace(misfitdetail, NaN => 0.0) * weight_xcorr
mis_pol = replace(misfitdetail, NaN => 0.0) * weight_pol
(minval, minidx) = findmin(totalmisfit)
mech = sdr[minidx]

result = Setting()
for s in nenv["stations"]
    sta = s["network"] * "." * s["station"]
    if !(sta ∈ keys(result))
        result[sta] = Setting()
    end
    c = s["component"]
    result[sta]["dist"] = s["base_distance"]
    result[sta][c] = Setting()
    for p in s["phases"]
        t = Setting()
        t["xcorr_rec"] = normalize(p["xcorr_record"], Inf)
        t["xcorr_syn"] = normalize(p["xcorr_greenfun"] * dc2ts(mech), Inf)
        t["xcorr_shift"] = XCorr.detail(p, dc2ts(mech))
        t["xcorr_dt"] = p["xcorr_dt"]
        t["polarity_rec"] = p["polarity_obs"]
        if p["type"] == "P"
            t["polarity_syn"] = sign(sum(p["polarity_syn"] .* dc2ts(mech)))
        end
        result[sta][c][p["type"]] = t
    end
end

result["info_mech"] = mech
result["info_misfit"] = minval
result["info_misfit_xcorr"] = mis_xcorr[minidx]
result["info_misfit_pol"] = mis_pol[minidx]

@info "Save"
jldsave(joinpath(@__DIR__, prefix * "_result.jld2"); result=result)

@info "Plot"
fname = prefix * "_result.jld2"
include("plot.jl")
