"""
    VersionInfo

A struct representing the information in a changelog about a particular version, with properties:

- `version::Union{Nothing, String}`: a string representation of a version number or name (e.g. "Unreleased" or "1.2.3").
- `url::Union{Nothing, String}`: a URL associated to the version, if available
- `date::Union{Nothing, Date}`: a date associated to the version, if available
- `toplevel_changes::Vector{String}`: a list of changes which are not within a section
- `sectioned_changes::Vector{Pair{String, Vector{String}}}`: an ordered mapping of section name to a list of changes in that section.

"""
struct VersionInfo
    version::Union{Nothing, String}
    url::Union{Nothing, String}
    date::Union{Nothing, Date}
    toplevel_changes::Vector{String}
    sectioned_changes::Vector{Pair{String, Vector{String}}}
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
    return if isempty(v.sectioned_changes) && isempty(v.toplevel_changes)
        print(io, "\n", pad, "- and no documented changes")
    else
        print(io, "\n", pad, "- changes")
        if !isempty(v.toplevel_changes)
            for b in v.toplevel_changes
                print(io, "\n", pad, "  - $b")
            end
        end

        if !isempty(v.sectioned_changes)
            for (section_name, bullets) in v.sectioned_changes
                print(io, "\n", pad, "  - $section_name")
                for b in bullets
                    print(io, "\n", pad, "    - $b")
                end
            end
        end
    end
end

"""
    SimpleChangelog

A simple in-memory changelog format, with properties:

- `title::Union{Nothing, String}`
- `intro::Union{Nothing, String}`
- `versions::Vector{VersionInfo}`

A `SimpleChangelog` can be parsed out of a markdown-formatted string with `Base.parse`.

SimpleChangelogs are not intended to be roundtrippable in-memory representations of markdown
changelogs; rather, they discard most formatting and other details to provide a simple
view to make it easy to query if the changelog has an entry for some particular version,
or what the changes are for that version.

See also: [`VersionInfo`](@ref), [`parsefile`](@ref).
"""
struct SimpleChangelog
    title::Union{Nothing, String}
    intro::Union{Nothing, String}
    versions::Vector{VersionInfo}
end

function Base.show(io::IO, ::MIME"text/plain", c::SimpleChangelog)
    print(io, SimpleChangelog, " with")
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
    parse(::Type{SimpleChangelog}, text::AbstractString)

Parse a [`SimpleChangelog`](@ref) from a markdown-formatted string.

!!! note
    This functionality is primarily intended for parsing [KeepAChangeLog](https://keepachangelog.com/en/1.1.0/)-style changelogs, that have a title as a H1 (e.g. `#`) markdown header, followed by a list of versions with H2-level headers (`##`) formatted like `[1.1.0] - 2019-02-15` with or without a link on the version number, followed by a bulleted list of changes, potentially in subsections, each with H3 header. For such changelogs, parsing should be stable. We may also attempt to parse a wider variety of headers, for which the extent that we can parse may change in non-breaking releases (typically improving the parsing, but potentially regressing in some cases).
"""
function Base.parse(::Type{SimpleChangelog}, text::AbstractString)
    # parse into CommonMark AST
    parser = CM.Parser()
    CM.enable!(parser, CM.FootnoteRule())
    ast = parser(text)
    # convert to MarkdownAST AST
    ast = md_convert(MarkdownAST.Node, ast)
    return _parse_simple_changelog!(ast)
end

"""
    tryparse(::Type{SimpleChangelog}, text::AbstractString)

Try to parse a [`SimpleChangelog`](@ref) from a markdown-formatted string,
returning `nothing` if unable to.

"""
function Base.tryparse(::Type{SimpleChangelog}, text::AbstractString)
    return try
        parse(SimpleChangelog, text)
    catch e
        # This may be handy occasionally if we want to understand why we couldn't parse
        # and don't want to manually run `parse(SimpleChangelog, text)`.
        @debug "Error when parsing `SimpleChangelog` from changelog, returning `nothing`" exception = sprint(Base.display_error, e, catch_backtrace())
        nothing
    end
end

"""
    parsefile(path) -> SimpleChangelog

Parse a [`SimpleChangelog`](@ref) from a file path `path`.
"""
function parsefile(path)
    return parse(SimpleChangelog, read(path, String))
end

"""
    tryparsefile(path) -> SimpleChangelog

Try to parse a [`SimpleChangelog`](@ref) from a file path `path`, returning
`nothing` if unable to.
"""
function tryparsefile(path)
    return tryparse(SimpleChangelog, read(path, String))
end


const CHANGELOG_NAMES = Set(permutedims(["changelog", "news", "release_notes", "changes", "release notes", "history", "version_history", "version history"]) .* [".md", "", ".txt"])

"""
    find_changelog(dir)

Given a directory `dir`, attempts to find a changelog in the directory, returning the path to the changelog if one is found, checking the following possible filenames, with any casing:

$(join(map(x -> "`$x`", sort!(collect(CHANGELOG_NAMES))), ", "))

If no changelog file is found, `nothing` is returned.

!!! note
    The list of changelog names to check may grow or be re-ordered in non-breaking releases of Changelog.jl, but it will not shrink without a breaking release.
"""
function find_changelog(dir)
    if !isdir(dir)
        throw(ArgumentError("[find_changelog] A directory must be passed."))
    end
    contents = readdir(dir)
    # we want the return to be based on the order in `CHANGELOG_NAMES`, so
    # if there is e.g. both news and history, we use news.
    # We check in the order prescribed by `CHANGELOG_NAMES`, but we use
    # the casing determined by `contents`. If there is both `CHANGELOG` and
    # `changelog` (only differing by casing), then we use the uppercase one,
    # as `readdir` sorts in that way.
    for lowercase_name in CHANGELOG_NAMES
        idx = findfirst(c -> lowercase(c) == lowercase_name, contents)
        if idx !== nothing
            return joinpath(dir, contents[idx])
        end
    end
    return nothing
end

"""
    tryparsefile(mod::Module)

Given a top-level module `mod` in a package, attempts to find the package directory using `pkgdir`,
find a changelog in the package directory using [`find_changelog`](@ref), and finally
parse the changelog using `tryparsefile`. If any step fails, returns `nothing`.
"""
function tryparsefile(mod::Module)
    dir = pkgdir(mod)
    dir === nothing && return nothing
    file = find_changelog(dir)
    file === nothing && return nothing
    return tryparsefile(file)
end

function find_version(cl::SimpleChangelog, version)
    version = string(version)
    versions = (v.version for v in cl.versions)
    repl = v -> replace_until_convergence(v, r"[`v\[\]\{\}]" => "")
    idx = @something(
        findfirst(==(version), versions),
        findfirst(contains(version), versions),
        findfirst(v -> contains(repl(v), version), versions)
    )
    idx === nothing && return nothing
    return cl.versions[idx]
end
