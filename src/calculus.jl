#   This file is part of Reduce.jl. It is licensed under the MIT license
#   Copyright (C) 2017 Michael Reed

calculus = Symbol[
    :df,
    :int
]

:(export $(calculus...)) |> eval
:(export $(Symbol.("@",calculus)...)) |> eval

for fun in calculus
    parsegen(fun,:calculus) |> eval
    unfoldgen(fun,:calculus) |> eval
    @eval begin
        function $fun(expr::Compat.String,s...;be=0)
            convert(Compat.String, $fun(RExpr(expr),s...;be=be))
        end
        macro $fun(expr)
            :($$(QuoteNode(fun))($(esc(expr))))
        end
    end
end
