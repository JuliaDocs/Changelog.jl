# Changelog.jl

Changelog.jl is a Julia package for managing changelogs.

## Installation

Install using Julias package manager:
```julia
pkg> add Changelog
```

## Documentation

The core idea of this package is to make it convenient to write changelog entries with
references to pull requests/issues and let Changelog.jl generate the full URLs.

The typical workflow is as follows:
1. Write a changelog entry in the changelog file (e.g. `CHANGELOG.md`):
   ```
   - Description of new feature with reference to pull request ([#123]).
   ```
2. Run the command
   ```julia
   Changelog.generate(
       Changelog.CommonMark(),          # output type
       "CHANGELOG.md";                  # input and output file
       repo = "JuliaDocs/Changelog.jl", # default repository for links
   )
   ```
   This scans the input for link tokens, generates the full URLs, and inserts a link list at
   the bottom. A tip is to add the command above as a Makefile target. The output would be
   ```
   - Description of new feature with reference to pull request ([#123]).

   <!-- Links generated by Changelog.jl -->
   [#123]: https://github.com/JuliaDocs/Changelog.jl/issues/123
   ```
3. Commit the result.
4. Run the following command to integrate the changelog into documentation built with
   [Documenter](https://github.com/JuliaDocs/Documenter.jl):
   ```julia
   # In docs/make.jl, before makedocs(...)
   Changelog.generate(
       Changelog.Documenter(),                 # output type
       joinpath(@__DIR__, "../CHANGELOG.md"),  # input file
       joinpath(@__DIR__, "src/CHANGELOG.md"); # output file
       repo = "JuliaDocs/Changelog.jl",        # default repository for links
   )
   ```
   The output in would be
   ```
   - Description of new feature with reference to pull request
     ([#123](https://github.com/JuliaDocs/Changelog.jl/issues/123)).
   ```

### Parsing changelogs

Changelog also provides functionality for parsing changelogs into a simple structure which can be programmatically queried,
e.g. to check what the changes are for a particular version. The API for this functionality consists of:

- `SimpleLog`: structure that contains a simple representation of a changelog.
- `VersionInfo`: structure that contains a simple representation of a version in a changelog.
- `Base.parse(SimpleLog, str)`: parse a markdown-formatted string into a `SimpleLog`
- `Changelog.parsefile`: parses a markdown-formatted file into a `SimpleLog`

For example, using `Changelog.parsefile` on the [CHANGELOG.md](./CHANGELOG.md) as of version 1.1 gives:

```julia
julia> changelog = Changelog.parsefile("CHANGELOG.md")
SimpleLog with
- title: Changelog.jl changelog
- intro: All notable changes to this project will be documented in this file.
- 2 versions:
  - 1.1.0
    - url: https://github.com/JuliaDocs/Changelog.jl/releases/tag/v1.1.0
    - date: 2023-11-13
    - changes
      - Added
        - Links of the form `[<commit hash>]`, where `<commit hash>` is a commit hashof length 7 or 40, are now linkified. (#4)
  - 1.0.0
    - url: https://github.com/JuliaDocs/Changelog.jl/releases/tag/v1.0.0
    - date: 2023-11-13
    - changes
      - First release. See README.md for currently supported functionality.
```

The changes for 1.1.0 can be obtained by `log.versions[1].changes`:

```julia
julia> changelog.versions[1].changes
OrderedCollections.OrderedDict{String, Vector{String}} with 1 entry:
  "Added" => ["Links of the form `[<commit hash>]`, where `<commit hash>` is a commit hashof length 7 or 40, are now linkified. (#4)"]
```
