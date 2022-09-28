
function shortstring(x)
    t = string(x)
    return length(t) > 80 ? t[1:38] * "..." * t[end-37:end] : t
end

function printstatus(env, status)
    println("\nCurrent status:\n")
    ks = Set(keys(status))
    pop!(ks, "stationlist")
    pop!(ks, "stationlist_selected")
    ks = sort(collect(ks))
    if isempty(ks)
        ml = 8
    else
        ml = maximum(length, ks)
        ml = (floor(Int, ml / 4) + 1) * 4
        for k in ks
            println("    ", " "^(ml - length(k) - 1), k, ": ", shortstring(status[k]))
        end
    end
    println("    ", " "^(ml - 8), "station:")
    if "statusformat" in keys(status) && status["statusformat"] == "long"
        staname = String[]
        dist = Float64[]
        for s in collect(status["stationlist"])
            push!(staname, s)
            id = findfirst(gettag.(env["stations"]) .== s)
            push!(dist, env["stations"][id]["base_distance"])
        end
        for i in sortperm(dist)
            s = staname[i]
            if s in status["stationlist_selected"]
                tcolor = :green
            else
                tcolor = :red
            end
            if "current_station" in keys(status) && s == status["current_station"]
                printstyled(" "^(5 + ml), "*")
                printstyled(@sprintf("%s %.2fkm", s, dist[i]), "\n"; color=tcolor)
            else
                printstyled(" "^(6 + ml), @sprintf("%s %.2fkm", s, dist[i]), "\n"; color=tcolor)
            end
        end
    else
        for s in collect(status["stationlist"])
            if s in status["stationlist_selected"]
                tcolor = :green
            else
                tcolor = :red
            end
            if "current_station" in keys(status) && s == status["current_station"]
                print(" *")
                printstyled(s; color=tcolor)
            else
                printstyled(" ", s; color=tcolor)
            end
        end
        println("")
    end
    return nothing
end

function printevent(env, status, cmd)
    println("Event Info:\n")
    ks = keys(env["event"]) |> Set |> collect |> sort
    if !isempty(ks)
        ml = maximum(length, ks)
        ml = (floor(Int, ml / 4) + 1) * 4
        for k in ks
            println("    ", " "^(ml - length(k) - 1), k, ": ", shortstring(env["event"][k]))
        end
    end
    return nothing
end

function printalgorithm(env, status, cmd)
    println("Algorithm Status:\n")
    ks = keys(env["algorithm"]) |> Set |> collect |> sort
    if isempty(ks)
        ml = 8
    else
        ml = maximum(length, ks)
        ml = (floor(Int, ml / 4) + 1) * 4
        for k in ks
            println("    ", " "^(ml - length(k) - 1), k, ": ", shortstring(env["algorithm"][k]))
        end
    end
    return nothing
end

function printstationinfo(env, status, cmd)
    if "current_station" in keys(status) && !isempty(status["current_station"])
        # idxs = findfirst(gettag.(env["stations"]) .== status["current_station"])
        (idxs, args) = parsesetconfig(env, status, cmd)
        s = env["stations"][idxs[1]]
        println("Station: ", gettag(s))
        ks = sort(collect(keys(s)))
        ml = maximum(length, ks)
        ml = (floor(Int, ml / 4) + 1) * 4
        for k in ("station", "network", "component")
            println("    ", " "^(ml - length(k) - 1), k, ": ", shortstring(s[k]))
        end
        for k in ks
            if k in ("phases", "station", "network", "component")
                continue
            end
            println("    ", " "^(ml - length(k) - 1), k, ": ", shortstring(s[k]))
        end
        println("    phases:")
        for p in s["phases"]
            pks = keys(p) |> collect |> sort
            pml = maximum(length, pks)
            pml = (floor(Int, pml / 4) + 1) * 4
            println(" "^8, " "^(pml - 5), "type: ", p["type"])
            println(" "^8, " "^(pml - 3), "at: ", p["at"])
            println(" "^8, " "^(pml - 3), "tt: ", p["tt"])
            for pk in pks
                if pk in ("type", "at", "tt")
                    continue
                end
                println(" "^8, " "^(pml - length(pk) - 1), pk, ": ", shortstring(p[pk]))
            end
            println("")
        end
    else
        @warn "Station not specified"
    end
    return nothing
end

function cmd_print(io::IO, env, status, cmd::Vector{String})
    if length(cmd) < 2
        help_print()
        return returnnone
    end
    t = lowercase(cmd[2])
    if t == "status"
        return printstatus
    elseif t == "station"
        return printstationinfo
    elseif t == "event"
        return printevent
    elseif t == "algorithm"
        return printalgorithm
    end
    return returnnone
end

_registeroption!("print", [""], """
    print   status
                print current status

            station
                print infomation of current station""", cmd_print)
