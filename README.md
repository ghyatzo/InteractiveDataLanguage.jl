# IDL interface for the Julia language

The `InteractiveDataLanguage.jl` package is a wrapper for the IDL C API for calling IDL from the Julia language. Any IDL code will need to be provided by the users.
Users are also expected to have a valid licensed Installation of the IDL library in their system, which must be obtained separately.
This package also assumes your license is correctly set up and provides no functionality nor instructions on how to set up an IDL installation, refer to the official IDL documentation instead.

> [!CAUTION]
> This package is still in the experimental phase, expect frequent changes.

This package started with an attempt to revive the code from [this package](https://github.com/henry2004y/IDL.jl) which was a fork of [this other package](https://github.com/BobPortmann/InteractiveDataLanguage.jl). But it turned into a complete rewrite.

## Installation

Within Julia, use the package manager:
```julia
] add InteractiveDataLanguage
```

> [!NOTE]
> `IDL.jl` should find and load the IDL library automatically. It has not been tested on Mac and/or Linux so please file an issue if you encounter errors. For the automatic discovery IDL should be in the PATH.

IDL can be called externally using either the `RPC` or `Callable` interface.
This library opted to only support the `Callable` IDL interface due to better ergonomics
and power when managing memory between IDL and Julia.

## TODO
Currently the package is in very early stages of development, the API is still in the process of being ironed out. Any kind of feedback is welcome!

Current support:
- [x] Scalars
	- [x] IDL -> Julia
	- [x] Julia -> IDL
	- [x] Create temporary variables
- [x] Arrays
	- [x] IDL -> Julia (No copy data)
	- [x] IDL -> Julia (Copy data)
	- [x] Julia -> IDL (No copy data)
	- [x] Julia -> IDL (Copy data)
	- [x] Initialize IDL arrays from Julia
	- [x] Create temporary arrays
- [ ] Structures
	- [ ] IDL -> Julia
	- [ ] Julia -> IDL
- [ ] Objects

Extras:
- [ ] REPL Mode (`IDL>` prompt)
- [ ] `@idl_str` macro
- [ ] automatic interpolation of variables from julia and idl

Currently the package provides the bare minimum to have some basic interaction between IDL and julia.

For the time being, most shortcomings of the current API can be overcome by using the `idlrun` functionality, by grafting a valid IDL string to be `eval`'d by the IDL runtime.

# Quickstart

```julia
using InteractiveDataLanguage
```
Once the package is loaded, it will automatically acquire a license. The license is bound to the current julia process. To drop the licence close the julia process.

Create a variable in IDL and get an handle to it from Julia:
```julia
idlrun("x = 10LL") # LL creates an Int64

x = idlvar(:x)
```
Instead you can initialize a new (or exising) variable with a value directly from Julia
```julia
y = idlvar(:y, 20)
```
Look at the value held by the IDL variable
```julia
@assert x[] == y[] - 10
@assert 2 * jlscalar(x) == jlscalar(y)
```

Specify the type of the variable from the julia side:
```julia
@assert jlscalar(y) isa Int
@assert jlscalar(Float32, y) == Float32(20)

# Directly extract just the value of the desired type
xfloat::Float64 = idlvar(:x)
yfloat = jlscalar(Float32, :y)
@assert xfloat == 10.0
@assert yfloat == 20.0f0

# The IDL variable retains its type
@assert eltype(y) == eltype(x) == Int

```

Change the value of the variables:
```julia
x[] = "Hello, "
y[] = "IDL!"

@assert eltype(x) == eltype(y) == String
```
>[!WARN]
> Currently only Integers, Floats, Complex, Strings and Booleans are supported through this API.

>[!NOTE]
> If a variable is manipulated both from Julia and IDL, extra care is advised in keeping track of the actual type of the variable.

<!--
IDL has three main types of datatypes:
### Scalars
These include mostly primitive types such as `Int`s/`UInt`s, `Double`s, etc..
Notably, IDL's `String`s are considered scalars even though they aren't really.

### Arrays
 - Arrays in IDL are akin to a mutable `NTuple` or `SizedArray` from `StaticArrays.jl`.
 - IDL supports multiarrays, but there is a hardcoded maximum of 8 dimensions.
 - IDL Arrays are column major

 - It is possible to have arrays of structures even though structures are not scalars, but it is peculiar in the sense that Array of Structures in IDL behave very much like Structures of Arrays, and all structures must have the same signature (both tag structure and type).

 - Arrays of scalars are not copied from idl to julia.
 - Arrays of structures are not copied, only the tag information, but not the data.
 >[!WARN]
 > You must take care to keep assigned the variable that holds the data you're referencing from julia assigned, so that IDL does not reuse the memory.

 - Arrays of up to 8 dimensions in julia memory can be passed to IDL and will automatically be kept safe from the GC. The data can be manipulated from either side. -->

<!-- ### Structures:
Structures in IDL are not like structures in Julia, instead they are more akin to
"optionally named" named tuples. An example of structure in idl is of the form:
`idl_struct = {NAME, TAG1:1, TAG2:2, TAG3:3}` or anonymous structures as
`anon_struct = {TAG1:1, TAG2:2, TAG3:3}`.

When translating from idl to julia the struct type information will be stored in a wrapper type
with all its tags, that wraps IDL memory. The IDL structures in julia behaves as if a normal structure with property accessors.

>[!WARN]
> Currently it is not (yet) possible to pass structured data from julia to IDL directly.
> If absolutely needed one can construct a string that defines the structure in IDL syntax and generate it directly in idl via a `IDL.execute` call. -->

### `IDL.execute`
This package provides the `execute` function that sends to idl a string to be evaluated, as if
you're typing it in the console. Accepts multiline strings, with comments and linebreaks.

Some convenient wrappers of `IDL.execute` are provided:
```
IDL.help
IDL.idlhelp
IDL.reset
IDL.full_reset
IDL.dotrun
```
