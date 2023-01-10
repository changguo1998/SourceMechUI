using JuliaSourceMechanism, JLD2, LinearAlgebra, Printf, CairoMakie, SeisTools

function linearscale(v::AbstractArray; ylim::AbstractVector=[-0.5, 0.5], A::Union{Real,Nothing}=nothing)
    if isnothing(A)
        A = maximum(abs, v)
    end
    y = @. (v + A) / 2 / A * (ylim[2] - ylim[1]) + ylim[1]
    return (y, A)
end

function plansubplot(xmin::Real, xmax::Real, ymin::Real, ymax::Real,
    tmin::AbstractMatrix, tmax::AbstractMatrix; xmargin::Float64=0.05, ymargin::Float64=0.01)
    trange = tmax - tmin
    tlen = maximum(trange, dims=1) |> x -> reshape(x, length(x))
    xperct = (xmax - xmin - (length(tlen) - 1) * xmargin) .* tlen ./ sum(tlen)
    yperct = (ymax - ymin - (size(tmin, 1) - 1) * ymargin) .* ones(size(tmin, 1)) ./ size(tmin, 1)
    xrange = zeros(size(tmin, 2), 2)
    yrange = zeros(size(tmin, 1), 2)
    for i = axes(tmin, 2)
        xrange[i, 2] = xmin + sum(xperct[1:i]) + (i - 1) * xmargin
        xrange[i, 1] = xrange[i, 2] - xperct[i]
    end
    for i = axes(tmin, 1)
        yrange[i, 2] = ymin + sum(yperct[1:i]) + (i - 1) * ymargin
        yrange[i, 1] = yrange[i, 2] - yperct[i]
    end
    return (xrange, reverse(yrange, dims=1), xperct[1] / tlen[1])
end

hideaxis = (xlabelvisible=false,
    xgridvisible=false,
    xticklabelsvisible=false,
    xticksvisible=false,
    ylabelvisible=false,
    ygridvisible=false,
    yticklabelsvisible=false,
    yticksvisible=false,
    leftspinevisible=false,
    rightspinevisible=false,
    topspinevisible=false,
    bottomspinevisible=false)

if !@isdefined result
    fname = ARGS[1]
    result = let
        t = JLD2.load(joinpath(@__DIR__, fname))
        t["result"]
    end
    (env, status) = let
        t = load(joinpath(@__DIR__, "..", replace(fname, "_result.jld2" => ".jld2")))
        (t["env"], t["status"])
    end
end

stationnames = filter(!startswith("info_"), collect(keys(result)))
dists = map(x -> result[x]["dist"], stationnames)
distperm = sortperm(dists)
nstation = length(stationnames)
WIDTH = 16
HEIGHT = nstation * WIDTH / 6 * 0.4 + 2

tmin = zeros(nstation, 6)
tmax = zeros(nstation, 6)
for i = 1:nstation
    s = stationnames[i]
    p = result[s]["E"]["P"]
    tmin[i, 1] = min(0.0, p["xcorr_shift"])
    tmax[i, 1] = max(0.0, p["xcorr_shift"]) + length(p["xcorr_rec"]) * p["xcorr_dt"]
    p = result[s]["N"]["P"]
    tmin[i, 2] = min(0.0, p["xcorr_shift"])
    tmax[i, 2] = max(0.0, p["xcorr_shift"]) + length(p["xcorr_rec"]) * p["xcorr_dt"]
    p = result[s]["Z"]["P"]
    tmin[i, 3] = min(0.0, p["xcorr_shift"])
    tmax[i, 3] = max(0.0, p["xcorr_shift"]) + length(p["xcorr_rec"]) * p["xcorr_dt"]
    p = result[s]["E"]["S"]
    tmin[i, 4] = min(0.0, p["xcorr_shift"])
    tmax[i, 4] = max(0.0, p["xcorr_shift"]) + length(p["xcorr_rec"]) * p["xcorr_dt"]
    p = result[s]["N"]["S"]
    tmin[i, 5] = min(0.0, p["xcorr_shift"])
    tmax[i, 5] = max(0.0, p["xcorr_shift"]) + length(p["xcorr_rec"]) * p["xcorr_dt"]
    p = result[s]["Z"]["S"]
    tmin[i, 6] = min(0.0, p["xcorr_shift"])
    tmax[i, 6] = max(0.0, p["xcorr_shift"]) + length(p["xcorr_rec"]) * p["xcorr_dt"]
end

(xframe, yframe, kx) = plansubplot(0.12, 0.98, 0.0, 1.0, tmin, tmax; xmargin=0.01, ymargin=0.01)

fig = Figure(; resolution=round.(Int, (WIDTH, HEIGHT) .* 100))
ax1 = Axis(fig[1, 1];
    title=@sprintf("%d/%d/%d",
        round(Int, result["info_mech"][1]),
        round(Int, result["info_mech"][2]),
        round(Int, result["info_mech"][3])),
    aspect=1,
    hideaxis...)
