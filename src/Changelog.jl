"""
    Changelog

Julia package for managing changelogs. See
https://github.com/JuliaDocs/Changelog.jl/blob/master/README.md for
documentation.
"""
module Changelog

VERSION >= v"1.11.0-DEV.469" && eval(Meta.parse("public generate"))

# generate Documenter changelogs and links
include("generate.jl")

end # module
