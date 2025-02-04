@testset "GET: Arrays of scalars" begin

	@testset for (jltype, idlsuffix) in IDL_SIMPLE_TYPES
		array_string = "[" * join(fill("5$idlsuffix", 5), ',') * "]"

		execute("var = $array_string")

		var = IDL.get_var("var")

		@test var isa AbstractArray{jltype, 1}
		@test var == jltype[5, 5, 5, 5, 5]

		resetsession()
	end

	@testset "ComplexF32" begin
		execute("var = [COMPLEX(69.0, 42.0), COMPLEX(42.0, 69.0)]")

		var = IDL.get_var("var")

		@test var isa AbstractArray{ComplexF32, 1}
		@test var == [ComplexF32(69.0, 42.0), ComplexF32(42.0, 69.0)]

		resetsession()
	end

	@testset "ComplexF32" begin
		execute("var = [DCOMPLEX(69.0, 42.0), DCOMPLEX(42.0, 69.0)]")

		var = IDL.get_var("var")

		@test var isa AbstractArray{ComplexF64, 1}
		@test var == [ComplexF64(69.0, 42.0), ComplexF64(42.0, 69.0)]

		resetsession()
	end

	@testset "Strings" begin
		execute("var = ['Hello', 'IDL']")

		var = IDL.get_var("var")

		@test var isa AbstractArray{IDL.IDL_STRING, 1}
		@test var == ["Hello", "IDL"]

		resetsession()
	end
end

@testset "PUT: Arrays of scalars" begin

	@testset for type in first.(IDL_SIMPLE_TYPES)
		arr = type[1, 2, 3, 4, 5]

		_var = IDL.put_var(arr, "var")
		var = IDL.get_var("var")

		@test var isa AbstractArray{type, 1}
		@test var == arr
		@test var !== arr

		resetsession()
	end

	@testset "ComplexF32" begin
		arr = ComplexF32[69 + 42im, 42 + 69im]

		_var = IDL.put_var(arr, "var")
		var = IDL.get_var("var")

		@test var isa AbstractArray{ComplexF32, 1}
		@test var == arr
		@test var !== arr

		resetsession()
	end

	@testset "ComplexF64" begin
		arr = ComplexF64[69 + 42im, 42 + 69im]

		_var = IDL.put_var(arr, "var")
		var = IDL.get_var("var")

		@test var isa AbstractArray{ComplexF64, 1}
		@test var == arr
		@test var !== arr

		resetsession()
	end

	@testset "Strings" begin
		arr = ["Hello", "IDL"]

		_var = IDL.put_var(arr, "var")
		var = IDL.get_var("var")

		@test var isa AbstractArray{IDL.IDL_STRING, 1}
		@test var == arr

		resetsession()
	end
end

@testset "GET: 2-dim arrays" begin
	execute("var = [[5LL], [5LL]]")
	execute("var2 = [[1LL:2LL], [3LL:4LL], [5LL:6LL]]")

	var = IDL.get_var("var")
	var2 = IDL.get_var("var2")

	@test var isa AbstractArray{Int, 2}
	@test var2 isa AbstractArray{Int, 2}

	@test var == [5 ; 5 ;;] # the last ;; adds a dimension.
	# Check column mayor order.
	@test var2 == reshape(collect(1:6), 2, 3)'
end

@testset "GET: N-dim arrys" begin
	@testset for N in 3:8
		arrstring = "FLTARR(" * join(string.(collect(1:N)), ',') * ")"
		execute("var = $arrstring")

		var = IDL.get_var("var")

		@test var isa AbstractArray{Float32, N}
		@test size(var) == IDL.dimsperm(N) #(2, 1, 3, 4, ...)
	end
end

@testset "PUT: 2-dim arrays" begin
	arr = [ 1 2; 3 4; 5 6]

	_var = IDL.put_var(arr, "var")
	var = IDL.get_var("var")

	@test var isa AbstractArray{Int, 2}
	@test var == arr'
end

@testset "PUT: N-dim arrays" begin
	@testset for N in 3:8
		arr = rand(Int, collect(1:N)...)

		_var = IDL.put_var(arr, "var")
		var = IDL.get_var("var")

		@test var isa AbstractArray{Int, N}
		@test var == permutedims(arr, IDL.dimsperm(N))
	end

	@testset "Error on bigger than 8th dimension" begin
		arr = rand(fill(3, 9)...)

		@test_throws ArgumentError _var = IDL.put_var(arr, "var")
	end
end