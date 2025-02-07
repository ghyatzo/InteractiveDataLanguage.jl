# IDL interface for the Julia language

The `IDL.jl` package is an interface for calling IDL from the Julia language.
You must have a valid IDL license to use IDL from Julia.

> [!WARN]
> This package is still in the experimental phase, expect changes in the wrapper types.

This package started with an attempt to revive the code from [this package](https://github.com/henry2004y/IDL.jl) which was a fork of [this other package](https://github.com/BobPortmann/IDLCall.jl). But it turned into a complete rewrite.

## Installation

Within Julia, use the package manager:
```julia
] add IDL
```

> [!NOTE]
> `IDL.jl` should find and load the IDL library automatically. It has not been tested on Mac and/or Linux so please file an issue if you encounter errors.

IDL can be called externally using either the `RPC` or `Callable` interface.
This library opted to only support the `Callable` IDL interface due to better ergonomics
and power when managing memory between IDL and Julia.

## Quickstart

```julia
using IDL
```
Once the package is loaded, it will automatically acquire a license. The license is bound to the current julia process. To drop the licence close the julia process.

You can add a Julia variable to the IDL process with
```julia
x = 1
IDL.putvar(x, "x")
```
and you can retrieve variable into Julia using
```julia
x2 = IDL.getvar("x")
@assert x2 == x
```
You can run an arbitrary chunk of code in IDL using
```julia
IDL.execute("any valid idl code")
```

IDL has three main types of datatypes:
### Scalars
These include mostly primitive types such as `Int`s/`UInt`s, `Double`s, etc..
Notably, IDL's `String`s are considered scalars even though they aren't really. (they are `isbits` though)
Scalar values involving strings, will be copied through `unsafe_string`.

### Arrays
 - Arrays in IDL are akin to a mutable `NTuple` or `SizedArray` from `StaticArrays.jl`.
 - IDL supports multiarrays, but there is a hardcoded maximum of 8 dimensions.
 - IDL Arrays are column major, but the first two dimensions are swapped: `A[column, row]` instead of `A[row, column]` as in julia. This package automatically takes care of representing the array correctly so that changes in julia correspond to the expected change in idl.
 - It is possible to have arrays of structures even though structures are not scalars, but it is peculiar in the sense that Array of Structures in IDL behave very much like Structures of Arrays, and all structures must have the same signature (both tag structure and type).

 - Arrays of scalars are not copied from idl to julia.
 - Arrays of structures are not copied, only the tag information, but not the data.
 >[!WARN]
 > You must take care to keep assigned the variable that holds the data you're referencing from julia assigned, so that IDL does not reuse the memory.

 - Arrays of up to 8 dimensions in julia memory can be passed to IDL and will automatically be kept safe from the GC. The data can be manipulated from either side.

### Structures:
Structures in IDL are not like structures in Julia, instead they are more akin to
"optionally named" named tuples. An example of structure in idl is of the form:
`idl_struct = {NAME, TAG1:1, TAG2:2, TAG3:3}` or anonymous structures as
`anon_struct = {TAG1:1, TAG2:2, TAG3:3}`.

When translating from idl to julia the struct type information will be stored in a wrapper type
with all its tags, that wraps IDL memory. The IDL structures in julia behaves as if a normal structure with property accessors.

>[!WARN]
> Currently it is not (yet) possible to pass structured data from julia to IDL directly.
> If absolutely needed one can construct a string that defines the structure in IDL syntax and generate it directly in idl via a `IDL.execute` call.

### `IDL.execute`
This package provides the `execute` function that sends to idl a string to be evaluated, as if
you're typing it in the console.

Some convenient wrappers of `IDL.execute` are provided:
```
IDL.help
IDL.idlhelp
IDL.reset
IDL.full_reset
IDL.dotrun
```
textual output generated in idl is automatically piped to julia.

## TODO
Currently the package provides the bare minimum to have some basic interaction between IDL and julia. The `execute` functionality provided by the IDL runtime is flexible enough it can circumvent the current limitations, at the expense of performance and ergonomicity.

These are some of the planned feature for this package (in no particular order):

- create a `@idl_str` macro to allow for easier use of the `execute` function
- send structured data from julia to idl
- add an option to copy data to and from idl, instead of wrapping it.
- notify when idl memory referenced from julia is freed.
- add an idl REPL prompt mode
- helper `@get/@put` macros

Another addition is giving and `@idl_str` macro so that one can also just call with `idl"v = !NULL"`.
