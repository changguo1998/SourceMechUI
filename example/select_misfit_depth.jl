using JLD2, Printf

function loadmisfit(path::AbstractString)
    t = JLD2.load(path)
    return (t["result"]["info_mech"], t["result"]["info_misfit"], 
        t["result"]["info_misfit_xcorr"], t["result"]["info_misfit_pol"])
end

fs = filter(v->startswith(v, "data") && endswith(v, "km_result.jld2"), readdir())
dep = map(fs) do f
    parse(Float64, replace(replace(f, "data"=>""), "km_result.jld2"=>""))
end
res = loadmisfit.(fs)
mis = getindex.(res, 2)

open("mechvsdepth.txt", "w") do io
    for i = eachindex(res)
        @printf(io, "%g %g %g %g %g %g 5\n", dep[i], mis[i], 0.0, res[i][1][1], 
            res[i][1][2], res[i][1][3])
    end
end

mind = minimum(dep)-0.5
maxd = maximum(dep)+0.5
dm = 10.0^floor(Int, log10(maximum(mis) - minimum(mis)))
minm = floor(minimum(mis)/dm)*dm
maxm = ceil(maximum(mis)/dm)*dm

open("plotmechvsdep.sh", "w") do io
    println(io, """
gmt begin depth_vs_mech png
    gmt basemap -JX16c/12c -R$mind/$maxd/$minm/$maxm -Bxa0.5+l"Depth(km)" -Bya$dm+l"misfit" -BWSen
    gmt meca -Sa0.5c < mechvsdepth.txt
gmt end
""")
end

run(`bash plotmechvsdep.sh`)