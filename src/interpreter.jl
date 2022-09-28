#=
function interpret!(inio::IO, env::Setting, status; misfits::Vector{Module}=Module[])
    if inio == stdin
        printstyled("IAT> "; color=:green)
    end
    l = String.(split(strip(readline(inio)); keepempty=false))
    if inio != stdin
        println("Command: ", join(l, ' '))
    end
    if isempty(l)
        return false
    end
    l = extractabbr(l)
    cmd = lowercase(l[1])
    if cmd in ("quit", "q", "exit")
        if inio != stdin
            print(inio, '\0')
        end
        return true
    elseif cmd == "print"
        func = cmd_print(l)
        func(env, status, l)
    elseif cmd == "plot"
        func = cmd_plot(l)
        func(env, status)
    elseif cmd == "set"
        func! = cmd_set(l)
        func!(env, status, l)
        if status["fresh"]
            fresh!(env, misfits)
        end
        status["fresh"] = false
    elseif cmd == "run"
        eval(Meta.parse(join(l[2:end], ' ')))
    elseif cmd == "shell"
        run(Cmd(l[2:end]); wait=false)
    elseif cmd == "save"
        outputconfig(env, status, l)
    elseif cmd == "help"
        cmd_help(l)
    elseif cmd == "tmpfile"
        if inio != stdin
            print(inio, abspath(status["saveplotdatato"]))
        end
    elseif cmd == "gettmp"
        if inio != stdin
            nf = filesize(status["saveplotdatato"])
            print(inio, @sprintf("%d\0", Int(nf)))
            open(status["saveplotdatato"]) do tmpio
                for _ = 1:nf
                    write(inio, read(tmpio, UInt8))
                end
            end
        else
            @warn "can't export to terminal"
            return false
        end
    else
        @warn "command: $cmd not exist"
    end
    println("<")
    if inio != stdin
        print(inio, '\0')
    end
    return false
end
=#
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

function interpret!(io::IO, env, status, cmd::Vector{String})
    global _OPTIONS
    if cmd[1] in ("quit", "exit", "q")
        return false
    end
    # replace abbrevation
    for k in keys(_OPTIONS)
        if cmd[1] == k
            break
        elseif cmd[1] in _OPTIONS[k].abbr
            cmd[1] = k
        end
    end
    cmd = extractabbr(cmd)
    try
        # call modules
        if cmd[1] in keys(_OPTIONS)
            func = _OPTIONS[cmd[1]]
            func(io, env, status, cmd)
        else
            @warn "command $(cmd[1]) not exist"
        end
    catch err
        println(err)
    finally
        return true
    end
end
