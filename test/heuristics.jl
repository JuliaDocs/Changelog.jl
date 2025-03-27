@testset "find_changelog / find_version" begin
    path, cl = find_changelog(test_path("test_pkgs/TestPkg1"))
    @test endswith(path, "CHANGELOG.md")

    # note: latest gives us 1.0.0 since it is the first entry.
    # we can't count on all version numbers being semver parsable so we can't go by semver ordering.
    @testset "TestPkg1 query $(repr(query))" for query in ("1.0.0", "1.0", "1", v"1", :latest)
        v = find_version(cl, query)
        @test v isa VersionInfo
        @test "one point oh point oh" in v.toplevel_changes
    end

    @testset "TestPkg1 query $(repr(query))" for query in ("1.1", v"1.1", "1.1.0")
        v = find_version(cl, query)
        @test v isa VersionInfo
        @test "one point one" in v.toplevel_changes
    end
    path, cl = find_changelog(test_path("test_pkgs/TestPkg2"))
    @test endswith(path, "changelog.md")

    # here `:latest` gives us v2.0 since it has the most recent date, even though
    # it is not the first entry on on the changelog
    @testset "TestPkg2 query $(repr(query))" for query in (v"2.0", "2.0", "2.", "2", :latest)
        v = find_version(cl, query)
        @test v isa VersionInfo
        @test "v2" in v.toplevel_changes
    end

    @testset "TestPkg2 query $(repr(query))" for query in (v"3.0", "3", "3.0.0")
        v = find_version(cl, query)
        @test v isa VersionInfo
        @test "v3" in v.toplevel_changes
    end

    @test find_version(cl, "30") === nothing
    @test find_version(cl, "3x") === nothing
    @test find_version(cl, "03") === nothing

    @test find_changelog(test_path("test_pkgs/TestPkg3")) === nothing
    @test find_changelog(test_path("test_pkgs/TestPkg4")) === nothing
end
