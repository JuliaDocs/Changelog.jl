# https://github.com/JuliaLang/Compat.jl/blob/8819abe252579b610cb48c5ad83d51b45a90ddba/src/Compat.jl#L86-L94
# https://github.com/JuliaLang/julia/pull/40729
if VERSION < v"1.7.0-DEV.1088"
    macro something(args...)
        expr = :(nothing)
        for arg in reverse(args)
            expr = :((val = $arg) !== nothing ? val : $expr)
        end
        return esc(:(something(let val; $expr; end)))
    end
end
