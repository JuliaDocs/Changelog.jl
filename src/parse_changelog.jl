#####
##### Parsing headings
#####

const HEADING_REGEX = let
    prefix = raw"^(?:[V|v]ersion)?v?" # can start with Version, or just "v", or not (or versionv)
    space = raw"\s*"
    name = space * raw"(?<name>.+?)" * space # a version "name" is anything
    df1 = raw"\d{4}-\d{2}-\d{2}" # matches yyyy-mm-dd
    df2 = raw"\w+ \d{1,2},? \d{4}" # matches Feb 1, 2024 or March 1, 2024 or March 1 2024
    df3 = raw"\d{1,2} \w+,? \d{4}" # matches 1 January 2024
    date = space * "(?<date>$df1|$df2|$df3)?" * space # match any date
    suffix = raw"$" # end of line
    Regex(string(prefix, name, raw"-?", date, suffix))
end

const DATE_FORMATS = (
    Dates.ISODateFormat,
    dateformat"U d, Y",
    dateformat"U d Y",
    dateformat"u d, Y",
    dateformat"u d Y",
    dateformat"d u Y",
    dateformat"d u, Y",
    dateformat"d U Y",
    dateformat"d U, Y",
)

function findfirst_dateformat(str, dateformats = DATE_FORMATS)
    for df in dateformats
        date = tryparse(Date, str, df)
        date === nothing || return date
    end
    return nothing
end

function replace_until_convergence(str, repl...)
    for _ in 1:1000
        newstr = replace(str, repl...)
        if newstr == str
            return str
        else
            str = newstr
        end
    end
    error("did not converge")
end

# Parse version header for name and date
function parse_version_header(str; header_regex = HEADING_REGEX, dateformats = DATE_FORMATS)
    header_text = replace_until_convergence(
        strip(str),
        r"\[(.*)\]" => s"\1",
        r"\((.*)\)" => s"\1",
        r"`(.*)`" => s"\1",
    )
    m = match(header_regex, header_text)
    if m === nothing
        return (; name = header_text, date = nothing)
    end
    date = m[:date]
    if date !== nothing
        date = findfirst_dateformat(date, dateformats)
    end
    return (; name = something(m[:name], header_text), date)
end

#####
##### Extracting text
#####

# Extract text content from a node
# should this be a markdown writer like https://github.com/JuliaDocs/MarkdownAST.jl/issues/18?
function text_content(node)
    if nodevalue(node) isa MarkdownAST.Text
        return nodevalue(node).text
    elseif !isempty(AbstractTrees.children(node))
        return join(text_content(child) for child in AbstractTrees.children(node))
    elseif nodevalue(node) isa MarkdownAST.Code
        return string("`", nodevalue(node).code, "`")
    else # are there any other nodes to deal with?
        # error(string(typeof(nodevalue(node)), ": ", nodevalue(node)))
        return ""
    end
end

#####
##### Tree traversal helpers
#####

function find_first_child(node, ::Type{T}) where {T}
    for x in AbstractTrees.children(node)
        if nodevalue(x) isa T
            return x
        end
    end
    return nothing
end

function filter_children(node, ::Type{T}) where {T}
    return Iterators.filter(AbstractTrees.children(node)) do x
        nodevalue(x) isa T
    end
end

function filter_tree(node, ::Type{T}) where {T}
    filter = node -> !(nodevalue(node) isa T) # don't recurse _into_ Ts
    return Iterators.filter(PreOrderDFS(filter, node)) do x
        nodevalue(x) isa T
    end
end

function find_first_tree(node, ::Type{T}) where {T}
    for x in PreOrderDFS(node)
        if nodevalue(x) isa T
            return x
        end
    end
    return nothing
end

function bullets_to_list(items)
    # If there were no bullets, just text, then combine them
    if all(x -> nodevalue(x) isa MarkdownAST.Text, items)
        return [join((text_content(x) for x in items), " ")]
    else
        return [text_content(x) for x in items]
    end
end

#####
##### Main parsing code
#####

# see `SimpleLog.jl` for the API entrypoints (`Base.parse` and `parsefile`)
function _parse_simplelog(ast::MarkdownAST.Node)
    # convert into a "MarkdownHeadingTree" where elements of a section are children of the section
    root = build_heading_tree(ast)
    # Now, we have a tree where content under a heading in the markdown document is a descendent
    # of the corresponding `MarkdownHeadingTree` object in the tree.
    # content which was a child of the heading itself (e.g. the text within the heading)
    # is disconnected from the main tree, and is only reachable by traversing `x.heading_node` for `x::MarkdownHeadingTree`

    # debug
    # print_tree(root; maxdepth=20)

    # build the changelog
    @assert root.level == 0

    # find highest-level header in document
    top_header = find_first_tree(root, MarkdownAST.Heading)

    title = text_content(top_header.heading_node) # reach into the heading node to get the actual contenxt

    # Now back to the "main" tree, look for the first paragraph under the top-heading to get an "intro"
    intro_para = find_first_child(top_header, MarkdownAST.Paragraph)
    intro = isnothing(intro_para) ? nothing : text_content(intro_para)

    # Now we will parse the versions. We assume each heading below the top-heading is a separate version.
    versions = VersionInfo[]
    for version_section in filter_children(top_header, MarkdownAST.Heading)
        # try to parse the version "name" (could be version number, or "Unreleased" etc) and date
        version, date = parse_version_header(text_content(version_section.heading_node))
        # if we couldn't get the name, then skip. But allow missing date.
        version === nothing && continue

        # See if we have a link for this version by checking for a text node with the same content as the version name
        # here we check within the heading node itself (so the link is in the heading, not below it)
        links = Iterators.filter(filter_tree(version_section.heading_node, MarkdownAST.Link)) do link
            c = find_first_child(link, MarkdownAST.Text)
            # Note: here we use contains, as we have processed version names by removing `v`'s, quoting, etc.
            # However we don't add anything, so `contains` should be true. We are also only searching within the heading itself
            # (not content below the heading), so I don't expect there to be multiple links that all contain the version name/number, where
            # the first one is not the correct one.
            return !isnothing(c) && contains(nodevalue(c).text, version)
        end
        version_url = isempty(links) ? nothing : nodevalue(first(links)).destination

        # Now let us formulate the changelog for this version
        # We may have subsections or just a flat list of changes
        changes = OrderedDict{String, Vector{String}}()
        seen = Set()
        for subsection in filter_children(version_section, MarkdownAST.Heading)
            subsection_name = text_content(subsection.heading_node)
            # Note: `filter_tree` doesn't recurse into the types we are looking for, so
            # here if there is an item, we will choose that one (and not the text contained in it),
            # and if we hit a text, we know it's not contained in an item that we are also pulling out.
            items = filter_tree(subsection, Union{MarkdownAST.Item, MarkdownAST.Text})
            union!(seen, items)
            changes[subsection_name] = bullets_to_list(items)
        end
        # see if there were items not within a subsection
        other_items = setdiff(filter_tree(version_section, Union{MarkdownAST.Item, MarkdownAST.Text}), seen)
        general = filter!(!isempty, bullets_to_list(other_items))
        if !isempty(general)
            # if we had subsections already, we'll make an artificial new subsection called "General"
            if !isempty(changes)
                k = "General"
                while haskey(changes, k) # make the key uniuqe
                    k *= "_"
                end
                changes[k] = general
            else
                # otherwise, we will skip the subsections and have a flat list
                changes = general
            end
        end

        push!(versions, VersionInfo(version, version_url, date, changes))
    end
    return SimpleLog(title, intro, versions)
end
