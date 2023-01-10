fs = filter(v->startswith(v, "data") && endswith(v, "km.jld2"), readdir(".."))

Threads.@threads for f in fs
    run(Cmd(["julia", "inverse.jl", String(f[1:end-5])]))
end
