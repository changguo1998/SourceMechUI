
autoscale(x, y) =
    let
        rx = (maximum(x) - minimum(x)) / 2
        ry = (maximum(y) - minimum(y)) / 2
        cx = minimum(x) + rx
        cy = minimum(y) + ry
        (cx - rx * 1.2, cx + rx * 1.2, cy - ry * 1.2, cy + ry * 1.2)
    end

function plotstationscatter(env, status)
    tags = gettag.(env["stations"])
    lon1 = Float64[]
    lat1 = Float64[]
    tag1 = String[]
    lon2 = Float64[]
    lat2 = Float64[]
    tag2 = String[]
    for s in status["stationlist"]
        idx = findfirst(tags .== s)
        if s in status["stationlist_selected"]
            push!(lon1, env["stations"][idx]["meta_lon"])
            push!(lat1, env["stations"][idx]["meta_lat"])
            push!(tag1, s)
        else
            push!(lon2, env["stations"][idx]["meta_lon"])
            push!(lat2, env["stations"][idx]["meta_lat"])
            push!(tag2, s)
        end
    end
    if ("saveplotdata" in keys(status)) && ("saveplotdatato" in keys(status)) && status["saveplotdata"]
        matwrite(status["saveplotdatato"],
                 Dict("type" => "station", "lon1" => lon1, "lon2" => lon2,
                      "lat1" => lat1, "lat2" => lat2, "tag1" => tag1, "tag2" => tag2,
                      "elon" => env["event"]["longitude"], "elat" => env["event"]["latitude"]))
        return nothing
    end
    return nothing
end

function plotstation(env, status)
    if !("current_station" in keys(status))
        @warn "Station not specified."
        return nothing
    end
    idx = findall(gettag.(env["stations"]) .== status["current_station"])
    if isempty(idx)
        @warn "Station not specified."
        return nothing
    end
    stas = env["stations"][idx]
    bt = minimum(map(x -> x["base_begintime"], stas))
    if !("refmech" in keys(status))
        status["refmech"] = round.(rand(3) .* [360, 90, 180] - [0.0, 0.0, 90.0])
    end
    m = dc2ts(status["refmech"])
    ks = keys(status)
    flag_filter = all(x -> x in ks, ("filtwave", "filterorder", "filterband"))
    flag_filter = flag_filter ? flag_filter && status["filtwave"] : false
    flag_green = "green_fun" in keys(stas[1])
    amp = "waveamp" in keys(status) ? status["waveamp"] : 1.0
    tl = Vector{Float64}[]
    tg = Vector{Float64}[]
    ww = Vector{Float64}[]
    wg = Vector{Float64}[]
    sw = Float64[]
    sg = Float64[]
    etshift = Millisecond(round(stas[1]["base_begintime"]-env["event"]["origintime"], Millisecond)).value*1e-3
    for i = 1:3
        rbt = round(stas[i]["base_begintime"] - bt, Millisecond).value * 1e-3 .+ etshift
        w = deepcopy(stas[i]["base_record"])
        if flag_filter
            fltr = digitalfilter(Bandpass(status["filterband"][1], status["filterband"][2];
                                          fs=1 / stas[i]["meta_dt"]), Butterworth(status["filterorder"]))
            w = filtfilt(fltr, w)
        end
        t = (0.0:length(w)-1) .* stas[i]["meta_dt"] .+ rbt
        if stas[i]["component"] == "E"
            shift = 3.0
        elseif stas[i]["component"] == "N"
            shift = 2.0
        else
            shift = 1.0
        end
        w ./= maximum(abs, w) * 2 / amp
        w .+= shift
        push!(tl, t)
        push!(ww, w)
        if flag_green
            g = stas[i]["green_fun"] * m
            if flag_filter
                if status["filterband"][2] < 0.5 / stas[i]["green_dt"]
                    fltr = digitalfilter(Bandpass(status["filterband"][1], status["filterband"][2];
                                                  fs=1 / stas[i]["green_dt"]), Butterworth(status["filterorder"]))
                    g = filtfilt(fltr, g)
                else
                    @warn "filterband is not correct. max frequency: $(0.5/stas[i]["green_dt"])Hz"
                end
            end
            g ./= maximum(abs, g) * 2 / amp
            g .+= shift - 0.2
            push!(tg, (0:length(g)-1) .* stas[i]["green_dt"] .+ rbt)
            push!(wg, g)
            push!(sw, shift)
            push!(sg, shift - 0.2)
        end
    end
    maxt = maximum(vcat(tl..., tg...))
    if "xlim" in keys(status) && "xlimreset" in keys(status) && !status["xlimreset"]
        rgn = (status["xlim"][1], status["xlim"][2], 0.0, 4.0)
    else
        rgn = (0.0, maxt, 0.0, 4.0)
    end
    if ("saveplotdata" in keys(status)) && ("saveplotdatato" in keys(status)) && status["saveplotdata"]
        t = Dict{String,Any}[]
        for p in stas[1]["phases"]
            td = Dict{String,Any}()
            for k in keys(p)
                if k in ("tt", "type") || contains(k, "trim")
                    td[k] = p[k]
                end
            end
            td["at"] = round(p["at"] - bt, Millisecond).value * 1e-3
            push!(t, td)
        end
        matwrite(status["saveplotdatato"],
                 Dict("type" => "wave", "tl" => tl, "ww" => ww, "tg" => tg, "wg" => wg, "sw" => sw, "sg" => sg,
                      "bt" => Dates.format(bt, "yyyy-mm-ddTHH:MM:SS.sss"), "win" => t))
        return nothing
    end
    return nothing
