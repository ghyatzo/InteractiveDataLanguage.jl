@testset "Getting objects" begin
	idlrun("h = HASH('a', 1, 'b', 2)")

	h = jlobject(:h)
	@test h isa IDLObject
	@test eltype(h) == IDLObject

	# an object variable reads back as the wrapper, like structs and arrays do
	@test IDL.idlvar(:h)[] isa IDLObject
	@test jlobject(IDL.idlvar(:h)).count() == 2
	@test IDLObject(idlvar(:h)).count() == 2
	@test IDLObject(h) === h

	@test_throws UndefVarError jlobject(:notanobject)
	IDL.idlrun("num = 1")
	@test_throws ArgumentError jlobject(:num)
end

@testset "Quoted strings and comments" begin
	h = IDLObject(:HASH, "a;b", "it's; intact")
	@test h["a;b"] == "it's; intact"
	@test h.haskey("a;b") == 1
	h["x;y"] = "a;b"
	@test h["x;y"] == "a;b"
	h["strings"] = ["a;b", "it's;c"]
	@test h["strings"] == ["a;b", "it's;c"]
	h["struct"] = (text = "a;b",)
	@test h["struct"].text == "a;b"

	idlrun("quoted_single = 'it''s;a' ; comment\nquoted_double = \"a\"\";b\" ; comment\ncontinued = [1L, \$ ; comment\n2L]")
	@test jlscalar(:quoted_single) == "it's;a"
	@test jlscalar(:quoted_double) == "a\";b"
	@test jlarray(:continued) == Int32[1, 2]
end

Base.@noinline function check_retained_tags(h)
	s = h["struct"]
	owner = s.ref
	weak_owner, result_name = WeakRef(owner), owner.name
	a, nested = s.values, s.inner.values
	s = nothing
	owner = nothing
	GC.@preserve a nested begin
		GC.gc(true)
		@test weak_owner.value !== nothing
		@test IDL.isvalid(idlvar(Symbol(result_name)))
		@test a == [1.0, 2.0]
		@test nested == [3.0, 4.0]
		a[1] = 7.0
		nested[1] = 8.0
		@test a[1] == 7.0
		@test nested[1] == 8.0
	end
	return weak_owner, result_name
end

@testset "Array tags retain result storage" begin
	h = IDLObject(:HASH, "struct", (values = [1.0, 2.0], inner = (values = [3.0, 4.0],)))
	weak_owner, result_name = check_retained_tags(h)
	GC.gc(true)
	GC.gc(true)
	@test weak_owner.value === nothing
	@test !IDL.isvalid(idlvar(Symbol(result_name)))
end

@testset "Result names preserve existing variables" begin
	free_names = copy(IDL.FREE_RESULT_NAMES)
	empty!(IDL.FREE_RESULT_NAMES)
	try
		first_name = "JL_RESULT_$(IDL.RESULT_NAME_COUNT[] + 1)"
		null_name = "JL_RESULT_$(IDL.RESULT_NAME_COUNT[] + 2)"
		idlvar(Symbol(first_name), Int64(123))
		idlvar(Symbol(null_name), nothing)
		o = IDLObject(:HASH)
		@test o.owner_.name != first_name
		@test o.owner_.name != null_name
		@test jlscalar(Symbol(first_name)) == Int64(123)
		@test isnothing(idlvar(Symbol(null_name)))

		recycled_name = o.owner_.name
		IDL.release!(o.owner_)
		idlvar(Symbol(recycled_name), Int64(456))
		o2 = IDLObject(:HASH)
		@test o2.owner_.name != recycled_name
		@test jlscalar(Symbol(recycled_name)) == Int64(456)
		IDL.release!(o2.owner_)
		@test jlscalar(Symbol(first_name)) == Int64(123)
		@test jlscalar(Symbol(recycled_name)) == Int64(456)
	finally
		append!(IDL.FREE_RESULT_NAMES, free_names)
	end
end

