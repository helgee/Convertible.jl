# Convertible

*Multi-step convert for Julia types.*

[![Build Status][travis-badge]][travis-link] [![Coverage Status][coveralls-badge]][coveralls-link] [![codecov.io][codecov-badge]][codecov-link]

This package provides the `isconvertible` trait that can be applied to struct type definitions via the `@convertible` macro.
Types that share this trait can be easily converted into one another with a single call to `Base.convert` even though multiple intermediate conversions might be required.

## Installation

The package can be installed through Julia's package manager:

```julia
Pkg.add("Convertible")
```

## Usage

Define convertible types:
```julia
# For Julia 0.5:
# @convertible immutable/type A
@convertible struct A
    val::Int
end

@convertible struct B
    val::Int
end

@convertible struct C
    val::Int
end

@convertible struct D
    val::Int
end
```

Define `Base.convert` methods:
```julia
Base.convert(::Type{B}, a::A) = B(a.val+1)
Base.convert(::Type{D}, a::A) = D(a.val+1)
Base.convert(::Type{C}, b::B) = C(b.val+1)
Base.convert(::Type{A}, c::C) = A(c.val-2)
```

Type `A` can now be converted to type `C` directly even though there is no direct `convert(::Type{C}, ::A)` available.
```julia
julia> a = A(1)
julia> @convert convert(C, a)
C(3)
```

Internally `Convertible.jl` will compute the shortest conversion path and emit a specialized method based on a generated function,
e.g. `convert(C, convert(B, a))` in this case.

As shown above, you need to opt-in to the new `convert` behaviour by wrapping calls to convert with the `@convert` macro, e.g.:

```julia
@convert begin
    b = convert(B, a)
    c = convert(C, a)
    a = convert(A, b)
    d = convert(D, b)
end
```

### Parametric Types

`@convertible` can only be used on non-parametric types.
It can be applied to type aliases without parameters, though.

```julia
type Param{T}
    val::T
end

# The pre-v0.6 `typealias` keyword is not supported.
@convertible const ParamFloat64 = Param{Float64}
@convertible const ParamInt = Param{Int}
@convertible const ParamUInt8 = Param{UInt8}

Base.convert(::Type{ParamInt}, p::ParamFloat64) = Param{Int}(p.val)
Base.convert(::Type{ParamUInt8}, p::ParamInt) = Param{UInt8}(p.val)
```

[travis-badge]: https://travis-ci.org/helgee/Convertible.jl.svg?branch=master
[travis-link]: https://travis-ci.org/helgee/Convertible.jl
[coveralls-badge]: https://coveralls.io/repos/helgee/Convertible.jl/badge.svg?branch=master&service=github
[coveralls-link]: https://coveralls.io/github/helgee/Convertible.jl?branch=master
[codecov-badge]: http://codecov.io/github/helgee/Convertible.jl/coverage.svg?branch=master
[codecov-link]: http://codecov.io/github/helgee/Convertible.jl?branch=master