end

function plotspec(env, status)
    if !("current_station" in keys(status))
        @warn "Station not specified."
        return nothing
    end
    idx = findall(gettag.(env["stations"]) .== status["current_station"])
    if isempty(idx)
        @warn "Station not specified."
        return nothing
    end
    stas = env["stations"][idx]
    fs = Vector{Float64}[]
    spec = Vector{Float64}[]
    for s in stas
        if s["component"] == "E"
            shift = 3.0
        elseif s["component"] == "N"
            shift = 2.0
        else
            shift = 1.0
        end
        w = deepcopy(s["base_record"])
        w ./= maximum(abs, w)
        w = complex(w)
        fft!(w)
        f = (1:length(w)) / length(w) / s["meta_dt"]
        idx = 1:round(Int, length(f) / 2)
        tspec = log10.(abs.(w[idx]))
        tspec .-= minimum(tspec)
        tspec ./= maximum(tspec)
        tspec .+= shift
        push!(fs, f[idx])
        push!(spec, tspec)
    end
    maxf = maximum(vcat(fs...))
    if ("saveplotdata" in keys(status)) && ("saveplotdatato" in keys(status)) && status["saveplotdata"]
        tbands = Matrix{Float64}(undef, 2, 0)
        tbands = Dict{String,Any}[]
        for p in stas[1]["phases"]
            for k in keys(p)
                if contains(k, "band")
                    push!(tbands, Dict{String,Any}("phase" => p["type"], "key" => k, "band" => p[k]))
                end
            end
        end
        matwrite(status["saveplotdatato"], Dict("type" => "spec", "fs" => fs, "spec" => spec, "band" => tbands))
        return nothing
    end
    return nothing
end

function cmd_plot(io::IO, env, status, cmd::Vector{String})
    if length(cmd) < 2
        _showhelp("plot")
    else
        t = lowercase(cmd[2])
        if t == "station"
            plotstationscatter(env, status)
        elseif t == "wave"
            plotstation(env, status)
        elseif t == "spec"
            plotspec(env, status)
        end
    end
    return nothing
end

_registeroption!("plot", [""], """
    Plot    station
                plot station scatter

            wave
                plot waveform and greenfun of current station

            spectrum
                plot frequency spectrum of current station""",
                 cmd_plot)
