using Changelog: VersionInfo, SimpleChangelog, OrderedDict, tryparsefile
@testset "VersionInfo and SimpleChangelog printing" begin
    v = VersionInfo("1.0.0", nothing, Date("2024-12-27"), ["One change"], OrderedDict("Section" => ["c1"]))
    v_str = repr("text/plain", v)
    @test contains(v_str, "- version: 1.0.0")
    @test contains(v_str, "- date: 2024-12-27")
    @test contains(v_str, "- One change")
    @test contains(v_str, "Section")
    @test contains(v_str, "- c1")

    c = SimpleChangelog("title", "intro", [v])
    c_str = repr("text/plain", c)
    @test contains(c_str, "- title: title")
    @test contains(c_str, "- intro: intro")
    @test contains(c_str, "- 1 version:")
    @test contains(c_str, "- date: 2024-12-27")

    c = SimpleChangelog("title", "intro", fill(v, 10))
    # Only show newest 5 versions
    c_str = repr("text/plain", c)
    @test contains(c_str, "⋮")
    @test contains(c_str, "- 10 versions:")
    @test count("- 1.0.0", c_str) == 5
end

@testset "tryparse" begin
    @test tryparse(SimpleChangelog, "") === nothing
    @test tryparsefile(test_path("empty.md")) === nothing
end
