using IDL, Test

ENV["JULIA_TEST_FAILFAST"] = true

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

# @testset "Arrays" begin
# 	include("arrays.jl")
# end

# @testset "GET: Structs" begin
# 	@testset "Simple Struct" begin
# 		simple_idl_struct = "{TAG1:1, TAG2: 2L, TAG3: 3.0D, TAG4: COMPLEX(42, 42)}"
# 		IDL.execute("s = $simple_idl_struct")
# 		s = IDL.getvar("s")

# 		@test IDL.ntags(s) == 4
# 		@test Base.nameof(s) == Symbol()
# 		@test IDL.tags(s) == (:TAG1, :TAG2, :TAG3, :TAG4)

# 		@test s.TAG1 == Int16(1)
# 		@test s.TAG2 == Int32(2)
# 		@test s.TAG3 == Float64(3)
# 		@test s.TAG4 == ComplexF32(42, 42)

# 		resetsession()
# 	end

# 	@testset "Named struct with arrays" begin
# 		idl_struct_with_array = "{TESTSTRUCT, ARR:[42, 69], ARR2:[1.0, 2.0]}"

# 		IDL.execute("s = $idl_struct_with_array")
# 		s = IDL.getvar("s")

# 		@test IDL.ntags(s) == 2
# 		@test Base.nameof(s) == :TESTSTRUCT
# 		@test IDL.tags(s) == (:ARR, :ARR2)
# 		@test s.ARR isa IDL.IDLArray{Int16, 1}
# 		@test s.ARR2 isa IDL.IDLArray{Float32, 1}

# 		@test s.ARR[1] == Int16(42)
# 		@test s.ARR[2] == Int16(69)
# 		@test s.ARR2[1] == Float32(1)
# 		@test s.ARR2[2] == Float32(2)

# 		resetsession()
# 	end

# 	@testset "Nested Structs" begin
# 		nested_struct = "{OUTER, NESTED:{INNER, TAG1:42, TAG2:[1,2]}}"
# 		IDL.execute("s = $nested_struct")
# 		s = IDL.getvar("s")

# 		@test IDL.ntags(s) == 1
# 		@test Base.nameof(s) == :OUTER
# 		@test IDL.tags(s) == (:NESTED,)
# 		@test s.NESTED isa
# 			IDL.IDLStruct{
# 				:INNER,
# 				(:TAG1, :TAG2),
# 				Tuple{IDL.StructTag{Ptr{Int16}}, IDL.StructTag{IDL.IDLArray{Int16, 1}}},
# 				2
# 			}

# 		ns = s.NESTED
# 		@test IDL.ntags(ns) == 2
# 		@test nameof(ns) == :INNER
# 		@test IDL.tags(ns) == (:TAG1, :TAG2)
# 		@test ns.TAG1 == Int16(42)
# 		@test ns.TAG2 isa IDL.IDLArray{Int16, 1}
# 		@test ns.TAG2[1] == Int16(1)
# 		@test ns.TAG2[2] == Int16(2)

# 		resetsession()
# 	end

# 	@testset "Array of structs" begin
# 		sa_string = "[{A:1, B:2}, {A:4, B:10}]"
# 		IDL.execute("s = $sa_string")
# 		sa = IDL.getvar("s")

# 		@test length(sa) == 2
# 		@test typeof(first(sa)) == typeof(last(sa))
# 		@test sa[1].A == 1
# 		@test sa[1].B == 2
# 		@test sa[2].A == 4
# 		@test sa[2].B == 10

# 		resetsession()
# 	end


# end


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
