# IDL interface for the Julia language

The `IDL.jl` package is an interface for calling IDL from the Julia language.
You must have a valid IDL license to use IDL from Julia.

## Installation

Within Julia, use the package manager:
```julia
] add IDL
```

> [!NOTE]
> `IDL.jl` should find and load the IDL library automatically. It has not been tested on Mac and/or Linux so please file an issue if you encounter errors.

IDL can be called using either the `RPC` or `Callable` interface.
This library opted to only support the `Callable` IDL interface due to better ergonomics
and power when managing memory between IDL and Julia.

## Quickstart

```julia
using IDL
```
You can add a Julia variable to the IDL process with
```julia
x = 1
put_var(x, "x")
```
and you can retrieve variable into Julia using
```julia
x = get_var("x")
```
You can run an arbitrary chunk of code in IDL using
```julia
Idl.execute("any valid idl code")
```
`[;|\$]` inside quotes won't be correctly recognized.

IDL has three main types of datatypes:
  - Scalars: these include mostly `isbits` types such as `Int`s/`UInt`s, `Double`s, etc..
    Notably, IDL's `String`s are considered scalars even though they aren't really.

  - Arrays: arrays in IDL are uniform and can only contain one scalar subtype.
    Also, IDL supports multiarrays, but there is a hardcoded maximum of 8 dimensions.
    It is possible to have Array of structures even though Structures are not scalar, but
    it is peculiar in the sense that Array of Structures in IDL behave very much like Structures
    of Arrays, and all structures must have the same signature (both tag structure and type).
    Arrays of scalar are not copied from idl to julia and are therefore quick.
    Arrays of strings and arrays of structures are copied.
    Arrays are not really moved from idl to julia as we can just wrap the IDL memory. So there is no copying.

  - Structures:
    Structures in IDL are not like structures in Julia, instead they are more akin to
    "optionally named" named tuples. An example of structure in idl is of the form:
    `idl_struct = {NAME, TAG1:1, TAG2:2, TAG3:3}` or anonymous structures as
    `anon_struct = {TAG1:1, TAG2:2, TAG3:3}`.

    When translating from idl to julia I've opted for returning a normal named tuple for anonymous
    structures `anon_jl_struct = (; tag1=1, tag2=2, tag3=3)` while named structures will have an
    additional `__name__` field: `jl_struct = (; __name__="NAME", tag1=1, tag2=2, tag3=3)`
    This choice allows for quickly wrapping an array of structures with the `StructArrays.jl` package.


Many convenient functions are provided:
```
IDL.help
IDL.idlhelp
IDL.shell_command
IDL.reset
IDL.full_reset
IDL.dotrun
```

See more examples in the [test script](test/runtests.jl)

## REPL

You can drop into an IDL REPL by typing `>` at the Julia prompt. Then you can type any valid IDL commands, including using continuation characters `$` for multi-line commands. One experimental feature I have added is the use of `%var` will auto-magically import the Julia variable `var` into the IDL process. This works at the IDL prompt or in strings passed into the `execute` function.

## TODO
Another addition is giving and `@idl_str` macro so that one can also just call with `idl"v = !NULL"`.
