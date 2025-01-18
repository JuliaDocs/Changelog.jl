const CHANGELOG_NAMES = Set(permutedims(["changelog", "news", "release_notes", "changes", "release notes", "history", "version_history", "version history"]) .* [".md", "", ".txt"])

"""
    find_changelog(pkgdir; subdirs = ["docs/src"])

Given a directory `pkgdir`, attempts to find a changelog in the directory or in the specified subdirectories.

Returns an `@NamedTuple{path::String, changelog::SimpleChangelog}` if a parseable changelog
was found, otherwise returns `nothing`.

Checks the following possible filenames, with any casing:

$(join(map(x -> "`$x`", sort!(collect(CHANGELOG_NAMES))), ", "))

When multiple changelogs are found, returns the changelog with the most recent version,
using the parsed date, or otherwise via the order of the list of changelog filenames.

!!! note
    The list of changelog names to check may grow or be re-ordered in non-breaking releases of Changelog.jl, but it will not shrink without a breaking release.
"""
function find_changelog(pkgdir; subdirs = ["docs/src"])
    dirs = [pkgdir]
    for s in subdirs
        subdir_path = joinpath(pkgdir, s)
        if isdir(subdir_path)
            push!(dirs, subdir_path)
        end
    end
    candidates = @NamedTuple{path::String, changelog::SimpleChangelog}[]
    for dir in dirs
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
                path = joinpath(dir, contents[idx])
                changelog = tryparsefile(path)
                push!(candidates, (; path, changelog))
            end
        end
    end
    isempty(candidates) && return nothing

    date, idx = findmax(most_recent_version(c.changelog) for c in candidates)

    # if we didn't parse dates out of any changelogs, use filename order instead
    if date == typemin(Date)
        return candidates[1]
    else
        return candidates[idx]
    end
end

function most_recent_version(cl::SimpleChangelog)
    return maximum(something(v.date, typemin(Date)) for v in cl.versions; init = typemin(Date))
end

"""
    find_version(changelog::SimpleChangelog, version)

Attempts to find the `VersionInfo` associated to `version` in `changelog`.
Searches `changelog.versions` for an exact match to `version`, then for approximate matches.

Returns `nothing` if no `VersionInfo` could be found, and otherwise the matching `VersionInfo`.
"""
function find_version(changelog::SimpleChangelog, version)
    version = string(version)
    versions = (v.version for v in changelog.versions)
    repl = v -> replace_until_convergence(v, r"[`v\[\]\{\}]" => "")
    repl_v = repl(version)
    idx = @something(
        findfirst(==(version), versions),
        findfirst(contains(version), versions),
        findfirst(v -> contains(repl(v), repl_v), versions),
        Some(nothing)
    )
    idx === nothing && return nothing
    return changelog.versions[idx]
end
