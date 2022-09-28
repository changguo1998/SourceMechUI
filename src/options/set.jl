
function updatestationselection!(env::Setting, status::Dict{String,Any})
    if !("stationlist" in keys(status))
        slist = String[]
        for i = 1:length(env["stations"])
            tag = join([env["stations"][i]["network"], env["stations"][i]["station"]], '.')
            push!(slist, tag)
        end
        unique!(slist)
        sort!(slist)
        status["stationlist_selected"] = Set()
        status["stationlist"] = Set(slist)
    end
    return nothing
end

function parsesetconfig(env, status, cmd::Vector{String})
    if !("current_station" in keys(status)) || isempty(status["current_station"])
        @warn "station not specified"
        return Int[]
    end
    opts = ArgParser.newoptionlist()
    ArgParser.addopt!(opts, "component", "all", "c")
    (pars, args) = ArgParser.parse(cmd, opts)
    if pars["component"] == "all"
        idxs = findall(gettag.(env["stations"]) .== status["current_station"])
    else
        idxs = findall((gettag.(env["stations"]) .== status["current_station"]) .&
                       map(x -> x["component"] == pars["component"], env["stations"]))
    end
    if isempty(idxs)
        @error "Component $(pars["component"]) not exist"
    end
    return (idxs, args)
end

function setstatus!(env, status, cmd)
    if length(cmd) < 4
        help_set()
    else
        if cmd[3] == "current_station"
            status[cmd[3]] = cmd[4]
        elseif cmd[3] == "refmech"
            if length(cmd) < 6
                @warn "parameter not enough"
            else
                status["refmech"] = parse.(Float64, cmd[4:6])
            end
        elseif cmd[3] == "select"
            if cmd[4] in status["stationlist"]
                if length(cmd) < 5
                    t = !(cmd[4] in status["stationlist_selected"])
                else
                    t = parse(Bool, cmd[5])
                end
                if t
                    push!(status["stationlist_selected"], cmd[4])
                else
                    pop!(status["stationlist_selected"], cmd[4])
                end
            else
                @warn "station $(cmd[4]) not exist"
            end
        elseif cmd[3] == "filterorder"
            status["filterorder"] = parse(Int, cmd[4])
        elseif cmd[3] == "filtwave"
            status["filtwave"] = parse(Bool, lowercase(cmd[4]))
        elseif cmd[3] == "filterband"
            if length(cmd) < 5
                @warn "bandpass filter need 2 corner frequency"
            else
                status["filterband"] = parse.(Float64, cmd[4:5])
            end
        elseif cmd[3] == "xlimreset"
            status["xlimreset"] = parse(Bool, lowercase(cmd[4]))
        elseif cmd[3] == "xlim"
            if length(cmd) < 5
                @warn "bandpass filter need 2 corner frequency"
            else
                status["xlim"] = parse.(Float64, cmd[4:5])
            end
        elseif cmd[3] == "statusformat"
            status["statusformat"] = cmd[4]
        elseif cmd[3] == "waveamp"
            status["waveamp"] = parse(Float64, cmd[4])
        else
            @warn "key $key illegal."
        end
    end
    status["fresh"] = false
    printstatus(env, status, cmd)
    return nothing
end

function setalgorithm!(env, status, cmd)
    if length(cmd) < 4
        @warn "value not exist."
        return nothing
    end
    if cmd[3] == "searchdepth"
        env["algorithm"]["searchdepth"] = parse(Float64, cmd[4])
    elseif cmd[3] == "weight"
        env["algorithm"]["weight"] = parse.(Float64, cmd[4:end])
    elseif cmd[3] == "misfit"
        env["algorithm"]["misfit"] = String.(cmd[4:end])
    else
        @warn "key: $(cmd[3]) illegal"
    end
    if cmd[3] == "searchdepth"
        status["fresh"] = true
    end
    return nothing
end

function setevent!(env, status, cmd)
    if length(cmd) < 4
        @warn "value not exist."
        return nothing
    end
    if cmd[3] in ("depth", "latitude", "longitude", "magnitude")
        env["event"][cmd[3]] = parse(Float64, cmd[4])
    elseif cmd[3] == "origintime"
        env["event"]["origintime"] = DateTime(cmd[4], "y-m-dTH:M:S.s")
    else
        @warn "key: $(cmd[3]) illegal"
    end
    if cmd[3] in ("depth", "latitude", "longitude", "origintime")
        status["fresh"] = true
    end
    return nothing
end

