# Struct to represent version information
struct VersionInfo
    version::Union{Nothing, String}
    url::Union{Nothing, String}
    date::Union{Nothing, Date}
    changes::Union{OrderedDict{String, Vector{String}}, Vector{String}}
end
function Base.show(io::IO, ::MIME"text/plain", v::VersionInfo)
    return full_show(io, v)
end

function full_show(io, v::VersionInfo; indent = 0, showtype = true)
    pad = " "^indent
    if showtype
        print(io, pad, VersionInfo, " with")
        print(io, pad, "\n- version: ", v.version)
    else
        print(io, pad, "- ", v.version)
        pad *= "  "
    end
    print(io, "\n", pad, "- url: ", v.url)
    print(io, "\n", pad, "- date: ", v.date)
    changes = v.changes
    return if isempty(changes)
        print(io, "\n", pad, "- and no documented changes")
    elseif changes isa OrderedDict
        print(io, "\n", pad, "- changes")
        for (section_name, bullets) in pairs(changes)
            print(io, "\n", pad, "  - $section_name")
            for b in bullets
                print(io, "\n", pad, "    - $b")
            end
        end
    else
        print(io, "\n", pad, "- changes")
        for b in changes
            print(io, "\n", pad, "  - $b")
        end
    end
end

struct Changelog_
    title::Union{Nothing, String}
    intro::Union{Nothing, String}
    url::Union{Nothing, String}
    versions::Vector{VersionInfo}
end

function Base.show(io::IO, mime::MIME"text/plain", c::Changelog_)
    print(io, Changelog_, " with")
    print(io, "\n- title: ", c.title)
    print(io, "\n- intro: ", c.intro)
    print(io, "\n- url: ", c.url)
    print(io, "\n- versions:")
    for v in c.versions
        print(io, "\n")
        full_show(io, v; showtype = false, indent = 2)
    end
    return
end

function Base.parse(::Type{Changelog_}, text::AbstractString)
    # parse into CommonMark AST
    parser = CM.Parser()
    CM.enable!(parser, CM.FootnoteRule())
    ast = parser(text)
    # convert to MarkdownAST AST
    ast = md_convert(MarkdownAST.Node, ast)
    return _parse_changelog(ast) # see parse_changelog.jl
end

function parsefile(path)
    return parse(Changelog_, read(path, String))
end
