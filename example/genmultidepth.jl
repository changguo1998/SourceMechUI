using JuliaSourceMechanism, JLD2, LinearAlgebra, Printf

(env, status) = let
    t = load(joinpath(@__DIR__, "..", "data.jld2"))
    (t["env"], t["status"])
end

for dep = 0.0:0.5:5.0
    env["algorithm"]["searchdepth"] = dep
    jldsave(@sprintf("../data%gkm.jld2", dep), env=env, status=status)
end
