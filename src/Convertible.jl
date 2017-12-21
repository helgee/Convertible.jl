__precompile__()

module Convertible

using ItemGraphs
using MacroTools

import Base: ∘

export @convertible, @convert, Converter

const registry = ItemGraph{Any}();

abstract type AbstractConverter end
abstract type Converter{From,To} <: AbstractConverter end

origin(::Converter{From,To}) where {From,To} = From
target(::Converter{From,To}) where {From,To} = To

struct ComposedConverter{C1<:AbstractConverter,C2<:AbstractConverter} <: AbstractConverter
    conv1::C1
    conv2::C2
end

(conv::ComposedConverter)(args...) = conv.conv2(conv.conv1(args...))

origin(conv::ComposedConverter) = origin(conv.conv1)
target(conv::ComposedConverter) = target(conv.conv2)

function ∘(conv1::Converter{From,Via}, conv2::Converter{Via,To}) where {From,Via,To}
    ComposedConverter(conv1, conv2)
end

function ∘(conv1::Converter{From,Via1}, conv2::Converter{Via2,To}) where {From,Via1,Via2,To}
    throw(ArgumentError("The output type of the first converter is '$Via1' while the input type of the
            second converter is '$Via2'. These must match."))
end

function (::Type{T})(from, to, args...) where {T<:Converter}
    path = getpath(registry, from, to)
    _converter(T, args, path...)
end

@generated function _converter(T, args, path...)
    ex = :($T.parameters[1]($(path[1])(), $(path[2])(), args...))
    for i in eachindex(path[2:end-1])
        t1 = path[i+1]
        t2 = path[i+2]
        ex = :(ComposedConverter($ex, $T.parameters[1]($t1(), $t2(), args...)))
    end
    ex
end

isconvertible(::Type{T}) where {T} = false

function _convert(::Type{T}, obj::S, ::Type{Val{true}}) where {T,S}
    path = getpath(registry, S, T)
    __convert(obj, path[2:end]...)
end

function _convert(::Type{T}, obj::S, ::Type{Val{false}}) where {T,S}
    throw(ArgumentError("Input type '$S' is not convertible."))
end

@generated function __convert(obj, path...)
    ex = :(obj)
    for p in path
        ex = :($p.parameters[1]($ex))
    end
    ex
end

macro convert(expr::Expr)
    def = splitdef(expr)
    name = def[:name]
    args = def[:args]
    if length(args) == 1
        length(args) != 1 && throw(ArgumentError("Constructor must have a single argument."))
        _, origin, _ = splitarg(args[1])
        return quote
            add_edge!(registry, $(esc(origin)), $(esc(name)))
            $(esc(expr))
        end
    elseif length(args) >= 2
        _, origin, _ = splitarg(args[1])
        _, target, _ = splitarg(args[2])
        return quote
            if !($(esc(name)) <: Converter)
                name = string($(esc(name)))
                throw(ArgumentError("'$name' is not a subtype of 'Converter'."))
            end
            add_edge!(registry, $(esc(origin))(), $(esc(target))())
            $(esc(expr))
        end
    else
        throw(ArgumentError("@convert must be used on single-argument or converter constructor."))
    end
end

macro convertible(expr::Expr)
    @capture(expr, struct T_ fields__ end) || throw(ArgumentError("Expected a struct definition."))
    return quote
        $expr
        Convertible.isconvertible(::Type{$(esc(T))}) = true
        $(esc(T))(obj::S) where {S} = _convert($(esc(T)), obj, Val{isconvertible(S)})
        nothing
    end
end

end # module
