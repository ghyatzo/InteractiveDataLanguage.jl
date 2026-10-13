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

@testset "Float exceptions" begin
	# Float ops in Julia leave the hardware exception flags set, and IDL's
	# !EXCEPT mechanism reports them as its own arithmetic errors unless they
	# are cleared before each statement.
	z = Ref(0.0)
	@test isnan(z[] / z[])
	@test_logs min_level = Base.CoreLogging.Error idlrun("float_except_probe = 1")
end

@testset "Temporary variables" begin
	# IDL hands its temporary variables back when it runs a statement, and
	# then re-issues their slots. A temp held across one is dead: using it has
	# to fail loudly, and its finalizer must not delete whatever took the slot.
	tv = maketemp(Float64[1.0, 2.0])
	slot = IDL.varptr__(tv)
	@test IDL.vartype(tv) == IDL.T_DOUBLE

	idlrun("temp_probe = 1")
	@test_throws "The temporary variable has been freed." IDL.varptr__(tv)
	@test_throws "The temporary variable has been freed." IDL.isvalid(tv)
	@test_throws "The temporary variable has been freed." convert(Nothing, tv)
	@test_throws "The temporary variable has been freed." repr(tv)

	fresh = maketemp(Float64[9.0, 9.0])
	@test IDL.varptr__(fresh) === slot
	finalize(tv)
	@test IDL.vartype(fresh) == IDL.T_DOUBLE
end

@testset "Arrays" begin
	include("arrays.jl")
end

@testset "Structs" begin
	include("structs.jl")
end

@testset "Objects" begin
	include("objects.jl")
end

@testset "Dicts" begin
	include("dicts.jl")
end

@testset "REPL" begin
	include("repl.jl")
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
