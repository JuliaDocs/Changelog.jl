@testset "find_changelog / find_version" begin
    path, cl = find_changelog(test_path("test_pkgs/TestPkg1"))
    @test endswith(path, "CHANGELOG.md")

    @testset "TestPkg1 query $(repr(query))" for query in ("1.0.0", "1.0", "1", v"1")
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
    @test find_version(cl, v"2.0") isa VersionInfo
    @test find_version(cl, "2.0") isa VersionInfo
    @test find_version(cl, "2.") isa VersionInfo
    @test find_version(cl, "2") isa VersionInfo

    @test find_changelog(test_path("test_pkgs/TestPkg3")) === nothing
    @test find_changelog(test_path("test_pkgs/TestPkg4")) === nothing
end