ax2 = Axis(fig[1, 2], aspect=cosd(env["event"]["latitude"]))
ax3 = Axis(fig[2, 1:2]; hideaxis...)

lons = Float64[]
lats = Float64[]
tags = String[]
useAA = true

for n = 1:nstation
    i = distperm[n]
    s = stationnames[i]
    ista = findfirst(t -> t["network"] * "." * t["station"] == s, env["stations"])
    push!(lons, env["stations"][ista]["meta_lon"])
    push!(lats, env["stations"][ista]["meta_lat"])
    push!(tags, s)
    hl = (yframe[n, 1] + yframe[n, 2]) / 2
    text!(ax3, 0.1, hl; text=@sprintf("%.1fkm\n%s\n%.0f", env["stations"][ista]["base_distance"],
        stationnames[i], env["stations"][ista]["base_azimuth"]), align=(:right, :center))
    for j = 1:6
        p = (j > 3) ? "S" : "P"
        if mod(j - 1, 3) == 0
            c = "E"
        elseif mod(j - 1, 3) == 1
            c = "N"
        else
            c = "Z"
        end
        dt = result[s][c][p]["xcorr_dt"]
        sh = result[s][c][p]["xcorr_shift"]
        nsp = round(Int, sh / dt)
        t = range(0.0, length = length(result[s][c][p]["xcorr_rec"]), step = dt)
        (tr, A) = linearscale(result[s][c][p]["xcorr_rec"]; ylim=yframe[n, :])
        lines!(ax3, (t .- min(0.0, sh)) .* kx .+ xframe[j, 1], tr; color=:black)
        if useAA
            (tr, _) = linearscale(result[s][c][p]["xcorr_syn"]; ylim=yframe[n, :], A=A)
        else
            (tr, _) = linearscale(result[s][c][p]["xcorr_syn"]; ylim=yframe[n, :])
        end
        lines!(ax3, (t .+ max(0.0, sh)) .* kx .+ xframe[j, 1], tr; color=:red)
        text!(ax3, xframe[j, 1], yframe[n, 1]; text=@sprintf("%.2fs", sh))
        if (j <= 3) && (!iszero(result[s][c][p]["polarity_rec"]))
            pol_obs = (result[s][c][p]["polarity_rec"] > 0) ? "+" : "-"
            pol_syn = (result[s][c][p]["polarity_syn"] > 0) ? "+" : "-"
            text!(ax3, xframe[j, 1], yframe[n, 2]; text=pol_obs*"/"*pol_syn, align=(:left, :top))
        end
        if (n == nstation) && (c == "E")
            wlen = length(result[s][c][p]["xcorr_rec"]) * result[s][c][p]["xcorr_dt"]
            basepow = 10^floor(log10(wlen))
            rulerlen = floor(wlen / basepow) * basepow
            kruler = rulerlen * kx
            lines!(ax3, [xframe[j, 1], xframe[j, 1] + kruler], [1.0, 1.0].*yframe[n, 1]; color=:black)
            lines!(ax3, [1.0, 1.0].*xframe[j, 1], [0.0, -0.1].*(yframe[n, 2]-yframe[n, 1]).+yframe[n, 1]; color=:black)
            lines!(ax3, [1.0, 1.0].*(xframe[j, 1] + kruler), 
                [0.0, -0.1].*(yframe[n, 2]-yframe[n, 1]).+yframe[n, 1]; color=:black)
            text!(ax3, xframe[j, 1] + kruler / 2, yframe[n, 1]; text = @sprintf("%gs", rulerlen),
                align=(:center, :top))
        end
    end
end
text!(ax3, (xframe[:, 1] .+ xframe[:, 2]) ./ 2, ones(6); 
    text = ["PE", "PN", "PZ", "SE", "SN", "SZ"], align=(:center, :baseline))


scatter!(ax2, lons, lats, marker=:utriangle, color=:blue, markersize=25)
scatter!(ax2, [env["event"]["longitude"]], [env["event"]["latitude"]], marker=:star5, color=:red, markersize=36)
text!(ax2, lons, lats; text=tags, align=(:center, :top))

mt = SeisTools.Source.MomentTensor(result["info_mech"][1], result["info_mech"][2], result["info_mech"][3])
heatmap!(ax1,
    range(; start=-1.0, stop=1.0, length=1001),
    range(; start=-1.0, stop=1.0, length=1001),
    SeisTools.Source.beachball_bitmap(mt; resolution=(1001, 1001)) |>
    permutedims .|>
    sign;
    colormap=:binary)
l = SeisTools.Source.beachball_sdrline(mt)
lines!(ax1, map(x -> (x[2], x[1]), l.l1); color=:black, width=2)
lines!(ax1, map(x -> (x[2], x[1]), l.l2); color=:black, width=2)
lines!(ax1, map(x -> (x[2], x[1]), l.edge); color=:black, width=2)
rowsize!(fig.layout, 1, Fixed(round(Int, WIDTH * 30)))
save(replace(fname, ".jld2" => ".png"), fig; px_per_unit=4)
