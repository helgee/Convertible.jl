using Convertible
using Base.Test

import Base: convert

for name in 'A':'F'
    sym = Symbol(name)
    @eval begin
        @convertible type $sym
            val::Int
        end
    end
end


convert(::Type{B}, a::A) = B(a.val+1)
convert(::Type{D}, a::A) = B(a.val+1)
convert(::Type{C}, b::B) = C(b.val+1)
convert(::Type{A}, c::C) = A(c.val-2)
convert(::Type{F}, e::E) = F(e.val+1)

type Param{T}
    val::T
end

@convertible const ParamFloat64 = Param{Float64}
@convertible const ParamInt = Param{Int}
@convertible const ParamUInt8 = Param{UInt8}

convert(::Type{ParamInt}, p::ParamFloat64) = Param{Int}(p.val)
convert(::Type{ParamUInt8}, p::ParamInt) = Param{UInt8}(p.val)

@testset "Convertible" begin
    g = Convertible.graph()
    @test g[A] == Set([B, D])
    @test g[B] == Set([C])
    @test isempty(g[D])
    @test g[E] == Set([F])

    # Node without outbound edges
    @test_throws ErrorException Convertible.findpath(D, B)
    # Disconnected regions
    @test_throws ErrorException Convertible.findpath(A, F)

    @test Convertible.findpath(A, C) == [B, C]
    @test Convertible.findpath(A, D) == [D]
    @test Convertible.findpath(B, A) == [C, A]
    @test Convertible.findpath(B, D) == [C, A, D]

    a = A(1)
    b = B(1)
    @test convert(B, a).val ==  2
    @test convert(C, a).val ==  3
    @test convert(A, b).val ==  0
    @test convert(D, b).val ==  1

    # Check that Base.convert still works.
    @test convert(Int, 4.0) == 4

    p = Param(0.0)
    @test convert(Param{UInt8}, p).val == UInt8(0)
end