@testset "Unsupported object-reference storage" begin
	idlrun("object_ref_array = [HASH(), HASH()]")
	v = idlvar(:object_ref_array)
	for convert_array in (jlview, unsafe_jlview, jlarray, jlobject)
		@test_throws "Arrays of IDL objects are not supported." convert_array(v)
	end
	@test_throws "Arrays of IDL objects are not supported." v[]
	@test_throws "Arrays of IDL objects are not supported." IDL.idlvalue("[HASH(), HASH()]")

	idlrun("object_ref_struct = {SCALAR: HASH(), ARRAY: [HASH(), HASH()], NUMBER: 7L}")
	s = jlstruct(:object_ref_struct)
	@test_throws "Object-reference structure tags are not supported." s.scalar
	@test_throws "Object-reference structure tags are not supported." s.array
	@test_throws "Object-reference structure tags are not supported." s.scalar = IDLObject(:HASH)
	@test_throws "Object-reference structure tags are not supported." s.array = [1, 2]
	@test s.number == Int32(7)
	s.number = 8
	@test s.number == Int32(8)

	idlrun("object_ref_valid = OBJ_VALID(object_ref_struct.SCALAR) AND TOTAL(OBJ_VALID(object_ref_struct.ARRAY)) EQ 2")
	@test jlscalar(:object_ref_valid) == 1
	idlrun("object_ref_nested = {INNER: object_ref_struct}")
	@test_throws "Object-reference structure tags are not supported." jlstruct(:object_ref_nested).inner.scalar
end

@testset "Method forwarding" begin
	h = IDLObject(:HASH, "a", 1, "b", 2)

	@test h.count() == 2
	@test h.haskey("a") == 1
	@test h.haskey("zzz") == 0
	@test h.isempty() == 0

	# a method that returns an object comes back as a wrapper of its own
	l = h.keys()
	@test l isa IDLObject
	@test l.count() == 2

	# IDL errors surface as Julia errors instead of taking the process down
	err = try
		h.nosuchmethod()
	catch e
		e
	end
	@test err isa ErrorException
	@test occursin("NOSUCHMETHOD", err.msg)
end

@testset "Brackets" begin
	h = IDLObject(:HASH, "a", 1, "b", 2)

	@test h["a"] == 1
	h["c"] = 3
	@test h["c"] == 3
	@test h.count() == 3

	h[2] = "two"
	@test h[2] == "two"

	err = try
		h["nope"]
	catch e
		e
	end
	@test err isa ErrorException
	@test occursin("Key does not exist", err.msg)
end

@testset "Argument types" begin
	h = IDLObject(:HASH,
		"byte", 0x07,
		"short", Int16(-5),
		"ushort", UInt16(65535),
		"long", Int32(-3),
		"ulong", UInt32(4),
		"int64", Int64(7),
		"uint64", UInt64(8),
		"float", 1.5f0,
		"double", 1.5,
		"subnormal", 1.0e-320,
		"inf", Inf,
		"neginf", -Inf,
		"nan", NaN,
		"complexf", 1.5f0 + 2.5f0im,
		"complexd", 1.5 + 2.5im,
		"string", "it's",
		"vector", [1.0, 2.0],
		"matrix", reshape(collect(1.0:4.0), 2, 2),
		"strings", ["a", "b"],
		"bytes", UInt8[1, 2],
		"bool", true,
		"struct", (a = Int64(1), b = "x"),
		"null", nothing)

	@test h["byte"] === 0x07
	@test h["short"] === Int16(-5)
	@test h["ushort"] === UInt16(65535)
	@test h["long"] === Int32(-3)
	@test h["ulong"] === UInt32(4)
	@test h["int64"] === Int64(7)
	@test h["uint64"] === UInt64(8)
	@test h["float"] === 1.5f0
	@test h["double"] === 1.5
	@test h["subnormal"] === 1.0e-320
	@test h["inf"] === Inf
	@test h["neginf"] === -Inf
	@test isnan(h["nan"])
	@test h["complexf"] === 1.5f0 + 2.5f0im
	@test h["complexd"] === 1.5 + 2.5im
	@test h["string"] == "it's"
	@test h["vector"] == [1.0, 2.0]
	@test h["matrix"] == reshape(collect(1.0:4.0), 2, 2)
	@test h["strings"] == ["a", "b"]
	@test h["bytes"] == UInt8[1, 2]
	@test h["bool"] === 0x01
	@test h["struct"].a === Int64(1)
	@test h["struct"].b == "x"
	@test isnothing(h["null"])

	# objects are passed by reference
	h2 = IDLObject(:HASH, "copy", h)
	@test h2["copy"] isa IDLObject
	@test h2["copy"].count() == h.count()
end

@testset "Empty and unsupported arguments" begin
	h = IDLObject(:HASH)
	@test h.count() == 0

	@test_throws ArgumentError h["x"] = Float64[]
	@test_throws ArgumentError h["x"] = [:a]
	@test_throws ArgumentError h["x"] = "a\nb"
	@test_throws ArgumentError h["x"] = 1im # Complex{Int} is not an IDL type
end
