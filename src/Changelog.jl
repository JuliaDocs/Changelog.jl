"""
    Changelog

Julia package for managing changelogs. See
https://github.com/JuliaDocs/Changelog.jl/blob/master/README.md for
documentation.
"""
module Changelog

const CHANGELOG_LINK_SEPARATOR = "<!-- Links generated by Changelog.jl -->"

abstract type OutputFormat end
struct Documenter <: OutputFormat end
struct CommonMark <: OutputFormat end

function collect_links(inputfile::String, repo::String)
    # Output mapping tokens to the full URL
    # (e.g. "[#123]" => "https://github.com/JuliaDocs/Documenter.jl/issues/123")
    linkmap = Dict{String, String}()

    # Read the source file and split the content to ignore the list of links
    content = read(inputfile, String)
    content = first(split(content, CHANGELOG_LINK_SEPARATOR))

    # Rule: [abc#XXXX] -> https://github.com/abc/issues/XXXX
    # Description: Replace issue/PR numbers with a link to the default repo
    # Example: [JuliaLang/julia#123] -> https://github.com/JuliaLang/julia/issues/123
    # There is no need to distinguish between PRs and Issues because GitHub redirects.
    for m in eachmatch(r"(?<!\])\[(?<repo>[a-zA-Z0-9/\.]+?)\#(?<id>[0-9]+)\](?![\[\(])", content)
        linkmap[m.match] = "https://github.com/$(m["repo"])/issues/$(m["id"])"
    end

    # Rule: [#XXXX] -> https://github.com/url/issue/XXXX
    # Description: Replace issue/PR numbers with a link to the default repo
    # Example: [#123] -> https://github.com/JuliaDocs/Documenter.jl/issues/123
    # There is no need to distinguish between PRs and Issues because GitHub redirects.
    for m in eachmatch(r"(?<!\])\[\#(?<id>[0-9]+)\](?![\[\(])", content)
        linkmap[m.match] = "https://github.com/$(repo)/issues/$(m["id"])"
    end

    # Rule: [@XXXX] -> https://github.com/XXXX
    # Description: Replace users with a link to their GitHub
    # Example: [@odow] -> https://github.com/odow
    for m in eachmatch(r"(?<!\])\[@(?<id>.+?)\](?![\[\(])", content)
        linkmap[m.match] = "https://github.com/$(m["id"])"
    end

    # Rule: [vX.Y.Z] -> url/releases/tag/vX.Y.Z
    # Description: Replace version headers with a link to the GitHub release
    # Example: [v0.27.0] -> https://github.com/JuliaDocs/Documenter.jl/releases/tag/v0.27.0
    for m in eachmatch(r"(?<!\])(?<token>\[(?<tag>v[0-9]+.[0-9]+.[0-9]+)\])(?![\[\(])", content)
        linkmap[m["token"]] = "https://github.com/$(repo)/releases/tag/$(m["tag"])"
    end

    return linkmap
end

"""
    generate(
        ::Documenter, inputfile::String, outputfile::String;
        repo::String, branch::String = "master",
    )

Read the input changelog file and modify it, according to the rules below, so that in can be
fed to [Documenter](https://github.com/JuliaDocs/Documenter.jl). `repo` is the default
repository (e.g. `repo = "JuliaDocs/Changelog.jl"`) and `branch` the branch for which to
point Documenter's `EditURL` link to.

The following modifications and replacements are performed:

 - `[#XYZ]` is replaced with `[#XYZ](https://github.com/\$repo/issues/XYZ)` where `repo` is
   the input keyword argument. For example, `[#123]` becomes
   `[#123](https://github.com/JuliaDocs/Changelog.jl/issues/123)` (with
   `repo = "JuliaDocs/Changelog.jl"`).

 - `[abc#XYZ]` is replaced with `[abc#XYZ](https://github.com/abc/issues/XYZ)`. For example,
   `[JuliaLang/julia#265]` becomes
   `[JuliaLang/julia#265](https://github.com/JuliaLang/julia/issues/265)`.

 - `[vX.Y.Z]` is replaced with `[vX.Y.Z](https://github.com/\$repo/releases/tag/vX.Y.Z)`.
   For example, `[v1.0.0]` becomes
   `[v1.0.0](https://github.com/JuliaDocs/Changelog.jl/releases/tag/v1.0.0)` (with
   `repo = "JuliaDocs/Changelog.jl"`).

 - `[@abc]` is replaced with `[@abc](https://github.com/abc)`. For example, `[@octocat]`
   becomes `[@octocat](https://github.com/octocat)`.

 - Links of the form
   ```
   [link text][target]

   [target]: https://example.com
   ```
   are inlined and becomes
   ```
   [link text](https://example.com)
   ```
"""
function generate(
    ::Documenter,
    inputfile::String,
    outputfile::String;
    repo::String,
    branch::String = "master",
)
    # Get the map of token to full URL
    linkmap = collect_links(inputfile, repo)

    # Read the source file and split the content to ignore the list of links
    content = read(inputfile, String)
    content = first(split(content, CHANGELOG_LINK_SEPARATOR))

    # Replace all link tokens with full URLs
    for (token, url) in linkmap
        # Generate replacement regex from the token of the form [xxx]: no ] before the
        # token, and no [ or ( after the token
        r = Regex("(?<!\\])" * escape_string(token, "[]") * "(?![\\[\\(])")
        while (m = match(r, content); m !== nothing)
            content = replace(content, r => "$(token)($(url))"; count = 1)
        end
    end

    # For Documenter output we need to inline explicit markdown links, e.g. replace
    #     A [link1] and [another][link2]
    #
    #     [link1]: https://link1
    #     [link2]: https://link2
    # with
    #     A [link1](https://link1) and [another](https://link2)

    # Lookup any explicitly included links
    explicit_links = Dict{String, String}()
    for m in eachmatch(r"(*ANYCRLF)^(?<token>\[\w+\]): (?<url>https:\/\/.*)$"m, content)
        explicit_links[m["token"]] = m["url"]
    end
    # Remove the link lines
    for token in keys(explicit_links)
        content = replace(content, Regex("(*ANYCRLF)^" * escape_string(token, "[]") * ": .*\$\\R?", "m") => "")
    end
    # Insert the links inline
    for (token, url) in explicit_links
        # Check whether this token is of the form [link text][token] and in that case use
        # the original link text
        r = Regex("(?<text>\\[[\\w\\s]+\\])?" * escape_string(token, "[]") * "(?![\\[\\(])")
        while (m = match(r, content); m !== nothing)
            if m["text"] === nothing
                content = replace(content, r => "$(token)($(url))"; count = 1)
            else
                content = replace(content, r => "$(m["text"])($(url))"; count = 1)
            end
        end
    end

    # Header to set EditURL
    header = """
    ```@meta
    EditURL = "https://github.com/$repo/blob/$branch/CHANGELOG.md"
    ```

    """

    # Write it all out
    open(outputfile, "w") do io
        write(io, header)
        write(io, content)
    end

    return
