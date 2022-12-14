using DelimitedFiles, SeismicRayTrace, SeisTools, TOML, Dates, JuliaSourceMechanism, 
    SourceMechUI, Printf, JLD2
SeismicRayTrace.set!(; maxit=10000)

misfitmodules = [XCorr, Polarity]

dataroot = abspath(@__DIR__, "..")

if isempty(ARGS)

# * event infomation
event = let
    evtinfo = TOML.parsefile(joinpath(dataroot, "eventinfo.toml"))
    Dict("longitude" => evtinfo["longitude"],
        "latitude" => evtinfo["latitude"],
        "depth" => evtinfo["depth"],
        "magnitude" => evtinfo["mag"],
        "origintime" => evtinfo["time"])
end

algorithm = Dict("misfit" => [m.tags[1] for m in misfitmodules],
                "searchdepth" => event["depth"],
                "weight" => ones(length(misfitmodules)))

stations = buildstationconfiguration(dataroot, event)

# * station infomation
defaultband = [0.05, 0.3]
for s in stations
    sacf = SeisTools.SAC.read(normpath(dataroot, "sac", s["meta_file"]))
    # - trim window
    s["base_trim"] = [event["origintime"] - Second(90),
                    SeisTools.SAC.DateTime(sacf.hdr) +
                    Millisecond(round(Int, sacf.hdr["delta"] * sacf.hdr["npts"] * 1e3))]
    push!(s["phases"], Dict("type" => "P", "at" => now()))
    push!(s["phases"], Dict("type" => "S", "at" => now()))
    # - Green function setting
    # general options
    s["green_modeltype"] = ""
    s["green_model"] = ""
    s["green_tsource"] = 0.1
    s["green_dt"] = 0.05
    # ! select one method below and comment others
    # - if use DWN
    # (tp, ts) = let
    #     m = readdlm(
    #         abspath(dataroot, "model", s["green_model"] * ".model"),
    #         ',';
    #         comments = true,
    #     )
    #     l = findlast(<=(-sacf.hdr["stel"] / 1000.0), m[:, 1])
    #     if isnothing(l)
    #         l = 1
    #     end
    #     m0 = m[l:end, :]
    #     m0[1, 1] = -sacf.hdr["stel"] / 1000.0
    #     tp = raytrace_fastest(0.0, event["depth"], s["base_distance"], m0[:, 1], m0[:, 2])
    #     ts = raytrace_fastest(0.0, event["depth"], s["base_distance"], m0[:, 1], m0[:, 3])
    #     (tp.phase.t, ts.phase.t)
    # end
    # s["green_m"] = 50000
    # s["green_tl"] = tp + ts / 0.5
    # - if use 3D numarical method like SEM, FD
    # s["green_modelpath"] = ""
    # s["green_ttlibpath"] = ""
    # * phase infomation
    for p in s["phases"]
        p["tt"] = round(p["at"] - event["origintime"], Millisecond).value * 1e-3
        if XCorr in misfitmodules
            p["xcorr_order"] = 4
            p["xcorr_band"] = defaultband
            p["xcorr_maxlag"] = 0.25 / p["xcorr_band"][2]
        end
        if p["type"] == "P"
            if XCorr in misfitmodules
                p["xcorr_trim"] = [-4.0, 4.0] ./ p["xcorr_band"][2]
            end
            if Polarity in misfitmodules
                if isnan(sacf.hdr["t1"])
                    p["polarity_obs"] = 0.0
                else
                    shift = round(Int, sacf.hdr["t1"] / sacf.hdr["delta"]) + 1
                    p["polarity_obs"] = sign(sum(sacf.data[shift:shift+9]))
                end
                p["polarity_trim"] = [0.0, 0.5]
            end
            if PSR in misfitmodules
                p["psr_trimp"] = [0.0, 2.0]
                p["psr_trims"] = [0.0, 3.0]
            end
        else
            if XCorr in misfitmodules
                p["xcorr_trim"] = [-2.0, 6.0] ./ p["xcorr_band"][2]
            end
            if Polarity in misfitmodules
                p["polarity_obs"] = NaN
            end
            if Polarity in misfitmodules
                p["polarity_trim"] = [NaN, NaN]
            end
            if PSR in misfitmodules
                p["psr_trimp"] = [NaN, NaN]
                p["psr_trims"] = [NaN, NaN]
            end
        end
        if XCorr in misfitmodules
            local dt = s["meta_dt"]
            tl = p["xcorr_trim"][2] - p["xcorr_trim"][1]
            while (dt + 1e-3) * 200 < tl
                dt += 1e-3
            end
            p["xcorr_dt"] = dt
        end
        if DTW in misfitmodules
            p["dtw_band"] = [1.0, 4]
            if p["type"] == "P"
                p["dtw_trim"] = [-4.0, 4.0] ./ p["dtw_band"][2]
            else
                p["dtw_trim"] = [-2.0, 6.0] ./ p["dtw_band"][2]
            end
            local dt = s["meta_dt"]
            tl = p["dtw_trim"][2] - p["dtw_trim"][1]
            while (dt + s["meta_dt"]) * 200 < tl
                dt += s["meta_dt"]
            end
            p["dtw_dt"] = dt
            p["dtw_klim"] = 20 * p["dtw_dt"]
            p["dtw_order"] = 4
            p["dtw_maxlag"] = 0.25 / p["dtw_band"][2]
        end
    end
end

env = Dict("algorithm" => algorithm,
        "event" => event,
        "stations" => stations,
        "dataroot" => dataroot)
JuliaSourceMechanism.calcgreen!(env)
JuliaSourceMechanism.loaddata!(env)
for s in env["stations"]
    ot = Millisecond(env["event"]["origintime"] - s["base_begintime"]).value * 1e-3
    (meta, _) = JuliaSourceMechanism.Green.scangreenfile(normpath(env["dataroot"],
                                                                "greenfun",
                                                                @sprintf("%s-%.4f", s["green_model"],
                                                                        env["algorithm"]["searchdepth"]),
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
status = Dict{String,Any}()
status["saveplotdata"] = true
status["saveplotdatato"] = abspath(".tmpplot.mat")

else # !isempty(ARGS)

(env, status) = let
    p1 = abspath(ARGS[1])
    p2 = abspath(pwd(), ARGS[1])
    if isfile(p1)
        t = load(p1)
    elseif isfile(p2)
        t = load(p2)
    else
        error("file not exist: "*ARGS[1])
    end
    (t["env"], t["status"])
end

end # isempty(ARGS)

SourceMechUI.Server.launchserver!(env, status)
