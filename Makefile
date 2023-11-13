changelog:
	julia --project -e 'using Changelog; Changelog.generate(Changelog.CommonMark(), "CHANGELOG.md"; repo = "JuliaDocs/Changelog.jl")'
