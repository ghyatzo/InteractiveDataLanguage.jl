@testset "@idl_str macro" begin
	idl"x = 10LL"
	@test jlscalar(:x) == 10

	# multiline, with comments
	idl"""
	y = 20LL ; a comment
	z = y + x
	"""
	@test jlscalar(:z) == 30
end

@testset "idlrepl" begin
	# no active REPL in the test session, must be a no-op
	@test idlrepl() === nothing
end
