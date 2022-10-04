_OPTIONS = Dict{String,Any}()

"""
```
_registeroption!(optname::String, helpdoc::String, entrance::Function)
```
"""
function _registeroption!(optname::String, abbrs::Vector{String}, helpdoc::String, entrance::Function)
    global _OPTIONS
    if optname in keys(_OPTIONS)
        error("Option " * optname * " already exist")
    end
    _OPTIONS[optname] = (f=entrance, abbr=abbrs, doc=helpdoc)
    return nothing
end

"""
```
_showhelp(optname::Vector{String})
```
"""
function _showhelp(optname::Vector{String})
    global _OPTIONS
    for o in optname
        println(_OPTIONS[o].doc)
    end
    return nothing
end

_showhelp(o::String) = _showhelp(String[o])

returnnone(x...) = nothing

gettag(x::Dict) = x["network"] * "." * x["station"]

const _DEBUG_ = true

macro debuginfo(ex)
    return quote
        if _DEBUG_
            printstyled("Debug info: ", color=:light_blue)
            println($(esc(ex)))
        end
    end
end
