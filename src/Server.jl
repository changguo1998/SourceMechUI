module Server
using Sockets
import ..CLI._repl!

SERVER_SETTING = Dict{String,Any}()

SERVER_SETTING["listenIP"] = IPv4(0)
SERVER_SETTING["listenPort"] = 12345

function set!(; ip::Union{IPAddr,Nothing}=nothing, port::Integer=-1)
    global SERVER_SETTING
    if !isnothing(ip)
        SERVER_SETTING["listenIP"] = ip
    end
    if port > 0
        SERVER_SETTING["listenPort"] = port
    end
end

function launchserver!(env, status; ip::Union{IPAddr,Nothing}=nothing, port::Integer=-1)
    set!(; ip=ip, port=port)
    svr = listen(SERVER_SETTING["listenIP"], SERVER_SETTING["listenPort"])
    @info "Listening $(SERVER_SETTING["listenIP"]):$(SERVER_SETTING["listenPort"])\nwaiting for connection..."
    sock = accept(svr)
    @info "Connection established"
    _repl!(sock, sock, env, status)
end
end
