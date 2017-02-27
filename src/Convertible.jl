module Convertible

import Base: convert
import Iterators: product
import DataStructures: PriorityQueue, enqueue!, unshift!, dequeue!

export @convertible, isconvertible

const nodes = Set{DataType}()

macro convertible(ex)
    if typeof(ex) == Expr && typeof(ex) != Symbol && ex.head == :type
        typ = ex.args[2]
    else
        error("@convertible must be used on a type definition.")
    end
    return quote
        $ex
        Convertible.isconvertible(::Type{$(esc(typ))}) = true
        push!(Convertible.nodes, $(esc(typ)))
        nothing
    end
end

isconvertible{T}(::Type{T}) = false

convert{T}(::Type{T}, obj, ::Type{Val{false}}, ::Type{Val{false}}) = convert(T, obj)
convert{T}(::Type{T}, obj, ::Type{Val{true}}, ::Type{Val{true}}) = _convert(T, obj)
convert{T,S}(::Type{T}, obj::S) = convert(T, obj, Val{isconvertible(T)}, Val{isconvertible(S)})

function graph()
    g = Dict{DataType,Set{DataType}}(t => Set{DataType}() for t in nodes)
    for (ti, tj) in product(nodes, nodes)
        ti == tj && continue

        m = methods(convert, (Type{tj}, ti))
        # Dirty hack to determine if the method isn't the generic fallback
        if !isempty(m) && m.ms[1].module != Convertible
            push!(g[ti], tj)
        end
    end
    return g
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
        for n in graph[node]
            if !haskey(links, n)
                push!(queue, n)
                merge!(links, Dict{DataType, DataType}(n=>node))
            end
        end
    end
    if haskey(links, target)
        haspath = true
    end
    return haspath
end

function findpath(origin, target)
    g = graph()
    if isempty(g[origin])
        error("There are no convert methods with source type '$origin' defined.")
    end
    if !haspath(g, origin, target)
        error("No conversion path '$origin' -> '$target' found.")
    end
    queue = PriorityQueue(DataType, Int)
    prev = Dict{DataType,Nullable{DataType}}()
    distance = Dict{DataType, Int}()
    for node in keys(g)
        merge!(prev, Dict(node=>Nullable{DataType}()))
        merge!(distance, Dict(node=>typemax(Int)))
        enqueue!(queue, node, distance[node])
    end
    distance[origin] = 0
    queue[origin] = 0
    visited = DataType[]
    while !isempty(queue)
        node = dequeue!(queue)
        for n in g[node]
            alt = distance[node] + 1
            if alt < distance[n]
                distance[n] = alt
                prev[n] = Nullable(node)
                queue[n] = alt
            end
            if n == target
                break
            end
        end
    end
    path = DataType[]
    n = target
    while !isnull(prev[n])
        unshift!(path, n)
        n = get(prev[n])
    end
    return path
end

function __convert(T, S, obj)
    ex = :(obj)
    path = findpath(S, T)
    for t in path
        ex = :(convert($t, $ex))
    end
    return :($ex)
end

@generated function _convert{T,S}(::Type{T}, obj::S)
    __convert(T, S, obj)
end

end # module
