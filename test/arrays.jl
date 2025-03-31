@testset "GET: Arrays of scalars" begin

	@testset for (jltype, idlsuffix) in IDL_SCALAR_TYPES

		if jltype == ComplexF32 || jltype == ComplexF64
			array_string = "[" * join(fill("$idlsuffix(5, 0)", 5), ',') * "]"
		else
			array_string = "[" * join(fill("5$idlsuffix", 5), ',') * "]"
		end

		idlrun("var = $array_string")

		var = idlvar(:var)

		@test jlarray(var) isa Array{jltype, 1}
		@test length(unsafe_jlview(var)) == 5

		@test var[] isa AbstractArray{jltype, 1}
		@test var[] == jltype[5, 5, 5, 5, 5]

		@test var[][1] == jltype(5)
		var[][2] = jltype(6)
		@test var[] == jltype[5, 6, 5, 5, 5]

		arrview = jlview(var)
		idlrun("var = [var, 6]")
		@test_throws InvalidStateException arrview[1]
	end

	@testset "Strings" begin
		idlrun("var = ['Hello', 'IDL']")

		var = idlvar(:var)

		@test jlarray(var) isa Array{String, 1}
		@test length(unsafe_jlview(var)) == 2

		@test var[] isa AbstractArray{String, 1}
		@test var[] == ["Hello", "IDL"]

		@test var[][1] == "Hello"
		var[][2] = "World"
		@test var[] == ["Hello", "World"]

		arrview = jlview(var)
		idlrun("var = [var, 'RIIIR']")
		@test_throws InvalidStateException arrview[1]
	end
end

@testset "PUT: Arrays of scalars" begin

	idlrun("var = []")
	@testset for type in first.(IDL_SCALAR_TYPES)
	# @testset for type in [Int, UInt]
		arr = type[1, 2, 3, 4, 5]

		var = idlvar(:var)

		idlarray(:var, arr)
		@test var[] isa AbstractArray{type, 1}
		@test all(var[] .== arr)

		sim = idlsimilar(arr)
		simview = jlview(sim)
		@test simview isa AbstractArray{type, 1}
		@test size(sim[]) == size(arr)

		temp = maketemp(arr)
		@test IDL.istemp(temp)
		@test all(temp[] .== arr)

		wrap = maketempwrap(arr)
		@test wrap[] isa AbstractArray{type, 1}
		@test all(wrap[] .== arr)

		wrap[][1] = type(10)
		@test arr[1] == type(10)

	end

	@testset "Strings" begin
		arr = ["Hello", "IDL"]
		# String don't support wrapping between them,
		# since they have different memory layouts

		sim = idlsimilar(arr)
		@test sim[] isa AbstractArray{String, 1}
		@test size(sim[]) == size(arr)

		temp = maketemp(arr)
		@test IDL.istemp(temp)
		@test all(temp[] .== arr)
	end
end

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