@testset "GET: Arrays of scalars" begin

	@testset for (jltype, idlsuffix) in IDL_SCALAR_TYPES

		if jltype == ComplexF32 || jltype == ComplexF64
			array_string = "[" * join(fill("$idlsuffix(5, 0)", 5), ',') * "]"
		else
			array_string = "[" * join(fill("5$idlsuffix", 5), ',') * "]"
		end

		IDL.execute("var = $array_string")

		var = IDL.var(:var)

		@test var[] isa AbstractArray{jltype, 1}
		@test var[] == jltype[5, 5, 5, 5, 5]

		@test var[][1] == jltype(5)
		var[][2] = jltype(6)
		@test var[] == jltype[5, 6, 5, 5, 5]

	end

	@testset "Strings" begin
		IDL.execute("var = ['Hello', 'IDL']")

		var = IDL.var(:var)

		@test var[] isa AbstractArray{String, 1}
		@test var[] == ["Hello", "IDL"]

		@test var[][1] == "Hello"
		var[][2] = "World"
		@test var[] == ["Hello", "World"]
	end
end

# @testset "PUT: Arrays of scalars" begin

# 	@testset for type in first.(IDL_SIMPLE_TYPES)
# 		arr = type[1, 2, 3, 4, 5]

# 		_var = IDL.putvar(arr, "var")
# 		var = IDL.var(:var)

# 		@test var isa AbstractArray{type, 1}
# 		@test var == arr
# 		@test var !== arr

# 		resetsession()
# 	end

# 	@testset "ComplexF32" begin
# 		arr = ComplexF32[69 + 42im, 42 + 69im]

# 		_var = IDL.putvar(arr, "var")
# 		var = IDL.var(:var)

# 		@test var isa AbstractArray{ComplexF32, 1}
# 		@test var == arr
# 		@test var !== arr

# 		resetsession()
# 	end

# 	@testset "ComplexF64" begin
# 		arr = ComplexF64[69 + 42im, 42 + 69im]

# 		_var = IDL.putvar(arr, "var")
# 		var = IDL.var(:var)

# 		@test var isa AbstractArray{ComplexF64, 1}
# 		@test var == arr
# 		@test var !== arr

# 		resetsession()
# 	end

# 	@testset "Strings" begin
# 		arr = ["Hello", "IDL"]

# 		_var = IDL.putvar(arr, "var")
# 		var = IDL.var(:var)

# 		@test var isa AbstractArray{IDL.IDL_STRING, 1}
# 		@test var == arr

# 		resetsession()
# 	end
# end

# @testset "GET: 2-dim arrays" begin
# 	execute("var = [[5LL], [5LL]]")
# 	execute("var2 = [[1LL:2LL], [3LL:4LL], [5LL:6LL]]")

# 	var = IDL.var(:var)
# 	var2 = IDL.getvar("var2")

# 	@test var isa AbstractArray{Int, 2}
# 	@test var2 isa AbstractArray{Int, 2}

# 	@test var == [5 ; 5 ;;] # the last ;; adds a dimension.
# 	# Check column mayor order.
# 	@test var2 == reshape(collect(1:6), 2, 3)'
# end

# @testset "GET: N-dim arrys" begin
# 	@testset for N in 3:8
# 		arrstring = "FLTARR(" * join(string.(collect(1:N)), ',') * ")"
# 		execute("var = $arrstring")

# 		var = IDL.var(:var)

# 		@test var isa AbstractArray{Float32, N}
# 		@test size(var) == IDL.dimsperm(N) #(2, 1, 3, 4, ...)
# 	end
# end

# @testset "PUT: 2-dim arrays" begin
# 	arr = [ 1 2; 3 4; 5 6]

# 	_var = IDL.putvar(arr, "var")
# 	var = IDL.var(:var)

# 	@test var isa AbstractArray{Int, 2}
# 	@test var == arr'
# end

# @testset "PUT: N-dim arrays" begin
# 	@testset for N in 3:8
# 		arr = rand(Int, collect(1:N)...)

# 		_var = IDL.putvar(arr, "var")
# 		var = IDL.var(:var)

# 		@test var isa AbstractArray{Int, N}
# 		@test var == permutedims(arr, IDL.dimsperm(N))
# 	end

# 	@testset "Error on bigger than 8th dimension" begin
# 		arr = rand(fill(3, 9)...)

# 		@test_throws ArgumentError _var = IDL.putvar(arr, "var")
# 	end
# end