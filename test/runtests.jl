using Changelog, Test

const CHANGELOG = """
## Version [v1.2.3] - link to GitHub release
 - Link to issue/pull request in own repository: [#123]
 - Link to short commit in own repository: [abcd123]
 - Link to long commit in own repository: [abcdef0123456789abcdef0123456789abcdef12]
 - Link to issue/pull request in another GitHub repository:
   [JuliaLang/julia#123], [JuliaDocs/Documenter.jl#123]
 - Link to GitHub user: [@octocat]
 - Explicitly [included][julialang] [links]
 - Explicitly [included][links] [julialang] again

 - Edge case [#123][whatever]

[julialang]: https://julialang.org
[links]: https://juliadocs.github.io
"""

const DOCUMENTER_OUTPUT = """
```@meta
EditURL = "https://github.com/JuliaDocs/Changelog.jl/blob/master/CHANGELOG.md"
```

## Version [v1.2.3](https://github.com/JuliaDocs/Changelog.jl/releases/tag/v1.2.3) - link to GitHub release
 - Link to issue/pull request in own repository: [#123](https://github.com/JuliaDocs/Changelog.jl/issues/123)
 - Link to short commit in own repository: [abcd123](https://github.com/JuliaDocs/Changelog.jl/commit/abcd123)
 - Link to long commit in own repository: [abcdef0123456789abcdef0123456789abcdef12](https://github.com/JuliaDocs/Changelog.jl/commit/abcdef0123456789abcdef0123456789abcdef12)
 - Link to issue/pull request in another GitHub repository:
   [JuliaLang/julia#123](https://github.com/JuliaLang/julia/issues/123), [JuliaDocs/Documenter.jl#123](https://github.com/JuliaDocs/Documenter.jl/issues/123)
 - Link to GitHub user: [@octocat](https://github.com/octocat)
 - Explicitly [included](https://julialang.org) [links](https://juliadocs.github.io)
 - Explicitly [included](https://juliadocs.github.io) [julialang](https://julialang.org) again

 - Edge case [#123][whatever]

"""

const GITHUB_OUTPUT = """
## Version [v1.2.3] - link to GitHub release
 - Link to issue/pull request in own repository: [#123]
 - Link to short commit in own repository: [abcd123]
 - Link to long commit in own repository: [abcdef0123456789abcdef0123456789abcdef12]
 - Link to issue/pull request in another GitHub repository:
   [JuliaLang/julia#123], [JuliaDocs/Documenter.jl#123]
 - Link to GitHub user: [@octocat]
 - Explicitly [included][julialang] [links]
 - Explicitly [included][links] [julialang] again

 - Edge case [#123][whatever]

[julialang]: https://julialang.org
[links]: https://juliadocs.github.io


$(Changelog.CHANGELOG_LINK_SEPARATOR)

[v1.2.3]: https://github.com/JuliaDocs/Changelog.jl/releases/tag/v1.2.3
[#123]: https://github.com/JuliaDocs/Changelog.jl/issues/123
[abcd123]: https://github.com/JuliaDocs/Changelog.jl/commit/abcd123
[abcdef0123456789abcdef0123456789abcdef12]: https://github.com/JuliaDocs/Changelog.jl/commit/abcdef0123456789abcdef0123456789abcdef12
[JuliaDocs/Documenter.jl#123]: https://github.com/JuliaDocs/Documenter.jl/issues/123
[JuliaLang/julia#123]: https://github.com/JuliaLang/julia/issues/123
[@octocat]: https://github.com/octocat
"""

@testset "Changelog" begin
    tmp = mktempdir()
    write(joinpath(tmp, "CHANGELOG.md"), CHANGELOG)
    # Documenter output
    Changelog.generate(
        Changelog.Documenter(),
        joinpath(tmp, "CHANGELOG.md"),
        joinpath(tmp, "release-notes.md");
        repo = "JuliaDocs/Changelog.jl",
    )
    out = read(joinpath(tmp, "release-notes.md"), String)
    @test out == DOCUMENTER_OUTPUT

    # GitHub output
    Changelog.generate(
        Changelog.CommonMark(),
        joinpath(tmp, "CHANGELOG.md"),
        joinpath(tmp, "release-notes-gh.md");
        repo = "JuliaDocs/Changelog.jl",
    )
    out = read(joinpath(tmp, "release-notes-gh.md"), String)
    @test out == GITHUB_OUTPUT
end
