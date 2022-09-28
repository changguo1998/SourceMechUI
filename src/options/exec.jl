# function cmd_run(io::IO, env, status, cmd::Vector{String})
# end

# function help_run()
#     println("""
#     Run cmd
#         run julia command""")
#     return nothing
# end

# function help_shell()
#     println("""
#     shell cmd
#         run command in shell env""")
#     return nothing
# end

function cmd_shell(io::IO, env, status, cmd::Vector{String})
    if length(cmd) > 1
        print(io, run(Cmd(cmd[2:end])))
    end
    return nothing
end

_registeroption!("shell", [""], """
shell cmd
    run command in shell env""", cmd_shell)

function cmd_help(io::IO, env, status, cmd::Vector{String})
    if length(cmd) > 1
        _showhelp(cmd[2:end])
    end
end

_registeroption!("help", [""], """
help cmd
    print help of module""", cmd_help)

function cmd_tmpfile(io::IO, env, status, cmd::Vector{String})
    println(io, abspath(status["saveplotdatato"]))
    return nothing
end

_registeroption!("tmpfile", [""], """
tmpfile
    return absolute path to plot buffer file""", cmd_tmpfile)

function cmd_gettmp(io::IO, env, status, cmd::Vector{String})
    if (io == stdin) || (io == stdout)
        return nothing
    end
    nf = filesize(status["saveplotdatato"])
    print(io, @sprintf("%d\0", Int(nf)))
    open(status["saveplotdatato"]) do tmpio
        for _ = 1:nf
            write(io, read(tmpio, UInt8))
        end
    end
    return nothing
end
