# IDL interface for the Julia language

The `InteractiveDataLanguage.jl` package is a wrapper for the `CallableIDL` API for calling IDL from other languages. Any IDL code will need to be provided by the users.
Users are also expected to have a valid licensed Installation of the IDL library in their system, which must be obtained separately.
This package also assumes your license is correctly set up and provides no functionality nor instructions on how to set up an IDL installation, refer to the official IDL documentation instead.

> [!CAUTION]
> This package was developed explicitly only on IDL version 8.9 on Windows. Other versions/OSs are untested.

> [!WARN]
> This package does not distributes any IDL binaries, library or code. It is only meant to run existing IDL code for which you have a validly licensed runtime.

This package started with an attempt to revive the code from [this package](https://github.com/henry2004y/IDL.jl) which was a fork of [this other package](https://github.com/BobPortmann/InteractiveDataLanguage.jl). But it turned into a complete rewrite.

## Installation

This package is not registered and will likely not be for various reasons. To install it you can call:
```julia
] add https://github.com/ghyatzo/InteractiveDataLanguage.jl
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
- [x] Structures
	- [x] IDL -> Julia (No copy data)
	- [x] Julia -> IDL (Copy data)
	- [x] Nested structures
	- [x] Arrays of structures
	- [x] Named structures
- [ ] Objects (probably not planned)

Extras:
- [ ] REPL Mode (`IDL>` prompt)
- [ ] `@idl_str` macro
- [ ] automatic interpolation of variables from julia and idl

Currently the package provides the bare minimum to have some basic interaction between IDL and julia.

Notable missing features are handling objects. Full support for all objects types is probably out of scope for this package.

I've been developing this package out of personal need, and will expand it accordingly as the need arise or if there is enough interest/necessity.

For the time being, most shortcomings of the current API can be overcome by using the `idlrun` functionality, by crafting a valid ad hoc IDL string to be `eval`'d by the IDL runtime. It's rough, hacky, but it does the job.

# Quickstart

```julia
using InteractiveDataLanguage
InteractiveDataLanguage.init() # needed to acquire a license
```
The license is bound to the current julia process. To acquire a licence you will need to call `InteractiveDataLanguage.init()`. To drop the licence close the julia process.

The module exports an `IDL` value that will be the main interface to pass and retrieve functions to and from IDL.

## Scalar Variables
Create a variable in IDL and get an handle to it from Julia:
```julia
julia> idlrun("x = 10LL") # LL creates an Int64

julia> IDL.x # access the variable x in IDL
IDL.Variable: 'X' - Int64 | T_LONG64

julia> IDL.x[] # access the variable value
10
```
Instead you can initialize a new (or exising) variable with a value directly from Julia
```julia
julia> IDL.y = 20

julia> IDL.y[]
20
```
Look and use the value held by the IDL variable
```julia
@assert IDL.x[] == IDL.y[] - 10
```

Specify the type of the variable from the julia side:
```julia

# Directly extract just the value of the desired type
julia> IDL.x = 10
10

julia> xfloat::Float64 = IDL.x;

julia> xfloat
10.0

julia> xcomplex::ComplexF32 = IDL.x;

julia> xcomplex
10.0f0 + 0.0f0im

# The IDL variable retains its type
julia> eltype(IDL.x)
Int64

```

Change the value of the variables:
```julia
julia> IDL.x = "Hello"
"Hello"

julia> IDL.y = "IDL!"
"IDL!"

julia> eltype(IDL.x) == String
true

```

If a variable is changed from IDL the change will be reflected also in julia:
```jl
julia> IDL.x = 10
10

julia> eltype(IDL.x)
Int64

julia> idlrun("x = 'Now I am a string'")

julia> eltype(IDL.x)
String
```

## Arrays
Arrays in IDL can be multidimensional, but they have an hard limit of maximum 8 dimensions.

> [!CAUTION]
> Although IDL is technically column major order, IDL arrays have the first two dimensions swapped. Therefore, be extra careful when passing data between the two languages.

By default when accessing IDL managed data from julia views are used, no copy is made.
But when julia managed memory is passed to IDL, a copy is made. It is also possible to instead give IDL a view to julia's data.


```julia
julia> idlrun("arr = [1ll,2ll,3ll,4ll]") # Int64 array

julia> IDL.arr
IDL.Variable: 'ARR' - Int64 | T_LONG64 (ARRAY)

julia> IDL.arr[]
4-element InteractiveDataLanguage.ArrayView{Int64, 1, InteractiveDataLanguage.Variable}:
 1
 2
 3
 4

# you can interact with the view like a normal julia array
julia> IDL.arr[][2]
2

julia> IDL.arr[][2] = 42
42

# and the changes will be mirrored in IDL since we're operating on the same memory.
julia> idlrun("print, arr")
                     1                    42                     3                     4

```

If instead you want to just make a copy of the data, use the `jlarray` function which will allocate new memory managed by julia and therefore independent of anything that might happen to the original data.
```jl
arrcopy = jlarray(:arr)
@assert arrcopy .== IDL.arr[]
```

A view to IDL data is only valid up until the underlaying array stays alive.
if for any reason the IDL data is freed, the view will become useless.
you can recover the binding on the julia side by calling `arr = idlvar(arr)`
which will retrieve the variable with any new value associated to it.

```julia
julia> idlrun("arr = 'we free the array memory'")

julia> IDL.arr[]
"we free the array memory"
```

In any case the view is safe, at every access the validity of the data is checked. If the original data is no longer valid any operation on it will error.

Alternatively you can send and view data managed by julia from IDL.
```jl
julia> jlarr = [1,2,3,4]
4-element Vector{Int64}:
 1
 2
 3
 4

julia> IDL.jlarr = jlarr
4-element Vector{Int64}:
 1
 2
 3
 4

julia> IDL.jlarrview = idlview(jlarr)
InteractiveDataLanguage.IDLview([1, 2, 3, 4])

julia> IDL.jlarrview[]
4-element InteractiveDataLanguage.ArrayView{Int64, 1, InteractiveDataLanguage.Variable}:
 1
 2
 3
 4

julia> all(IDL.jlarr[] .== IDL.jlarrview[] .== jlarr)
true

julia> IDL.jlarr[][2] = 42;

julia> jlarr[2] == 42
false

julia> IDL.jlarrview[][2] = 42;

julia> jlarr[2] == 42
true
```

Multi dimensional arrays are supported:
```
julia> idlrun("multiarr = fltarr(5,5)")

julia> IDL.multiarr[]
5×5 InteractiveDataLanguage.ArrayView{Float32, 2, InteractiveDataLanguage.Variable}:
 0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0

julia> IDL.multiarr[][1,3] = 42
42

julia> IDL.multiarr[]
5×5 InteractiveDataLanguage.ArrayView{Float32, 2, InteractiveDataLanguage.Variable}:
 0.0  0.0  42.0  0.0  0.0
 0.0  0.0   0.0  0.0  0.0
 0.0  0.0   0.0  0.0  0.0
 0.0  0.0   0.0  0.0  0.0
 0.0  0.0   0.0  0.0  0.0

# IDL prints arrays with the first two dimensions transposed
julia> idlrun("print, multiarr")
      0.00000      0.00000      0.00000      0.00000      0.00000
      0.00000      0.00000      0.00000      0.00000      0.00000
      42.0000      0.00000      0.00000      0.00000      0.00000
      0.00000      0.00000      0.00000      0.00000      0.00000
      0.00000      0.00000      0.00000      0.00000      0.00000

julia> IDL.jlmultiarr = zeros(3,5)
3×5 Matrix{Float64}:
 0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0

```

If performance is of the essence, it is possible to use an `unsafe_jlview` that performs no checks on the liveliness of the IDL data. It goes without saying that you'll be responsible to make sure the data will be always available. Otherwise expect violent crashes and segfaults that will bring down the whole julia session.

## Structures
IDL structures are not like structures in Julia, they are closer to "optionally named" named tuples: `{TAG1:1, TAG2:2}` or `{MYSTRUCT, TAG1:1, TAG2:2}`. Internally a structure is always an array of structures, even when it holds a single element.

Retrieving a structure gives a live view over the IDL memory, no copy is made. Tags are accessed as properties (case insensitive, like IDL):
```julia
julia> idlrun("s = {A:42, B:{A2:69, B2:[123, 321]}, C:'hello'}")

julia> s = IDL.s[]
IDLStruct{A: 69, B: IDLStruct{A2: 69, B2: Int16[123, 321]}, C: hello}

julia> s.A, s.C
(Int16(42), "hello")

julia> s.b.b2[2] = 999 # nested tags and array tags are views too

julia> idlrun("print, s.B.B2")
         123         999
```
Arrays of structures behave like normal julia arrays of views:
```julia
julia> idlrun("sa = [{A:1, B:2}, {A:4, B:10}]")

julia> sa = IDL.sa[]

julia> sa[2].A = 7

julia> idlrun("print, sa[1].A") # IDL arrays are 0-based
       7
```

To pass a structure from julia to IDL, use a `NamedTuple` (arrays of `NamedTuple`s for arrays of structures). IDL allocates and owns the memory, the data is copied over:
```julia
julia> idlstruct(:js, (A=Int32(1), B=Float32[1,2,3], C="hello", D=(X=Int16(4),)))

julia> idlrun("print, js.D.X")
       4

# or assign directly
julia> IDL.js2 = (A=1, B=[1.0, 2.0])

# or through a variable
julia> v = idlvar(:js3); v[] = (A=Int16(9),)
```
Named structures are supported by passing the structure name as a third argument. IDL enforces that all instances of a named structure share the same tag definition:
```julia
julia> idlstruct(:ms, (S=Int16(1), B="x"), :MYSTRUCT)

julia> idlrun("ms2 = {MYSTRUCT, S:7, B:'!'}") # valid on the IDL side too
```
An existing named definition can also be instantiated with zeroed tags, exactly like `s = {MYSTRUCT}` on the IDL side. The tags can then be filled one by one through the view:
```julia
julia> idlstruct(:ms_zero, type=:MYSTRUCT)

julia> ms_zero = IDL.ms_zero[]

julia> ms_zero.S = 7
```

> [!WARN]
> A `StructView` is only valid while the underlying IDL variable keeps holding that structure. If IDL frees or replaces the data (for example with `idlrun("s = 42")`), a held view will point at freed memory. Re-fetch it with `jlstruct` instead of holding on to it across IDL calls.

### Running arbitrary IDL strings
This package provides the `idlrun` function that sends to idl a string to be evaluated, as if you're typing it in the IDL console. Accepts multiline strings, with comments and linebreaks.

