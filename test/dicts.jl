
@testset "jldict / idldict" begin
	idlrun("dict_a = HASH('a', 1, 'b', 'two')")
	d = jldict(:dict_a)
	@test d isa AbstractDict
	@test jldict(idlvar(:dict_a)) isa AbstractDict
	@test length(d) == 2
	@test d["a"] == 1
	@test d["b"] == "two"
	@test haskey(d, "a")
	@test !haskey(d, "zzz")

	# the entries live in the HASH, so IDL sees them
	@test jlobject(:dict_a).count() == 2
	idlrun("dict_a['c'] = 3LL") # an edit made from the IDL side
	@test d["c"] == 3
	d["c"] = 4
	@test jlobject(:dict_a)["c"] == 4

	@test sort(collect(keys(d))) == ["a", "b", "c"]
	@test length(collect(d)) == 3
	@test Dict(d) == Dict("a" => 1, "b" => "two", "c" => 4)

	@test_throws KeyError d["nope"]
	@test get(d, "nope", 0) == 0
	@test get!(d, "a", 99) == 1
	@test get!(d, "d", 5) == 5
	@test d["d"] == 5

	@test pop!(d, "b") == "two"
	@test !haskey(d, "b")
	@test_throws KeyError pop!(d, "b")
	delete!(d, "b") # an absent key is not an error
	@test delete!(d, "a") === d
	@test !haskey(d, "a")

	# integer keys work like they do in a HASH
	d[Int32(7)] = "seven"
	@test d[Int32(7)] == "seven"
	@test haskey(d, Int32(7))
	@test !haskey(d, "7")

	# idldict builds the hash from a Julia dict
	v = idldict(:dict_b, Dict("x" => 42, "y" => [1.0, 2.0]))
	@test v isa IDL.Variable
	w = jldict(v)
	@test w["x"] == 42
	@test w["y"] == [1.0, 2.0]
	w["z"] = "added"
	idlrun("dict_check = dict_b['z']")
	@test jlscalar(:dict_check) == "added"
	@test isempty(jldict(idldict(:dict_empty, Dict{String,Any}())))

	# only a HASH, or a subclass of one, can back the dict
	idlrun("dict_list = LIST(1, 2)")
	@test_throws "jldict needs a HASH object; 'DICT_LIST' is a LIST." jldict(:dict_list)
	@test_throws "jldict needs a HASH object; 'DICT_LIST' is a LIST." jldict(idlvar(:dict_list))
	@test_throws UndefVarError jldict(:dict_not_there)
	@test jldict(IDLObject(:DICTIONARY, "a", 1))["a"] == 1
end
