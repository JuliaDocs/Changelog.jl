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
using OrderedCollections: OrderedDict
import CommonMark as CM

public parsefile, VersionInfo

export SimpleLog

# generate Documenter changelogs and links
include("generate.jl")

# CommonMark <> MarkdownAST code
include("commonmark_markdownast_interop.jl")
using .CommonMarkMarkdownASTInterop: md_convert

# Convert MarkdownAST tree to our own tree
include("heading_tree.jl")

# Changelog and VersionInfo types, as well as API entrypoints
include("types.jl")

# Tree traversal and parsing code
include("parse_changelog.jl")


end # module
