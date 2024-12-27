"""
    VersionInfo

A struct representing the information in a changelog about a particular version, with properties:

- `version::Union{Nothing, String}`: a string representation of a version number or name (e.g. "Unreleased" or "1.2.3").
- `url::Union{Nothing, String}`: a URL associated to the version, if available
- `date::Union{Nothing, Date}`: a date associated to the version, if available
- `changes::Union{OrderedDict{String, Vector{String}}, Vector{String}}`: a list of changes associated to the version, either as a flat list (`Vector{String}`), or with ordered sections (`OrderedDict{String, Vector{String}`), where the keys are the section names and the values are the changes in that section. If a version uses sections, but also has items that are not in a section, a section called "General" will be used to store those. If there is already a section called "General", it will be named "General_", and so forth.
"""
struct VersionInfo
    version::Union{Nothing, String}
    url::Union{Nothing, String}
    date::Union{Nothing, Date}
    changes::Union{OrderedDict{String, Vector{String}}, Vector{String}}
end
function Base.show(io::IO, ::MIME"text/plain", v::VersionInfo)
    return full_show(io, v)
end

function full_show(io, v::VersionInfo; indent = 0, showtype = true)
    pad = " "^indent
    if showtype
        print(io, pad, VersionInfo, " with")
        print(io, pad, "\n- version: ", v.version)
    else
        print(io, pad, "- ", v.version)
        pad *= "  "
    end
    if v.url !== nothing
        print(io, "\n", pad, "- url: ", v.url)
    end
    print(io, "\n", pad, "- date: ", v.date)
    changes = v.changes
    return if isempty(changes)
        print(io, "\n", pad, "- and no documented changes")
    elseif changes isa OrderedDict
        print(io, "\n", pad, "- changes")
        for (section_name, bullets) in pairs(changes)
            print(io, "\n", pad, "  - $section_name")
            for b in bullets
                print(io, "\n", pad, "    - $b")
            end
        end
    else
        print(io, "\n", pad, "- changes")
        for b in changes
            print(io, "\n", pad, "  - $b")
        end
    end
end

"""
    SimpleLog

A simple in-memory changelog format, with properties:

- `title::Union{Nothing, String}`
- `intro::Union{Nothing, String}`
- `versions::Vector{VersionInfo}`

A `SimpleLog` can be parsed out of a markdown-formatted string with `Base.parse`.

SimpleLogs are not intended to be roundtrippable in-memory representations of markdown
changelogs; rather, they discard most formatting and other details to provide a simple
view to make it easy to query if the changelog has an entry for some particular version,
or what the changes are for that version.

See also: [`VersionInfo`](@ref).
"""
struct SimpleLog
    title::Union{Nothing, String}
    intro::Union{Nothing, String}
    versions::Vector{VersionInfo}
end

function Base.show(io::IO, ::MIME"text/plain", c::SimpleLog)
    print(io, SimpleLog, " with")
    print(io, "\n- title: ", c.title)
    print(io, "\n- intro: ", c.intro)
    n_versions = length(c.versions)
    plural = n_versions > 1 ? "s" : ""
    print(io, "\n- $(n_versions) version$plural:")
    n_to_show = 5
    for v in first(c.versions, n_to_show)
        print(io, "\n")
        full_show(io, v; showtype = false, indent = 2)
    end
    if n_versions > n_to_show
        print(io, "\n    ⋮")
    end
    return
end

"""
    Base.parse(::Type{SimpleLog}, ast::MarkdownAST.Node)

Parse a [`SimpleLog`](@ref) from a `MarkdownAST` node corresponding to a
`MarkdownAST.Document`.
"""
function Base.parse(::Type{SimpleLog}, ast::MarkdownAST.Node)
    return _parse_simplelog(ast) # see parse_changelog.jl for implementation
end

"""
    parse(::Type{SimpleLog}, text::AbstractString)

Parse a [`SimpleLog`](@ref) from a markdown-formatted string.
"""
function Base.parse(::Type{SimpleLog}, text::AbstractString)
    # parse into CommonMark AST
    parser = CM.Parser()
    CM.enable!(parser, CM.FootnoteRule())
    ast = parser(text)
    # convert to MarkdownAST AST
    ast = md_convert(MarkdownAST.Node, ast)
    return parse(SimpleLog, ast)
end

"""
    parsefile(path) -> SimpleLog

Parse a [`SimpleLog`](@ref) from a file path `path`.
"""
function parsefile(path)
    return parse(SimpleLog, read(path, String))
end
