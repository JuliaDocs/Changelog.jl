@testset "parse_version_header" begin
    @testset "valid header with date" begin
        header = "[1.0.0] - 2023-10-01"
        result = parse_version_header(header)
        @test result.name == "1.0.0"
        @test result.date == Date("2023-10-01")
    end

    @testset "valid header without date" begin
        header = "[1.0.0]"
        result = parse_version_header(header)
        @test result.name == "1.0.0"
        @test result.date === nothing
    end

    @testset "header with invalid date" begin
        header = "[1.0.0] - invalid-date"
        result = parse_version_header(header)
        # note we pass the whole thing as the name - potentially we could improve things
        # so we only skip the date
        @test result.name == "1.0.0 - invalid-date"
        @test result.date === nothing
    end

    @testset "header without version" begin
        header = "[] - 2023-10-01"
        result = parse_version_header(header)
        # again, not optimal
        @test result.name == "-"
        @test result.date == Date("2023-10-01")
    end

    @testset "header without brackets" begin
        header = "1.0.0 - 2023-10-01"
        result = parse_version_header(header)
        @test result.name == "1.0.0"
        @test result.date == Date("2023-10-01")
    end

    @testset "invalid header" begin
        header = "Invalid Header"
        result = parse_version_header(header)
        @test result.name == "Invalid Header"
        @test result.date === nothing
    end

    @testset "multiple quotes" begin
        header = "[1.0.0] (`2024-12-25`)"
        result = parse_version_header(header)
        @test result.name == "1.0.0"
        @test result.date === Date("2024-12-25")
    end

    @testset "date $date_str" for date_str in [
            "2024-02-01",
            "February 1, 2024",
            "February 1 2024",
            "Feb 1, 2024",
            "Feb 1 2024",
            "1 February 2024",
            "1 February, 2024",
            "1 Feb 2024",
            "1 Feb, 2024",
        ]
        header = "v1.0.0 - $date_str"
        result = parse_version_header(header)
        @test result.name == "1.0.0"
        date = Changelog.findfirst_dateformat(date_str)
        @test result.date == date == Date("2024-02-01")
    end
end

@testset "parsefile" begin
    # Here we test some point-in-time examples. This is not intended to test anything about
    # JuMP itself (e.g. if it is keeping a consistently formatted changelog), but rather that we can parse
    # its changelog as of when this file was committed (Dec 2024), to test the parsing code on in-the-wild examples.
    @testset "JuMP changelog" begin
        jump = parsefile(test_path("jump.md"))
        # we parse dates for every entry
        @test isempty(filter(x -> x.date === nothing, jump.versions))
        # and find at least one change per version
        @test isempty(filter(x -> isempty(x.sectioned_changes) && isempty(x.toplevel_changes), jump.versions))
        # there are no URLs in the section headers, so we shouldn't find any
        @test isempty(filter(x -> !isnothing(x.url), jump.versions))
    end

    # Similarly we check that we can parse Documenter's changelog (as of Dec 2024).
    @testset "Documenter changelog" begin
        documenter = parsefile(test_path("documenter.md"))
        # we parse dates for every entry
        @test isempty(filter(x -> x.date === nothing, documenter.versions))
        # and find at least one change per version
        @test isempty(filter(x -> isempty(x.sectioned_changes), documenter.versions))
        # and we parse a URL for every version
        @test isempty(filter(x -> isnothing(x.url), documenter.versions))
    end

    @testset "v1.1 changelog" begin
        # Here we check in the changelog for this package as `v1.1.md`
        # This is a tricky one, as for v1.0.0, there are no bullet points (nor sections), only text.

        v1p1 = parsefile(test_path("v1.1.md"))
        # we parse dates for every entry
        @test isempty(filter(x -> x.date === nothing, v1p1.versions))
        # and find at least one change per version
        @test isempty(filter(x -> isempty(x.toplevel_changes) && isempty(x.sectioned_changes), v1p1.versions))
        # and we parse a URL for every version
        @test isempty(filter(x -> isnothing(x.url), v1p1.versions))
        @test length(v1p1.versions) == 2
        ver_1p1, ver_1p0 = v1p1.versions

        @test ver_1p1.version == "1.1.0"
        @test ver_1p1.url == "https://github.com/JuliaDocs/Changelog.jl/releases/tag/v1.1.0"
        @test ver_1p1.date == Date("2023-11-13")
        @test ver_1p1.sectioned_changes == ["Added" => ["Links of the form `[<commit hash>]`, where `<commit hash>` is a commit hashof length 7 or 40, are now linkified. (#4)"]]

        @test ver_1p0.version == "1.0.0"
        @test ver_1p0.url == "https://github.com/JuliaDocs/Changelog.jl/releases/tag/v1.0.0"
        @test ver_1p0.date == Date("2023-11-13")
        @test ver_1p0.toplevel_changes == ["First release. See README.md for currently supported functionality."]
    end

    # Next we check several quite similar changelogs which have some differences in formatting
    @testset "$file" for file in readdir(test_path("good"); join = true)
        c = parsefile(file)
        @test c.title == "Changelog"
        @test c.intro == "Intro"
        # All have these versions, in this order
        @test [v.version for v in c.versions] == ["Unreleased", "1.0.0"]
        unreleased = c.versions[1]
        v1 = c.versions[2]
        @test unreleased.date === nothing
        @test v1.date == Date("2024-12-25")
        @test !isempty(unreleased.sectioned_changes) || !isempty(unreleased.toplevel_changes)
        @test !isempty(v1.sectioned_changes) || !isempty(v1.toplevel_changes)
    end

    # Lastly, we check that we don't error on some "bad" examples,
    # which have e.g. inconsistent or missing headings
    @testset "$file" for file in readdir(test_path("bad"); join = true)
        c = parsefile(file)
        @test c.title == "Changelog"
    end
end
