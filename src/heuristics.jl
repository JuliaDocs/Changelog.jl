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
    The list of changelog names to check may grow or be re-ordered in non-breaking releases of Changelog.jl, but it will not shrink without a breaking release. Likewise the default
    value for `subdirs` is subject to grow but not shrink in non-breaking releases of Changelog.jl.
"""
function find_changelog(pkgdir; subdirs=["docs/src"])
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

    date, idx = findmax(most_recent_version(c.changelog)[1] for c in candidates)

    # if we didn't parse dates out of any changelogs, use filename order instead
    if date == typemin(Date)
        return candidates[1]
    else
        return candidates[idx]
    end
end

function most_recent_version(cl::SimpleChangelog)
    isempty(cl.versions) && return typemin(Date), -1
    return findmax(something(v.date, typemin(Date)) for v in cl.versions)
end

"""
    find_version(changelog::SimpleChangelog, version)

Attempts to find the `VersionInfo` associated to `version` in `changelog`.
Searches `changelog.versions` for an exact match to `version`, then for approximate matches.

* if `version === :latest`, the latest version will be returned (by date, or failing that, the first entry)
* if `version` is a VersionNumber, it will be converted to a string (using `string`), then:
* if `version` is a string, it will be used to search for exact and then approximate matches

Note that `string(v"1.1") = "1.1.0"`, meaning that passing a version number will search for the complete version. In contrast, passing a string "1.1" will search for a version number with 1.1 in it, favoring exact matches ("1.1"), then the first version starting with "1.1" (followed by a word-boundary such as `.` or a space), then the first version containing "1.1" in any position.

Returns `nothing` if no `VersionInfo` could be found, and otherwise the matching `VersionInfo`.

!!! note
    The heuristics used here to find the most appropriate match may be changed in non-breaking releases of Changelog.jl. However, exact matches will always be preferred.
"""
function find_version(changelog::SimpleChangelog, version)
    isempty(changelog.versions) && return nothing
    if version === :latest
        # sometimes the first version is unreleased; we will go with the version
        # with the most recent date, and fall back to the first version
        date, idx = most_recent_version(changelog)
        if date === typemin(Date) || idx < 0
            return changelog.versions[1]
        else
            return changelog.versions[idx]
        end
    end
    version = string(version)
    versions = (v.version for v in changelog.versions)

    # remove brackets, code quoting, `v`'s
    repl = v -> replace_until_convergence(v, r"[`v\[\]\{\}]" => "")
    version_repl = repl(version)

    # we use \Q and \E to quote our input, and look for a match
    # starting at the beginning of the version number, with a word-boundary
    # after our `version`
    startswith_version = Regex(raw"^\Q" * version * raw"\E\b")
    startswith_version_repl = Regex(raw"^\Q" * version_repl * raw"\E\b")

    idx = @something(
        # first, look for exact matches
        findfirst(==(version), versions),
        # then look for starting with our version, then a word-boundary
        findfirst(contains(startswith_version), versions),
        # then the same, but after replacements
        findfirst(v -> contains(repl(v), startswith_version_repl), versions),
        # then look for any containment
        findfirst(contains(version), versions),
        # then the same, but after replacements
        findfirst(v -> contains(repl(v), version_repl), versions),
        Some(nothing)
    )
    idx === nothing && return nothing
    return changelog.versions[idx]
end
