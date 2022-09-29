module SourceMechUI

include("CLI.jl")
include("Server.jl")

function initevent(path::AbstractString)
    if isdir(path)
        for f in ("UIServer.jl", "inverse.jl", "plot.jl", "showresult.jl")
            cp(joinpath(@__DIR__, "../example/", f), joinpath(path, f))
        end
    end
    return nothing
end

end
