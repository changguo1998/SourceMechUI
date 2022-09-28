module CLI

using Dates, DelimitedFiles, DSP, FFTW, JLD2, MAT, Printf, Statistics, TOML, SeisTools, JuliaSourceMechanism

include("ArgParser.jl")

include("utils.jl")

for f in readdir(joinpath(@__DIR__, "options"))
    include(joinpath(@__DIR__, "options", f))
end
#=
function fresh!(env::Setting, misfitmodules::Vector{Module}; warn::Bool=false)
    t = checkconfiguration(devnull, env, misfitmodules)
    if !isempty(t)
        @error "Something wrong while checking. See $(abspath(normpath(pwd(), "check.log"))) for more detail."
        open("check.log", "w") do io
            print(io, t)
        end
        return nothing
    end
    for s in env["stations"]
        (dist, az, _) = SeisTools.Geodesy.distance(env["event"]["latitude"], env["event"]["longitude"], s["meta_lat"],
                                                   s["meta_lon"])
        s["base_distance"] = dist
        s["base_azimuth"] = az
    end

    @info "Green function"
    if !("dataroot" ∈ keys(env))
        @warn "dataroot not specified"
        return nothing
    end
    # Threads.@threads
    for s in collect(filter(x -> x["component"] == "Z", env["stations"]))
        Green.calculategreenfun(s, env)
    end

    for s in env["stations"]
        # t = Seis.readsac(normpath(env["dataroot"], "sac", s["meta_file"]))
        t = SeisTools.SAC.read(normpath(env["dataroot"], "sac", s["meta_file"]))
        # if s["base_trim"][1] < s["meta_btime"]
        #     trim_bt = s["meta_btime"]
        #     if warn
        #         printstyled("Begin time: ", s["base_trim"][1],
        #                     " of $(s["network"]).$(s["station"]).$(s["component"]) is too early, set to: ", trim_bt,
        #                     "\n"; color = :yellow)
        #     end
        # else
        trim_bt = s["base_trim"][1]
        # end
        # if s["base_trim"][2] > s["meta_btime"] + Millisecond(round(Int, t.head["npts"] * t.head["delta"] * 1e3))
        #     trim_et = s["meta_btime"] + Millisecond(round(Int, t.head["npts"] * t.head["delta"] * 1e3))
        #     if warn
        #         printstyled("End time: ", s["base_trim"][2],
        #                     " of $(s["network"]).$(s["station"]).$(s["component"]) is too late, set to: ", trim_et,
        #                     "\n"; color = :yellow)
        #     end
        # else
        trim_et = s["base_trim"][2]
        # end
        # t = trim(t, trim_bt, trim_et)
        (sbt, tw, _) = SeisTools.DataProcess.cut(t.data, SeisTools.SAC.DateTime(t.hdr), trim_bt, trim_et,
                                                 Millisecond(round(Int, t.hdr["delta"] * 1000)))
        s["base_begintime"] = sbt
        s["base_record"] = tw
        Green.load!(s, env)
        detrendandtaper!(s["base_record"])
        detrendandtaper!(s["green_fun"])
    end
    return nothing
end

function extractabbr(cmd::Vector{String})
    if cmd == ["p"]
        return ["plot", "wave"]
    elseif cmd[1] == "csta" && length(cmd) >= 2
        return ["set", "status", "current_station", cmd[2]]
    elseif cmd == ["status"]
        return ["print", "status"]
    elseif cmd[1] == "xlim"
        return [["set", "status"]; cmd]
    elseif lowercase(cmd[1]) == "p" && length(cmd) > 1
        return ["plot"; cmd[2:end]]
    elseif lowercase(cmd[1]) == "i"
        t = deepcopy(cmd)
        t[1] = "print"
        return t
    elseif lowercase(cmd[1]) == "s"
        t = deepcopy(cmd)
        t[1] = "set"
        return t
    elseif lowercase(cmd[1]) == "r"
        t = deepcopy(cmd)
        t[1] = "run"
        return t
    else
        return cmd
    end
end

=#
_split(s) = split(s; keepempty=false)

function _repl!(ioin::IO, ioout::IO, env::Setting, status::Dict)
    while true
        s = readline(ioin)
        cmd = s |> strip |> _split .|> String
        println(join(cmd, ' '))
        if interpret!(ioout, env, status, cmd)
            continue
        else
            break
        end
    end
    return nothing
end

function repl!(env, status)
    _repl!(stdin, stdout, env, status)
end
end
