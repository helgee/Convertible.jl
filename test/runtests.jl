using Convertible
using Base.Test
using Compat

#= import Base: convert =#
#=  =#
#= for name in 'A':'F' =#
#=     sym = Symbol(name) =#
#=     @eval begin =#
#=         @convertible type $sym =#
#=             val::Int =#
#=         end =#
#=     end =#
#= end =#
#=  =#
#= convert(::Type{B}, a::A) = B(a.val+1) =#
#= convert(::Type{D}, a::A) = B(a.val+1) =#
#= convert(::Type{C}, b::B) = C(b.val+1) =#
#= convert(::Type{A}, c::C) = A(c.val-2) =#
#= convert(::Type{F}, e::E) = F(e.val+1) =#
#=  =#
#= type Param{T} =#
#=     val::T =#
#= end =#
#=  =#
#= @convertible const ParamFloat64 = Param{Float64} =#
#= @convertible const ParamInt = Param{Int} =#
#= @convertible const ParamUInt8 = Param{UInt8} =#
#=  =#
#= convert(::Type{ParamInt}, p::ParamFloat64) = Param{Int}(p.val) =#
#= convert(::Type{ParamUInt8}, p::ParamInt) = Param{UInt8}(p.val) =#
#=  =#
#= @compat abstract type Blob end =#
#=  =#
#= @convertible immutable Foo <: Blob end =#
#= @convertible immutable Bar <: Blob end =#
#= @convertible immutable FooBar <: Blob end =#
#=  =#
#= convert(::Type{Bar}, ::Foo) = Bar() =#
#= convert(::Type{FooBar}, ::Bar) = FooBar() =#
#=  =#
#= (::Type{T}){T<:Blob, S<:Blob}(s::S) = @convert convert(T, s) =#
#=  =#
#= @testset "Convertible" begin =#
#=     @test macroexpand(:(@convertible 1.0)).head == :error =#
#=     @test macroexpand(:(@convertible type Foo{T} end)).head == :error =#
#=     @test macroexpand(:(@convertible f(x) = x)).head == :error =#
#=  =#
#=     g = Convertible.getgraph() =#
#=     @test g[A] == Set([B, D]) =#
#=     @test g[B] == Set([C]) =#
#=     @test isempty(g[D]) =#
#=     @test g[E] == Set([F]) =#
#=  =#
#=     # Node without outbound edges =#
#=     @test_throws ErrorException Convertible.findpath(g, D, B) =#
#=     # Disconnected regions =#
#=     @test_throws ErrorException Convertible.findpath(g, A, F) =#
#=  =#
#=     @test Convertible.findpath(g, A, C) == [B, C] =#
#=     @test Convertible.findpath(g, A, D) == [D] =#
#=     @test Convertible.findpath(g, B, A) == [C, A] =#
#=     @test Convertible.findpath(g, B, D) == [C, A, D] =#
#=  =#
#=     a = A(1) =#
#=     b = B(1) =#
#=     @convert begin =#
#=         @test convert(B, a).val ==  2 =#
#=         @test convert(C, a).val ==  3 =#
#=         @test convert(A, b).val ==  0 =#
#=         @test convert(D, b).val ==  1 =#
#=     end =#
#=  =#
#=     @test_throws MethodError convert(C, a) =#
#=  =#
#=     x = @convert convert(C, a) =#
#=     @test x.val == 3 =#
#=  =#
#=     p = Param(0.0) =#
#=     @test @convert Base.convert(Param{UInt8}, p).val == UInt8(0) =#
#=  =#
#=     f = Foo() =#
#=     @test isa(FooBar(f), FooBar) =#
#= end =#

abstract type AbstractFrame end

struct Frame1 <: AbstractFrame end
struct Frame2 <: AbstractFrame end
struct Frame3 <: AbstractFrame end
struct Frame4 <: AbstractFrame end

struct State{Frame} end

struct Rotation{From,To} <: Converter{From,To}
    a::Int
    b::Int
    c::Int
end

(::Rotation{From,To})(s::State{From}) where {From,To} = State{To}()

@convertible struct AType end
@convertible struct BType end
@convertible struct CType end
@convertible struct DType end

@convert function BType(a::AType)
    BType()
end
@convert function CType(a::BType)
    CType()
end
@convert function DType(a::BType)
    DType()
end

@convert function Rotation(origin::Frame1, target::Frame2, a, b, c)
    Rotation{origin,target}(a, b, c)
end

@convert function Rotation(origin::Frame2, target::Frame3, a, b, c)
    Rotation{origin,target}(a, b, c)
end

@convert function Rotation(origin::Frame2, target::Frame4, a, b, c)
    Rotation{origin,target}(a, b, c)
end

@testset "Convertible" begin
    @test DType(AType()) == DType()
    @test CType(AType()) == CType()

    s = State{Frame1()}()
    r = Rotation(Frame1(), Frame2(), 1, 2, 3)
    @test r(s) == State{Frame2()}()

    r = Rotation(Frame1(), Frame3(), 1, 2, 3)
    @test r(s) == State{Frame3()}()

    r = Rotation(Frame1(), Frame4(), 1, 2, 3)
    @test r(s) == State{Frame4()}()
end