end

"""
    generate(
        ::CommonMark, inputfile::String, outputfile::String = inputfile;
        repo::String,
    )

Read the input changelog file and modify it as described below. In particular, this method
scans the input for "link tokens", and generates a list of urls placed at the bottom of the
file.

The following link tokens are discovered:

 - `[#XYZ]` results in the link `[#XYZ]: https://github.com/\$repo/issues/XYZ`, where `repo`
   is the input keyword argument. For example, `[#123]` adds
   `[#123]: https://github.com/JuliaDocs/Changelog.jl/issues/123` to the list (with
   `repo = "JuliaDocs/Changelog.jl"`).

 - `[abc#XYZ]` results in the link `[abc#XYZ]: https://github.com/abc/issues/XYZ`. For
   example, `[JuliaLang/julia#265]` adds
   `[JuliaLang/julia#265]: https://github.com/JuliaLang/julia/issues/265` to the list.

 - `[vX.Y.Z]` results in the link `[vX.Y.Z]: https://github.com/\$repo/releases/tag/vX.Y.Z`.
   For example, `[v1.0.0]` adds
   `[v1.0.0](https://github.com/JuliaDocs/Changelog.jl/releases/tag/v1.0.0)` to the list
   (with `repo = "JuliaDocs/Changelog.jl"`).

 - `[@abc]` results in the link `[@abc]: https://github.com/abc`. For example, `[@octocat]`
   adds `[@octocat]: https://github.com/octocat` to the list
"""
function generate(
    ::CommonMark,
    inputfile::String,
    outputfile::String = inputfile;
    repo::String,
)
    # Get the map of token to full URL
    linkmap = collect(collect_links(inputfile, repo))

    # Sort releases first, then own issues, then external issues, then other things
    sort!(linkmap; by = function(x)
        k, v = x
        if occursin("/releases/tag/", v)
            # Sort releases by version number
            return (1, VersionNumber(match(r"\[(?<version>.*)\]", k)["version"]))
        elseif occursin("github.com/$(repo)/issues/", v)
            # Sort issues by number
            n = parse(Int, match(r"\[\#(?<id>\d+)\]", k)["id"])
            return (2, n)
        elseif occursin(r"github\.com/.*/issues/", v)
            # Sort by repo name, then issues by number
            m = match(r"\[(?<repo>.*)\#(?<id>\d+)\]", k)
            n = parse(Int, m["id"])
            return (3, m["repo"], n)
        else
            return (4,)
        end
    end)

    # Read the source file and split the content to ignore the list of links
    content = read(inputfile, String)
    content = strip(first(split(content, CHANGELOG_LINK_SEPARATOR)))

    # Write it all out
    open(outputfile, "w") do io
        write(io, content)
        write(io, "\n\n\n")
        write(io, CHANGELOG_LINK_SEPARATOR)
        write(io, "\n\n")
        for (k, v) in linkmap
            println(io, k, ": ", v)
        end
    end

    return
end

end # module
