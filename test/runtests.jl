using Convertible
using Base.Test
using Compat

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
