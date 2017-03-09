module Convertible

import Base: convert, function_module
import DataStructures: PriorityQueue, enqueue!, unshift!, dequeue!

export @convertible, @convert, isconvertible

const nodes = Set{DataType}()

"""
    @convertible

`@convertible <type-def>` adds the `isconvertible` trait to the (struct) type defined in `<type-def>`.
"""
macro convertible(ex)
    if !isa(ex, Expr) || (isa(ex, Expr) && !(ex.head in (:type, :const)))
        error("@convertible must be used on a type or alias definition.")
    end
    if ex.head == :type
        typ = ex.args[2]
        if isa(typ, Expr)
            if typ.head == :curly
                error("@convertible cannot be used on parametric types. "
                    * "Use it on an alias without free parameters instead.")
            else
                typ = typ.args[1]
            end
        end
    elseif ex.head == :const
        typ = ex.args[1].args[1]
    end

    return quote
        $(esc(ex))
        Convertible.isconvertible(::Type{$(esc(typ))}) = true
        push!(Convertible.nodes, $(esc(typ)))
        nothing
    end
end

"""
    @convert

`@convert <expr>` enables multi-step conversion for all calls to `convert` in `<expr>`.
"""
macro convert(ex)
    recursive_replace!(ex, :(Base.convert), :(Convertible._convert))
    recursive_replace!(ex, :convert, :(Convertible._convert))
    :($(esc(ex)))
end

function recursive_replace!(ex, old::Expr, new)
    if isa(ex, Expr) && !isempty(ex.args)
        for (i, expr) in enumerate(ex.args)
            if (isa(expr, Expr) && expr.head == :.
                && Symbol(expr.args) == Symbol(old.args))
                ex.args[i] = new
            else
                recursive_replace!(ex.args[i], old, new)
            end
        end
    end
end

function recursive_replace!(ex, old::Symbol, new)
    if isa(ex, Expr) && !isempty(ex.args)
        for (i, expr) in enumerate(ex.args)
            if isa(expr, Symbol) && expr == old
                ex.args[i] = new
            else
                recursive_replace!(ex.args[i], old, new)
            end
        end
    end
end

isconvertible{T}(::Type{T}) = false

_convert{T,S}(::Type{T}, obj::S) = _convert(T, obj, Val{isconvertible(T)}, Val{isconvertible(S)})
_convert{T}(::Type{T}, obj, ::Type{Val{true}}, ::Type{Val{true}}) = __convert(T, obj)
_convert{T}(::Type{T}, obj, ::Type{Val{false}}, ::Type{Val{false}}) = convert(T, obj)

function getgraph()
    graph = Dict{DataType,Set{DataType}}(t => Set{DataType}() for t in nodes)
    for ti in nodes
        for tj in nodes
            ti == tj && continue

            m = methods(convert, (Type{tj}, ti))
            isempty(m) && continue

            if function_module(convert, (Type{tj}, ti)) != Convertible
                push!(graph[ti], tj)
            end
        end
    end
    return graph
end

function haspath(graph, origin, target)
    haspath = false
    queue = [origin]
    links = Dict{DataType, DataType}()
    while !isempty(queue)
        node = shift!(queue)
        if node == target
            break
        end
        for neighbour in graph[node]
            if !haskey(links, neighbour)
                push!(queue, neighbour)
                merge!(links, Dict{DataType, DataType}(neighbour=>node))
            end
        end
    end
    if haskey(links, target)
        haspath = true
    end
    return haspath
end

function findpath(origin, target)
    graph = getgraph()
    if isempty(graph[origin])
        error("There are no convert methods with source type '$origin' defined.")
    end
    if !haspath(graph, origin, target)
        error("No conversion path '$origin' -> '$target' found.")
    end
    queue = PriorityQueue(DataType, Int)
    prev = Dict{DataType,Nullable{DataType}}()
    distance = Dict{DataType, Int}()
    for node in keys(graph)
        merge!(prev, Dict(node=>Nullable{DataType}()))
        merge!(distance, Dict(node=>typemax(Int)))
        enqueue!(queue, node, distance[node])
    end
    distance[origin] = 0
    queue[origin] = 0
    while !isempty(queue)
        node = dequeue!(queue)
        node == target && break
        for neighbour in graph[node]
            alt = distance[node] + 1
            if alt < distance[neighbour]
                distance[neighbour] = alt
                prev[neighbour] = Nullable(node)
                queue[neighbour] = alt
            end
        end
    end
    path = DataType[]
    current = target
    while !isnull(prev[current])
        unshift!(path, current)
        current = get(prev[current])
    end
    return path
end

function gen_convert(T, S, obj)
    ex = :(obj)
    path = findpath(S, T)
    for t in path
        ex = :(convert($t, $ex))
    end
    return :($ex)
end

@generated function __convert{T,S}(::Type{T}, obj::S)
    gen_convert(T, S, obj)
end

end # module
