# IDL interface for the Julia language

The `InteractiveDataLanguage.jl` package is a wrapper for the `CallableIDL` API for calling IDL from other languages. Any IDL code will need to be provided by the users.
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
> `InteractiveDataLanguage.jl` should find and load the IDL library automatically. It has not been tested on Mac and/or Linux so please file an issue if you encounter errors. For the automatic discovery IDL should be in the PATH.

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

It might be beneficial to import the package to provide an alternative binding to the module to shorten it:
```jl
import InteractiveDataLanguage as IDL
using .IDL
```

## Scalar Variables
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

## Arrays
Arrays in IDL can be multidimensional, but they have an hard limit of maximum 8 dimensions.


> [!CAUTION]
> Although IDL is technically column major order, IDL arrays have the first two dimensions swapped. Therefore, be extra careful when passing data between the two languages.

```julia
idlrun("arr = [1ll,2ll,3ll,4ll]") # Int64 array
arr = jlview(:arr)

@assert sum(arr[]) = 10

# views allow you to change idl memory from julia
arr[][2] = 5
idlrun("print, arr[2]")
# 5
```
a view to IDL data is only valid up until the underlaying array stays alive.
if for any reason the IDL data is freed, the view will become useless.
you can recover the binding on the julia side by calling `arr = idlvar(arr)`
which will retrieve the variable with any new value associated to it.


If instead you want to just make a copy of the data, use the `jlarray` function which will allocate new memory managed by julia and therefore independent of anything that might happen to the original data.
```jl
arrcopy = jlarray(:arr)
@assert arrcopy .== arr[]
```

Alternatively you can send and view data managed by julia from IDL by using the `idlvar` and `idlwrap` functions, respectively.
```jl
jlarr = [1,2,3,4]

idlarrcopy = idlvar(:jlarrcopy, jlarr)
idlarr = idlwrap(:jlarr, jlarr)
# both return an ArrayView object that can be used to interact with the newly created variables in IDL

@assert idlarrcopy[] .== idlarr[] .== jlarr
idlarrcopy[][1] = 5
@assert jlarr[1] != 5
idlrun("jlarr[2] = 5")
@assert jlarr[2] == 5
```

If performance is of the essence, it is possible to use an `unsafe_jlview` that performs no checks on the liveliness of the IDL data. It goes without saying that you'll be responsible to make sure the data will be always available. Otherwise expect violent crashes and segfaults that will bring down the whole julia session.

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

### Running arbitrary IDL strings
This package provides the `idlrun` function that sends to idl a string to be evaluated, as if you're typing it in the console. Accepts multiline strings, with comments and linebreaks.

Some convenient wrappers of `idlrun` are provided:
```
idlhelp
idlprint
InteractiveDataLanguage.reset
InteractiveDataLanguage.full_reset
InteractiveDataLanguage.dotrun
```

