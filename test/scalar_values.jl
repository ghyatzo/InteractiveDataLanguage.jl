
@testset "GET: Scalar Variables" begin

	@testset "UInt8" begin
		execute("var = 5B")

		var = IDL.var(:var)

		@test var isa UInt8
		@test var == 0x05

		resetsession()
	end

	@testset "Int16/UInt16" begin
		execute("var = 5S")
		execute("varu = 5US")

		var = IDL.var(:var)
		varu = IDL.var(:varu)

		@test varu isa UInt16
		@test varu == UInt16(5)

		@test var isa Int16
		@test var == Int16(5)

		resetsession()
	end

	@testset "Int32/UInt32" begin
		execute("var = 5L")
		execute("varu = 5UL")

		var = IDL.var(:var)
		varu = IDL.var(:varu)

		@test varu isa UInt32
		@test varu == UInt32(5)

		@test var isa Int32
		@test var == Int32(5)

		resetsession()
	end

	@testset "Int64/UInt64" begin
		execute("var = 5LL")
		execute("varu = 5ULL")

		var = IDL.var(:var)
		varu = IDL.var(:varu)

		@test varu isa UInt64
		@test varu == UInt64(5)

		@test var isa Int64
		@test var == Int64(5)

		resetsession()
	end

	@testset "Float32" begin
		execute("var = 5.0")

		var = IDL.var(:var)

		@test var isa Float32
		@test var == Float32(5)

		resetsession()
	end

	@testset "Float64" begin
		execute("var = 5.0D")

		var = IDL.var(:var)

		@test var isa Float64
		@test var == Float64(5)

		resetsession()
	end

	@testset "ComplexF32" begin
		execute("var = COMPLEX(69.0, 42.0)")

		var = IDL.var(:var)

		@test var isa ComplexF32
		@test var == ComplexF32(69.0, 42.0)

		resetsession()
	end

	@testset "ComplexF64" begin
		execute("var = DCOMPLEX(69.0, 42.0)")

		var = IDL.var(:var)

		@test var isa ComplexF64
		@test var == ComplexF64(69.0, 42.0)

		resetsession()
	end

	@testset "Strings" begin
		execute("var = 'Hello!'")

		var = IDL.var(:var)

		@test var isa String
		@test var == "Hello!"
	end
end

#=======~~~~~~~~~~~~~~~~~~~~~~~~~~======#

@testset "PUT: Scalar Variables" begin
	@testset "UInt8" begin
		var = 0x05

		_var = IDL.var(:var, var)
		varvar = IDL.var(:var)

		@test varvar isa UInt8
		@test varvar == var

		resetsession()
	end

	@testset "Int16/UInt16" begin
		var = Int16(5)
		varu = UInt16(5)

		_var = IDL.var(:var, var)
		_varu = IDL.var(:varu, varu)

		varvar = IDL.var(:var)
		varvaru = IDL.var(:varu)

		@test varvar isa Int16
		@test varvar == var

		@test varvaru isa UInt16
		@test varvaru == varu

		resetsession()
	end

	@testset "Int32/UInt32" begin
		var = Int32(5)
		varu = UInt32(5)

		_var = IDL.var(:var, var)
		_varu = IDL.var(:varu, varu)

		varvar = IDL.var(:var)
		varvaru = IDL.var(:varu)

		@test varvar isa Int32
		@test varvar == var

		@test varvaru isa UInt32
		@test varvaru == varu

		resetsession()
	end

	@testset "Int64/UInt64" begin
		var = Int64(5)
		varu = UInt64(5)

		_var = IDL.var(:var, var)
		_varu = IDL.var(:varu, varu)

		varvar = IDL.var(:var)
		varvaru = IDL.var(:varu)

		@test varvar isa Int64
		@test varvar == var

		@test varvaru isa UInt64
		@test varvaru == varu

		resetsession()
	end

	@testset "Float32" begin
		var = Float32(5)

		_var = IDL.var(:var, var)
		varvar = IDL.var(:var)

		@test varvar isa Float32
		@test varvar == var

		resetsession()
	end

	@testset "Float64" begin
		var = Float64(5)

		_var = IDL.var(:var, var)
		varvar = IDL.var(:var)

		@test varvar isa Float64
		@test varvar == var

		resetsession()
	end

	@testset "ComplexF32" begin
		var = ComplexF32(5)

		_var = IDL.var(:var, var)
		varvar = IDL.var(:var)

		@test varvar isa ComplexF32
		@test varvar == var

		resetsession()
	end

	@testset "ComplexF64" begin
		var = ComplexF64(5)

		_var = IDL.var(:var, var)
		varvar = IDL.var(:var)

		@test varvar isa ComplexF64
		@test varvar == var

		resetsession()
	end

	@testset "Strings" begin
		var = "Hello!"

		_var = IDL.var(:var, var)
		varvar = IDL.var(:var)

		@test varvar isa String
		@test varvar == var

		resetsession()
	end
end
