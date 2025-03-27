"""
    Changelog

Julia package for managing changelogs. See
https://github.com/JuliaDocs/Changelog.jl/blob/master/README.md for
documentation.
"""
module Changelog

using MarkdownAST
using Dates
using AbstractTrees
import CommonMark as CM

VERSION >= v"1.11.0-DEV.469" && eval(Meta.parse("public parsefile, VersionInfo, SimpleChangelog, generate, tryparsefile, find_changelog, find_version"))

# compat for older Julia versions
include("compat.jl")

# generate Documenter changelogs and links
include("generate.jl")

# CommonMark <> MarkdownAST code
include("commonmark_markdownast_interop.jl")
using .CommonMarkMarkdownASTInterop: md_convert

# Convert MarkdownAST tree to our own tree
include("heading_tree.jl")

# SimpleChangelog and VersionInfo types, as well as API entrypoints
include("SimpleChangelog.jl")

# Tree traversal and parsing code
include("parse_changelog.jl")

# `find_changelog` and `find_version`
include("heuristics.jl")

end # module
