# Command line interface, available as a Pkg app (`pkg> app add Changelog`) or via
# `julia -m Changelog`.

const CLI_HELP = """
usage: changelog <command> [<args>]

Commands:
  generate   Generate links for link tokens like [#123] in a changelog
  show       Show the changes for a version
  versions   List the versions in a changelog

Options:
  -h, --help   Show this help, or the help for a command (changelog <command> --help)
  --version    Show the version of Changelog.jl
"""

const GENERATE_HELP = """
usage: changelog generate [INPUT] [-o OUTPUT] [--format commonmark|documenter]
                          [--repo OWNER/NAME] [--branch BRANCH] [--check]

Scan INPUT (default: CHANGELOG.md) for link tokens like [#123], [@user], and [v1.2.3],
and generate the corresponding GitHub links.

Options:
  -o, --output OUTPUT  Output file. Defaults to INPUT for --format commonmark, and is
                       required for --format documenter.
  --format FORMAT      `commonmark` (default) writes a list of links at the bottom of the
                       file. `documenter` inlines the links for use with Documenter.jl.
  --repo OWNER/NAME    Repository for links like [#123]. If not given, the repository used
                       by existing links in INPUT is used, otherwise the repository of the
                       git remote `origin`.
  --branch BRANCH      Branch for Documenter's EditURL (only for --format documenter).
                       Defaults to the default branch of `origin`, otherwise `master`.
  --check              Don't write OUTPUT, instead exit with code 1 if it is not up to date.
"""

const SHOW_HELP = """
usage: changelog show [PATH] [VERSION]

Show the changes for VERSION (default: the latest version). PATH is a changelog file or a
directory to search for a changelog in (default: the current directory). If only one
argument is given it is interpreted as PATH if it exists, and as VERSION otherwise.

VERSION is matched approximately, e.g. `1.1` matches the first 1.1.x version listed.
"""

const VERSIONS_HELP = """
usage: changelog versions [PATH]

List the versions in a changelog, one per line, followed by a tab and the release date if
available. PATH is a changelog file or a directory to search for a changelog in (default:
the current directory).
"""

# Errors from invalid command line usage (exit code 2)
struct UsageError <: Exception
    msg::String
end

# Other errors that should be reported without a backtrace (exit code 1)
struct CLIError <: Exception
    msg::String
end

"""
    main(args::Vector{String}) -> Cint

Entrypoint for the `changelog` command line interface. Run `main(["--help"])` for usage
information. Returns the exit code.
"""
function main(args::AbstractVector{<:AbstractString})
    return _main(args, stdout, stderr)
end

function _main(args, io::IO, err::IO)
    args = String[a for a in args]
    if isempty(args)
        print(err, CLI_HELP)
        return Cint(2)
    elseif args[1] in ("-h", "--help", "help")
        print(io, CLI_HELP)
        return Cint(0)
    elseif args[1] == "--version"
        println(io, "changelog ", isdefined(Base, :pkgversion) ? Base.pkgversion(@__MODULE__) : "(unknown version)")
        return Cint(0)
    end
    cmd, rest = args[1], args[2:end]
    return try
        if cmd == "generate"
            return Cint(cli_generate(rest, io, err))
        elseif cmd == "show"
            return Cint(cli_show(rest, io))
        elseif cmd == "versions"
            return Cint(cli_versions(rest, io))
        else
            println(err, "error: unknown command `$(cmd)`")
            println(err, "Run `changelog --help` for usage information.")
            return Cint(2)
        end
    catch e
        if e isa UsageError
            println(err, "error: ", e.msg)
            println(err, "Run `changelog $(cmd) --help` for usage information.")
            return Cint(2)
        elseif e isa CLIError || e isa ArgumentError
            println(err, "error: ", e.msg)
            return Cint(1)
        end
        rethrow()
    end
end

@static if isdefined(Base, Symbol("@main"))
    # Mark `main` as the entrypoint for `julia -m Changelog` and the Pkg app
    @main
end

# Parse `args` into positional arguments, options with values, and flags
function parse_cli_args(args; options = String[], flags = String[], aliases = Dict{String, String}())
    positional = String[]
    opts = Dict{String, String}()
    set_flags = Set{String}()
    push!(flags, "--help")
    aliases["-h"] = "--help"
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--"
            append!(positional, args[(i + 1):end])
            break
        elseif startswith(arg, "-") && arg != "-"
            name, val = occursin('=', arg) ? split(arg, '='; limit = 2) : (arg, nothing)
            name = get(aliases, name, name)
            if name in flags
                val === nothing || throw(UsageError("flag `$(name)` does not take a value"))
                push!(set_flags, name)
            elseif name in options
                if val === nothing
                    i += 1
                    i > length(args) && throw(UsageError("option `$(name)` requires a value"))
                    val = args[i]
                end
                opts[name] = val
            else
                throw(UsageError("unknown option `$(arg)`"))
            end
        else
            push!(positional, arg)
        end
        i += 1
    end
    return positional, opts, set_flags
end

