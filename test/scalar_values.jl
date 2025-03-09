@testset "Scalar Variables" begin
	@testset for (i, pair) in enumerate(IDL_SCALAR_TYPES)
		T, Tstr = pair
		if T == ComplexF32 || T == ComplexF64
			IDL.execute("v = $Tstr(5, 0)")
		else
			IDL.execute("v = 5$Tstr")
		end

		v = IDL.var(:v)
		v2 = IDL.var(:v2, T(5))

		@test v[] == T(5)
		@test v2[] == T(5)

		v[] = T(42)
		@test v[] == T(42)

		newT, _ = rand(IDL_SCALAR_TYPES)
		IDL.set!(v, newT(69))

		@test v[] == newT(69)

	end

	@testset "Strings" begin
		IDL.execute("v = 'Hello!'")

		v = IDL.var(:v)

		@test v[] == "Hello!"

		v[] = "World"

		@test v[] == "World"

		IDL.set!(v, 10)

		@test v[] == 10
	end
end