@testset "GET: Simple struct" begin
	idlrun("s = {TAG1:1, TAG2:2L, TAG3:3.0D, TAG4:COMPLEX(42, 42)}")
	s = jlstruct(:s)

	@test ntags(s) == 4
	@test nameof(s) == Symbol()
	@test tags(s) == (:TAG1, :TAG2, :TAG3, :TAG4)

	@test s.TAG1 == Int16(1)
	@test s.TAG2 == Int32(2)
	@test s.TAG3 == Float64(3)
	@test s.TAG4 == ComplexF32(42, 42)

	# case insensitive, like IDL
	@test s.tag2 == Int32(2)
	@test_throws ErrorException s.NOPE
end

@testset "GET: Strings and array tags" begin
	idlrun("s2 = {NAME:'hello', ARR:[1L, 2L, 3L]}")
	s2 = jlstruct(:s2)

	@test s2.NAME == "hello"
	@test s2.ARR == Int32[1, 2, 3]
	@test s2.ARR[2] == Int32(2)

	# write through the view
	s2.ARR[3] = 42
	idlrun("check = s2.ARR[2]") # IDL is 0-based
	@test jlscalar(:check) == Int32(42)
end

@testset "GET: Nested structs" begin
	idlrun("s3 = {A:42, B:{A2:69, B2:[123, 321]}, C:2}")
	s3 = jlstruct(:s3)

	@test s3.A == Int16(42)
	@test s3.B.A2 == Int16(69)
	@test s3.B.B2 == Int16[123, 321]

	s3.B.A2 = 100
	idlrun("check = s3.B.A2")
	@test jlscalar(:check) == Int16(100)
end

@testset "GET: Array of structs" begin
	idlrun("sa = [{A:1, B:2}, {A:4, B:10}]")
	sa = jlstruct(:sa)

	@test length(sa) == 2
	@test sa[1].A == Int16(1)
	@test sa[1].B == Int16(2)
	@test sa[2].A == Int16(4)
	@test sa[2].B == Int16(10)

	sa[2].A = 7
	idlrun("check = sa[1].A") # IDL is 0-based
	@test jlscalar(:check) == Int16(7)
end

@testset "GET: via v[]" begin
	idlrun("sv = {A:1L}")
	v = idlvar(:sv)
	@test v[].A == Int32(1)
end

@testset "PUT: Structs from Julia" begin
	idlstruct(:js, (A=Int32(1), B=Float32[1, 2, 3], C="hello", D=(X=Int16(4),)))

	idlrun("check_a = js.A")
	@test jlscalar(:check_a) == Int32(1)

	idlrun("check_b = js.B[1]") # IDL is 0-based
	@test jlscalar(:check_b) == Float32(2)

	idlrun("check_c = js.C")
	@test jlscalar(:check_c) == "hello"

	idlrun("check_d = js.D.X")
	@test jlscalar(:check_d) == Int16(4)

	# round trip
	js = jlstruct(:js)
	@test js.A == Int32(1)
	@test js.B == Float32[1, 2, 3]
	@test js.C == "hello"
	@test js.D.X == Int16(4)
end

@testset "PUT: Array of structs" begin
	idlstruct(:jsa, [(A=Int16(1), B=Int16(2)), (A=Int16(3), B=Int16(4))])

	idlrun("check = jsa[1].B") # IDL is 0-based
	@test jlscalar(:check) == Int16(4)
	@test jlstruct(:jsa)[2].A == Int16(3)
end

@testset "PUT: via setindex!" begin
	idlrun("sv2 = 1")
	v = idlvar(:sv2)
	v[] = (A=Int32(9), B=[1.0, 2.0])

	idlrun("check = sv2.B[1]") # IDL is 0-based
	@test jlscalar(:check) == 2.0
	@test v[].A == Int32(9)
end

@testset "Named structs" begin
	idlrun("ms = {MYSTRUCT, S:42, B:'SDFS'}")
	ms = jlstruct(:ms)

	@test nameof(ms) == :MYSTRUCT
	@test tags(ms) == (:S, :B)
	@test ms.S == Int16(42)
	@test ms.B == "SDFS"

	# create from julia using the same named definition
	idlstruct(:ms2, (S=Int16(1), B="x"), :MYSTRUCT)
	idlrun("check = ms2.S")
	@test jlscalar(:check) == Int16(1)
	@test nameof(jlstruct(:ms2)) == :MYSTRUCT

	# IDL treats them as instances of the same structure
	idlrun("ms3 = {MYSTRUCT, S:7, B:'!'}")
	idlrun("check2 = ms3.S + ms2.S")
	@test jlscalar(:check2) == Int16(8)
end

@testset "Instantiate named types" begin
	idlrun("mst = {ZEROTYPE, S:42, B:'SDFS'}") # defines the type
	idlstruct(:mz, type=:ZEROTYPE)

	mz = jlstruct(:mz)
	@test nameof(mz) == :ZEROTYPE
	@test mz.S == Int16(0)
	@test mz.B == ""

	# fill through the view
	mz.S = 7
	mz.B = "filled"
	idlrun("check = mz.S")
	@test jlscalar(:check) == Int16(7)
	idlrun("check2 = mz.B")
	@test jlscalar(:check2) == "filled"
end

