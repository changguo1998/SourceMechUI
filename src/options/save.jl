
function outputconfig(env, status, cmd)
    # t = Dict("algorithm" => env["algorithm"], "event" => env["event"], "stations" => env["stations"])
    if length(cmd) <= 1
        tpath = normpath(env["dataroot"], "conf.jld2")
    else
        tpath = normpath(env["dataroot"], cmd[2])
        if isdir(tpath)
            tpath = normpath(tpath, "conf.jld2")
        end
    end
    jldsave(tpath; env=env, status=status)
    return nothing
end

function cmd_save(io::IO, env, status, cmd::Vector{String})
    outputconfig(env, status, cmd)
end

_registeroption!("save", [""], """
    save path   save configuration to specified path""", cmd_save)