function setstation!(env, status, cmd)
    (idxs, args) = parsesetconfig(env, status, cmd)
    if length(args) < 4
        @warn "value not exist."
        return nothing
    end
    if !("current_station" in keys(status)) || isempty(status["current_station"])
        @warn "station not specified"
        return nothing
    end
    # idxs = findall(gettag.(env["stations"]) .== status["current_station"])
    if args[3] in ("base_azimuth", "base_distance", "green_dt", "green_xl")
        t = parse(Float64, args[4])
        for i in idxs
            env["stations"][i][args[3]] = t
        end
    elseif args[3] in ("green_tsource",)
        t = parse(Float64, args[4])
        for s in env["stations"]
            s[args[3]] = t
        end
    elseif args[3] == "green_m"
        t = parse(Int, args[4])
        for i in idxs
            env["stations"][i][args[3]] = t
        end
    elseif args[3] == "base_trim"
        t = DateTime.(args[4:5])
        for i in idxs
            env["stations"][i][args[3]] = t
        end
    elseif args[3] == "green_model"
        for i in idxs
            env["stations"][i][args[3]] = args[4]
        end
    end
    status["fresh"] = true
    return nothing
end

function setphase!(env, status, cmd)
    (idxs, args) = parsesetconfig(env, status, cmd)
    if !("current_station" in keys(status)) || isempty(status["current_station"])
        @warn "station not specified"
        return nothing
    end
    # idxs = findall(gettag.(env["stations"]) .== status["current_station"])
    if length(args) == 4
        if args[3] == "type"
            if !(args[4] in map(x -> x["type"], env["stations"][idxs[1]]["phases"]))
                for i in idxs
                    push!(env["stations"][i]["phases"], Dict{String,Any}("type" => args[4]))
                end
            end
            status["fresh"] = true
            return nothing
        end
    end
    if length(args) < 5
        @warn "value not exist."
        return nothing
    end
    pidx = findfirst(x -> x["type"] == args[3], env["stations"][1]["phases"])
    if isnothing(pidx)
        @warn "phase: $(args[3]) not exist. use: set phase type typename to add new phase"
        return nothing
    end
    if args[4] in ("tt", "dtw_dt", "dtw_klim", "dtw_maxlag", "xcorr_dt", "xcorr_maxlag")
        t = parse(Float64, args[5])
        for i in idxs
            pidx = findfirst(x -> x["type"] == args[3], env["stations"][i]["phases"])
            env["stations"][i]["phases"][pidx][args[4]] = t
        end
    elseif args[4] == "at"
        t = DateTime(args[5], "y-m-dTH:M:S.s")
        for i in idxs
            pidx = findfirst(x -> x["type"] == args[3], env["stations"][i]["phases"])
            env["stations"][i]["phases"][pidx][args[4]] = t
        end
    elseif args[4] in ("dtw_order", "xcorr_order")
        t = parse(Int, args[5])
        for i in idxs
            pidx = findfirst(x -> x["type"] == args[3], env["stations"][i]["phases"])
            env["stations"][i]["phases"][pidx][args[4]] = t
        end
    elseif args[4] == "polarity_obs"
        t = parse(Float64, args[5])
        t = sign(t)
        for i in idxs
            pidx = findfirst(x -> x["type"] == args[3], env["stations"][i]["phases"])
            env["stations"][i]["phases"][pidx][args[4]] = t
        end
    elseif args[4] in ("dtw_band", "dtw_trim", "polarity_trim", "psr_trimp", "psr_trims", "xcorr_band", "xcorr_trim")
        if length(args) < 6
            @warn "need two float"
            return nothing
        else
            t = parse.(Float64, args[5:6])
            for i in idxs
                pidx = findfirst(x -> x["type"] == args[3], env["stations"][i]["phases"])
                env["stations"][i]["phases"][pidx][args[4]] = t
            end
        end
    end
    return nothing
end

function cmd_set(io::IO, env, status, cmd::Vector{String})
    if length(cmd) < 2
        _showhelp("set")
        return nothing
    end
    t = lowercase(cmd[2])
    if t == "status"
        setstatus!(env, status, cmd)
    elseif t == "algorithm"
        setalgorithm!(env, status, cmd)
    elseif t == "event"
        setevent!(env, status, cmd)
    elseif t == "station"
        setstation!(env, status, cmd)
    elseif t == "phase"
        setphase!(env, status, cmd)
    else
        @warn "key $t not exist"
    end
    if status["fresh"]
        JuliaSourceMechanism.loaddata!(env)
    end
    status["fresh"] = false
    return nothing
end

_registeroption!("set", [""], """
    Set status
            current_station String
            refmech         [Float, Float, Float]
            filtwave        Bool
            filterorder     Int
            filterband      [Float, Float]
            xlim            [Float, Float]
            xlimreset       Bool
            select stationname [Bool]
            statusformat    String
            waveamp         Float

        algorithm
        event
        station
        phase""", cmd_set)
