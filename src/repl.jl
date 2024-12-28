using Pkg: REPLMode, Operations, API
using Markdown
using .REPLMode: PSA
using Pkg.Types: Context
using Pkg.Operations: source_path
using .API: handle_package_input!, update_source_if_set
using Pkg
using Changelog
function find_changelog(dir)
    for name in ("CHANGELOG.md", "CHANGELOG", "NEWS", "NEWS.md")
        path = joinpath(dir, name)
        isfile(path) || continue
        parsed = Changelog.parsefile(path)
        if !isempty(parsed.versions)
            return parsed
        end
    end
    return nothing
end

function show_args(pkgs::Vector{Pkg.Types.PackageSpec}; kwargs...)
    ctx = Context()
    pkgs = deepcopy(pkgs) # don't mutate input
    foreach(handle_package_input!, pkgs)

    Operations.update_registries(ctx; force=false, update_cooldown=Day(1))
    API.project_deps_resolve!(ctx.env, pkgs)
    API.registry_resolve!(ctx.registries, pkgs)
    API.stdlib_resolve!(pkgs)
    API.ensure_resolved(ctx, ctx.env.manifest, pkgs, registry=true)
    preserve=Pkg.PRESERVE_ALL
    resolved_pkgs, deps_map = Pkg.Operations.targeted_resolve_up(ctx.env, ctx.registries, pkgs, preserve, ctx.julia_version)
    uuids = Set(pkg.uuid for pkg in pkgs)
    filter!(resolved_pkgs) do pkg
        pkg.uuid in uuids
    end
    for pkg in resolved_pkgs
        update_source_if_set(ctx.env.project, pkg)
        path = source_path(ctx.env.manifest_file, pkg, ctx.julia_version)
        cl = find_changelog(path)
        if cl === nothing
            @warn "No changelog found for $(pkg.name) [$(pkg.uuid)]"
            continue
        end
        # show(stdout, MIME"text/plain"(), cl)
        # @show string("v", pkg.version)
        # @show keys(cl.versions)
        # TODO- more robust
        v_lookup = Dict(v.version => v for v in cl.versions)
        if string("v", pkg.version) in keys(v_lookup)
            ver = v_lookup[string("v", pkg.version)]
            show(stdout, MIME"text/plain"(), ver)
            println(stdout)
        end
        # @show pkg path
        # @show  pkg path
    end
    return nothing
end

spec = PSA[:name => "changelog",
    :short_name => "cl",
    :api => show_args,
    :should_splat => false,
    :arg_count => 0 => Inf,
    :arg_parser => REPLMode.parse_package,
    :option_spec => [
        PSA[:name => "diff", :short_name => "d", :api => :diff => true],
    ],
    :completions => :complete_installed_packages,
    :description => "show the changelog for a package",
    :help => md"""
    [cl|changelog] [-d|--diff] [pkgs...]

Description
""",
]

spec = Pkg.REPLMode.CommandSpec(; spec...)
Pkg.REPLMode.SPECS["package"]["changelog"] = spec
Pkg.REPLMode.SPECS["package"]["cl"] = spec
