
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
        # note we pass the whole thing as the name
        # I guess that's alright?
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
        "1 Feb, 2024"
    ]
        header = "v1.0.0 - $date_str"
        result = parse_version_header(header)
        @test result.name == "1.0.0"
        date = Changelog.findfirst_dateformat(date_str)
        @test result.date == date == Date("2024-02-01")
    end
end

@testset "parsefile" begin
    jump = parsefile(test_path("jump.md"))
    # we parse dates for every entry
    @test isempty(filter(x -> x.date === nothing, jump.versions))
    # and find at least one change per version
    @test isempty(filter(x -> isempty(x.changes), jump.versions))
    # there are no URLs in the section headers, so we shouldn't find any
    @test isempty(filter(x -> !isnothing(x.url), jump.versions))

    documenter = parsefile(test_path("documenter.md"))
    # we parse dates for every entry
    @test isempty(filter(x -> x.date === nothing, documenter.versions))
    # and find at least one change per version
    @test isempty(filter(x -> isempty(x.changes), documenter.versions))
    # and we parse a URL for every version
    @test isempty(filter(x -> isnothing(x.url), documenter.versions))

    @testset "good" begin
        for file in readdir(test_path("good"); join=true)
            println(file)
            c = parsefile(file)
            # parse at least 1 date (some are missing)
            @test !isempty(filter(x -> x.date !== nothing, c.versions))
            # find changes for each entry
            @test isempty(filter(x -> isempty(x.changes), c.versions))

        end
    end

    @testset "bad" begin
        for file in readdir(test_path("bad"); join=true)
            parsefile(file)
        end
    end
end
