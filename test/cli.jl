using Changelog: repo_from_links

# Run the CLI and return (exit code, stdout, stderr)
function cli(args...)
    io, err = IOBuffer(), IOBuffer()
    code = Changelog._main(collect(String, args), io, err)
    return code, String(take!(io)), String(take!(err))
end

gitcmd(dir, args...) = run(pipeline(`git -C $(dir) $(args)`; stdout = devnull, stderr = devnull))

@testset "repo_from_links" begin
    @test repo_from_links("# Changelog\n- [#1]\n") === nothing
    @test repo_from_links(GITHUB_OUTPUT) == "JuliaDocs/Changelog.jl"
    # Links to other repositories are ignored
    @test repo_from_links(
        """
        $(Changelog.CHANGELOG_LINK_SEPARATOR)

        [JuliaLang/julia#1]: https://github.com/JuliaLang/julia/issues/1
        [@octocat]: https://github.com/octocat
        """
    ) === nothing
    @test_throws ArgumentError repo_from_links(
        """
        $(Changelog.CHANGELOG_LINK_SEPARATOR)

        [#1]: https://github.com/Foo/Bar.jl/issues/1
        [v1.0.0]: https://github.com/Baz/Bar.jl/releases/tag/v1.0.0
        """
    )
end

@testset "CLI: main" begin
    code, out, err = cli()
    @test code == 2
    @test occursin("usage: changelog", err)
    code, out, err = cli("--help")
    @test code == 0
    @test occursin("usage: changelog", out)
    for cmd in ("generate", "show", "versions")
        code, out, err = cli(cmd, "--help")
        @test code == 0
        @test occursin("usage: changelog $(cmd)", out)
    end
    code, out, err = cli("--version")
    @test code == 0
    @test startswith(out, "changelog ")
    code, out, err = cli("bogus")
    @test code == 2
    @test occursin("unknown command `bogus`", err)
    code, out, err = cli("show", "--bogus")
    @test code == 2
    @test occursin("unknown option `--bogus`", err)
    @test occursin("changelog show --help", err)
end

@testset "CLI: show, versions" begin
    file = test_path("good/ex1.md")
    code, out, err = cli("versions", file)
    @test code == 0
    @test out == "Unreleased\n1.0.0\t2024-12-25\n"
    code, out, err = cli("show", file)
    @test code == 0
    @test startswith(out, "## 1.0.0 - 2024-12-25\n\n### Added\n\n- Initial release")
    code, out, err = cli("show", file, "Unreleased")
    @test code == 0
    @test out == "## Unreleased\n\n### Added\n\n- Feature X\n- New widget for dashboards\n"
    code, out, err = cli("show", file, "2.0")
    @test code == 1
    @test occursin("version `2.0` not found", err)
    # Single argument is a version if it isn't a path
    cd(dirname(file)) do
        code, out, err = cli("show", "Unreleased")
        @test code == 1 # no changelog in this directory
        @test occursin("no changelog found", err)
    end
    # Changelog found in a directory
    code, out, err = cli("versions", test_path("test_pkgs/TestPkg1"))
    @test code == 0
    @test !isempty(out)
    code, out, err = cli("versions", test_path("test_pkgs/TestPkg4"))
    @test code == 1
    @test occursin("no changelog found", err)
    code, out, err = cli("show", "does-not-exist", "1.0")
    @test code == 1
    @test occursin("does not exist", err)
end

@testset "CLI: generate" begin
    mktempdir() do dir
        file = joinpath(dir, "CHANGELOG.md")
        write(file, CHANGELOG)
        # Not a git repository and no existing links
        code, out, err = cli("generate", file)
        @test code == 1
        @test occursin("could not determine the repository", err)
        # Explicit --repo
        code, out, err = cli("generate", file, "--repo", "JuliaDocs/Changelog.jl")
        @test code == 0
        @test read(file, String) == GITHUB_OUTPUT
        # Repository from existing links
        code, out, err = cli("generate", file, "--check")
        @test (code, err) == (0, "")
        # Default input file
        cd(dir) do
            @test cli("generate", "--check")[1] == 0
        end
        # Out of date
        write(file, replace(read(file, String), "[#123]" => "[#123], [#124]"; count = 1))
        code, out, err = cli("generate", file, "--check")
        @test code == 1
        @test occursin("is not up to date", err)
        @test cli("generate", file)[1] == 0
        @test occursin("[#124]: https://github.com/JuliaDocs/Changelog.jl/issues/124", read(file, String))
        # --repo takes precedence over existing links
        code, out, err = cli("generate", file, "--repo=Foo/Bar.jl")
        @test code == 0
        @test occursin("existing links point to `JuliaDocs/Changelog.jl`", err)
        @test repo_from_links(read(file, String)) == "Foo/Bar.jl"
        # Documenter output
        out = joinpath(dir, "out.md")
        code, _, err = cli("generate", file, "--format", "documenter", "-o", out)
        @test code == 0
        @test occursin("EditURL = \"https://github.com/Foo/Bar.jl/blob/master/CHANGELOG.md\"", read(out, String))
        # Usage errors
        @test cli("generate", file, "--format", "documenter")[1] == 2
        @test cli("generate", file, "--format", "bogus")[1] == 2
        @test cli("generate", file, "--branch", "main")[1] == 2
        @test cli("generate", joinpath(dir, "nope.md"))[1] == 1
    end
end

if Sys.which("git") !== nothing
    @testset "CLI: generate with git" begin
        mktempdir() do dir
            gitcmd(dir, "init")
            gitcmd(dir, "remote", "add", "origin", "git@github.com:Upstream/Pkg.jl.git")
            mkdir(joinpath(dir, "docs"))
            file = joinpath(dir, "docs", "NEWS.md")
            write(file, CHANGELOG)
            # Repository from origin
            code, out, err = cli("generate", file)
            @test (code, err) == (0, "")
            @test repo_from_links(read(file, String)) == "Upstream/Pkg.jl"
            # Existing links take precedence over origin (e.g. for forks)
            gitcmd(dir, "remote", "set-url", "origin", "https://github.com/Fork/Pkg.jl")
            code, out, err = cli("generate", file)
            @test code == 0
            @test occursin("using `Upstream/Pkg.jl` from existing links", err)
            @test occursin("`Fork/Pkg.jl`", err)
            @test repo_from_links(read(file, String)) == "Upstream/Pkg.jl"
            # Documenter EditURL with the default branch of origin and path in the repo
            out = joinpath(dir, "out.md")
            gitcmd(dir, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
            @test cli("generate", file, "--format", "documenter", "-o", out)[1] == 0
            @test occursin("EditURL = \"https://github.com/Upstream/Pkg.jl/blob/main/docs/NEWS.md\"", read(out, String))
            @test cli("generate", file, "--format", "documenter", "-o", out, "--branch", "dev")[1] == 0
            @test occursin("EditURL = \"https://github.com/Upstream/Pkg.jl/blob/dev/docs/NEWS.md\"", read(out, String))
        end
    end
end

if VERSION >= v"1.12"
    @testset "CLI: julia -m Changelog" begin
        julia = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project())`
        @test success(`$(julia) -m Changelog --version`)
        p = run(pipeline(ignorestatus(`$(julia) -m Changelog bogus`); stderr = devnull))
        @test p.exitcode == 2
    end
end