function cli_generate(args, io, err)
    positional, opts, flags = parse_cli_args(
        args; options = ["--output", "--format", "--repo", "--branch"],
        flags = ["--check"], aliases = Dict("-o" => "--output"),
    )
    if "--help" in flags
        print(io, GENERATE_HELP)
        return 0
    end
    length(positional) > 1 && throw(UsageError("expected at most one input file"))
    input = isempty(positional) ? "CHANGELOG.md" : positional[1]
    isfile(input) || throw(CLIError("input file `$(input)` does not exist"))
    format = get(opts, "--format", "commonmark")
    if !(format in ("commonmark", "documenter"))
        throw(UsageError("unknown format `$(format)`, expected `commonmark` or `documenter`"))
    end
    if format == "documenter" && !haskey(opts, "--output")
        throw(UsageError("`--format documenter` requires `--output`"))
    end
    if format == "commonmark" && haskey(opts, "--branch")
        throw(UsageError("`--branch` is only used with `--format documenter`"))
    end
    output = get(opts, "--output", input)
    gitdir = dirname(abspath(input))
    repo = resolve_repo(get(opts, "--repo", nothing), read(input, String), gitdir, err)
    if format == "commonmark"
        gen = out -> generate(CommonMark(), input, out; repo = repo)
    else
        branch = something(get(opts, "--branch", nothing), git_default_branch(gitdir), "master")
        editurl_path = git_relpath(input)
        gen = out -> generate(Documenter(), input, out; repo = repo, branch = branch, editurl_path = editurl_path)
    end
    if "--check" in flags
        return mktempdir() do dir
            tmp = joinpath(dir, "output.md")
            gen(tmp)
            if isfile(output) && read(tmp, String) == read(output, String)
                return 0
            else
                println(err, "`$(output)` is not up to date, run the command without `--check` to update it.")
                return 1
            end
        end
    else
        gen(output)
        return 0
    end
end

# Determine the default repository for links, in order of precedence:
#  1. explicitly given with `--repo`
#  2. the repository that existing generated links point to
#  3. the repository of the git remote `origin`
function resolve_repo(repo, content, gitdir, err)
    if repo !== nothing
        link_repo = try
            repo_from_links(content)
        catch e
            e isa ArgumentError || rethrow()
            nothing
        end
        if link_repo !== nothing && link_repo != repo
            println(err, "note: existing links point to `$(link_repo)`, using `$(repo)` from `--repo`.")
        end
        return repo
    end
    link_repo = try
        repo_from_links(content)
    catch e
        e isa ArgumentError || rethrow()
        throw(CLIError("$(e.msg), use `--repo` to pick one"))
    end
    origin_repo = git_origin_repo(gitdir)
    if link_repo !== nothing
        if origin_repo !== nothing && origin_repo != link_repo
            println(err, "note: using `$(link_repo)` from existing links, which differs from the git remote `origin` (`$(origin_repo)`). Use `--repo` to override.")
        end
        return link_repo
    elseif origin_repo !== nothing
        return origin_repo
    end
    throw(CLIError("could not determine the repository from existing links or the git remote `origin`, use `--repo OWNER/NAME`"))
end

# Run git in `dir`, returning the output or `nothing` on failure
function git(dir, args...)
    Sys.which("git") === nothing && return nothing
    try
        return readchomp(pipeline(`git -C $(dir) $(args)`; stderr = devnull))
    catch e
        e isa ProcessFailedException || rethrow()
        return nothing
    end
end

function git_origin_repo(dir)
    url = git(dir, "remote", "get-url", "origin")
    url === nothing && return nothing
    m = match(r"github\.com[:/](?<repo>[^/\s]+/[^/\s]+?)(?:\.git)?/?$", url)
    return m === nothing ? nothing : String(m["repo"])
end

function git_default_branch(dir)
    ref = git(dir, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
    (ref === nothing || !startswith(ref, "origin/")) && return nothing
    return String(ref[(length("origin/") + 1):end])
end

# Path of `file` relative to the root of the git repository it is in
function git_relpath(file)
    toplevel = git(dirname(abspath(file)), "rev-parse", "--show-toplevel")
    toplevel === nothing && return basename(file)
    return replace(relpath(realpath(file), realpath(toplevel)), '\\' => '/')
end

function load_changelog(path)
    if isdir(path)
        nt = find_changelog(path)
        nt === nothing && throw(CLIError("no changelog found in `$(path)`"))
        return nt.changelog
    elseif isfile(path)
        changelog = tryparsefile(path)
        changelog === nothing && throw(CLIError("could not parse `$(path)` as a changelog"))
        return changelog
    else
        throw(CLIError("`$(path)` does not exist"))
    end
end

function cli_show(args, io)
    positional, _, flags = parse_cli_args(args)
    if "--help" in flags
        print(io, SHOW_HELP)
        return 0
    end
    if length(positional) == 0
        path, version = ".", nothing
    elseif length(positional) == 1
        path, version = ispath(positional[1]) ? (positional[1], nothing) : (".", positional[1])
    elseif length(positional) == 2
        path, version = positional
    else
        throw(UsageError("expected at most two arguments"))
    end
    changelog = load_changelog(path)
    v = find_version(changelog, something(version, :latest))
    if v === nothing
        throw(CLIError(version === nothing ? "no versions found in `$(path)`" : "version `$(version)` not found in `$(path)`"))
    end
    print_version(io, v)
    return 0
end

# Print a `VersionInfo` as markdown
function print_version(io, v::VersionInfo)
    print(io, "## ", something(v.version, ""))
    v.date === nothing || print(io, " - ", v.date)
    println(io)
    print_changes = changes -> for c in changes
        println(io, "- ", replace(c, "\n" => "\n  "))
    end
    if !isempty(v.toplevel_changes)
        println(io)
        print_changes(v.toplevel_changes)
    end
    for (section, changes) in v.sectioned_changes
        println(io, "\n### ", section, "\n")
        print_changes(changes)
    end
    return
end

function cli_versions(args, io)
    positional, _, flags = parse_cli_args(args)
    if "--help" in flags
        print(io, VERSIONS_HELP)
        return 0
    end
    length(positional) > 1 && throw(UsageError("expected at most one argument"))
    changelog = load_changelog(isempty(positional) ? "." : positional[1])
    for v in changelog.versions
        println(io, something(v.version, ""), v.date === nothing ? "" : "\t$(v.date)")
    end
    return 0
end
