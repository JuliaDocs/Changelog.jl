# Here we transform MarkdownAST trees into a new "MarkdownHeadingTree" which has slightly different semantics, with the goal that content under a heading in the markdown document is a _descendent_ of the corresponding `MarkdownHeadingTree`.
# Semantics:
# - Each `MarkdownAST.Heading` (and the `MarkdownAST.Document`) node maps to a `MarkdownHeadingTree` object
# - All other "top-level" elements (i.e. all children thereof) map to `Elt` objects
# - The children of `MarkdownHeadingTree`s are all the corresponding `Elt` objects as well as any `MarkdownHeadingTree` corresponding nested subheadings
# - The children of `Elt` objects are their usual children (deferring to MarkdownAST's notion of a child)
# Note therefore MarkdownAST's children of `MarkdownAST.Heading` objects are disconnected / not present in the final tree, since the headings are nodes themselves in this new tree.
# To access them, when necessary we will traverse `obj.heading_node` for `obj::MarkdownHeadingTree`,
# instead of traversing `obj`'s children.

# Generic "element"
struct Elt
    value::MarkdownAST.Node
end

# simply passes along children and values to MarkdownAST's definitions
AbstractTrees.children(n::Elt) = AbstractTrees.children(n.value)
AbstractTrees.nodevalue(n::Elt) = AbstractTrees.nodevalue(n.value)

# Heading or Document
struct MarkdownHeadingTree
    heading_node::MarkdownAST.Node # either MarkdownAST.Heading or MarkdownAST.Document elements
    level::Int # matches `heading_node.level` when heading, otherwise 0 for Document
    children::Vector{Union{Elt, MarkdownHeadingTree}}
end

Base.summary(io::IO, m::MarkdownHeadingTree) = print(io, MarkdownHeadingTree, "(level=$(m.level))")
# Passes to `n.children`, each of which has its own semantics (Elt or MarkdownHeadingTree)
AbstractTrees.children(n::MarkdownHeadingTree) = n.children
# the nodevalue is the MarkdownAST node itself (which itself has children, but they form a disconnected separate tree)
AbstractTrees.nodevalue(n::MarkdownHeadingTree) = AbstractTrees.nodevalue(n.heading_node)

# Main function: transform a node for MarkdownAST.Document into a MarkdownHeadingTree
function build_heading_tree(ast)
    if !(nodevalue(ast) isa MarkdownAST.Document)
        throw(ArgumentError("The initial node should be a `MarkdownAST.Document`"))
    end

    itr = PreOrderDFS(ast) do node
        # don't recurse into Headings
        nodevalue(node) isa MarkdownAST.Heading && return false
        # optimization: don't recurse into values which can't contain a heading
        # (the `seen` mechanism below should ensure correctness regardless of what we do here,
        #  but this can be prevent unnecessary traversal)
        MarkdownAST.can_contain(nodevalue(node), MarkdownAST.Heading(1)) || return false
        return true
    end
    # First we will build a flat list of *all* headings, with all content "within" the heading
    # as a child of that heading.
    flat = MarkdownHeadingTree[]
    # we will keep track of non-heading elements we have seen, so we can avoid adding
    # both a parent and its child which would cause extraneous edges in our tree
    seen = Set()
    for node in itr
        # we treat the Document as a special level-0 heading
        if nodevalue(node) isa MarkdownAST.Document
            push!(flat, MarkdownHeadingTree(node, 0, []))
        elseif nodevalue(node) isa MarkdownAST.Heading
            push!(flat, MarkdownHeadingTree(node, nodevalue(node).level, []))
        elseif isempty(flat)
            # This should not be possible, the first element should always be a document
            @assert false
        elseif AbstractTrees.parent(node) in seen
            # has a parent in the tree already; nothing to do
        else
            push!(flat[end].children, Elt(node))
            push!(seen, node)
        end
    end

    # Now we have a list of all markdown headers in order, e.g.
    # [Header 1, Header 2, Header 3]
    # but we want some of these to be children of others, e.g. for
    # ```markdown
    #    # Header 1
    #    abc
    #    ## Header 2
    #    def
    #    ## Header 3
    # ```
    # we should have Header 2/3 as children of Header 1, but Header 3 is not a child of Header 2.
    # We will do this as follows. Note theoretically we can have multiple "roots", but since
    # we treat the Document itself as a level-0 header, that should be the unique root.
    # We will write the logic generally, then assert there is only 1 root at the end.
    roots = MarkdownHeadingTree[]
    for i in eachindex(flat)
        current = flat[i]
        if i == 1
            push!(roots, current)
        else
            parent_idx = findlast(j -> flat[j].level < current.level, 1:(i - 1))
            if parent_idx === nothing
                push!(roots, current)
            else
                push!(flat[parent_idx].children, current)
            end
        end
    end

    return only(roots)
end
