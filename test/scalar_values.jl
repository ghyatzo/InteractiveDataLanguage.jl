@testset "Scalar Variables" begin
	@testset for (i, pair) in enumerate(IDL_SCALAR_TYPES)
		T, Tstr = pair
		if T == ComplexF32 || T == ComplexF64
			idlrun("v = $Tstr(5, 0)")
		else
			idlrun("v = 5$Tstr")
		end

		v = idlvar(:v)
		v2 = idlvar(:v2, T(5))

		@test v[] == T(5)
		@test v2[] == T(5)

		v[] = T(42)
		@test v[] == T(42)

		newT, _ = rand(IDL_SCALAR_TYPES)
		IDL.set!(v, newT(69))

		@test v[] == newT(69)

	end

	@testset "Strings" begin
		idlrun("v = 'Hello!'")

		v = idlvar(:v)

		@test v[] == "Hello!"

		v[] = "World"

		@test v[] == "World"

		IDL.set!(v, 10)

		@test v[] == 10
	end
end