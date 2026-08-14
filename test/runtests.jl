import InteractiveDataLanguage as IDL
using .IDL
using Test
using ExplicitImports
using Aqua

IDL.init()

const IDL_SCALAR_TYPES = [
	UInt8 => "B",
	Int16 => "S",
	UInt16 => "US",
	Int32 => "L",
	UInt32 => "UL",
	Int64 => "LL",
	UInt64 => "ULL",
	Float32 => ".0",
	Float64 => "D",
	ComplexF32 => "COMPLEX",
	ComplexF64 => "DCOMPLEX"
]

@testset "Scalar Values" begin
	include("scalar_values.jl")
end

@testset "Arrays" begin
	include("arrays.jl")
end

@testset "Structs" begin
	include("structs.jl")
end

print_explicit_imports(IDL)

# Aqua.test_all(IDL)

# Structs # (sub sections: GET, PUT)
# anonymous structures (Named Tuples)
# named structures (Composite Types)
# Nested Structs
# Array of structs


# IDL ARRAYS HAVE SWAPPED COLUMN AND ROW ORDER!
# IDL.IDL_ExecuteStr("arr = intarr(3,3,3)")
# 0

# julia> arr = IDL.getvar("arr")
# 3×3×3 SizedArray{Tuple{3, 3, 3}, Int16, 3, 3, Array{Int16, 3}} with indices SOneTo(3)×SOneTo(3)×SOneTo(3):
# [:, :, 1] =
#  0  0  0
#  0  0  0
#  0  0  0

# [:, :, 2] =
#  0  0  0
#  0  0  0
#  0  0  0

# [:, :, 3] =
#  0  0  0
#  0  0  0
#  0  0  0

# julia> arr[:,:,1] = 42
# 42

# julia> arr[:,1,2] = 69
# 69

# julia> arr[3,:,3] = 1337
# 1337

# julia> arr
# 3×3×3 SizedArray{Tuple{3, 3, 3}, Int16, 3, 3, Array{Int16, 3}} with indices SOneTo(3)×SOneTo(3)×SOneTo(3):
# [:, :, 1] =
#  42  42  42
#  42  42  42
#  42  42  42

# [:, :, 2] =
#  69  0  0
#  69  0  0
#  69  0  0

# [:, :, 3] =
#     0     0     0
#     0     0     0
#  1337  1337  1337

# julia> IDL.IDL_ExecuteStr("print, arr")
#       42      42      42
#       42      42      42
#       42      42      42

#       69      69      69
#        0       0       0
#        0       0       0

#        0       0    1337
#        0       0    1337
#        0       0    1337
# 0
