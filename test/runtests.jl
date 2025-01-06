using Changelog, Test
using Changelog: parse_version_header, parsefile
using Dates


test_path(filename) = joinpath(pkgdir(Changelog), "test", "test_changelogs", filename)

include("generate.jl")
include("parse_changelog.jl")
include("SimpleLog.jl")

