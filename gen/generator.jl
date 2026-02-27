using Clang.Generators
using Clang.JLLEnvs

# IDL supports only:
# - Windows x86_64
# - mac x86_64 / arm64
# - linux x86_64 glibc

const IDL_SUPPORTED_TRIPLETS = [
	"aarch64-apple-darwin20",
	"x86_64-apple-darwin14",
 	"x86_64-linux-gnu",
 	"x86_64-w64-mingw32"
]

function generate()
	cd(@__DIR__) do

		options = load_options(joinpath(@__DIR__, "generator-v2.toml"))

		# add compiler flags, e.g. "-DXXXXXXXXX"
		args = get_default_args("x86_64-w64-mingw32")  # Note you must call this function firstly and then append your own flags

		headers = [joinpath(@__DIR__, "..", "include", "idl_export.h")]
		# there is also an experimental `detect_headers` function for auto-detecting top-level headers in the directory
		# headers = detect_headers(clang_dir, args)

		# create context
		ctx = create_context(headers, args, options)

		# run generator
		build!(ctx)

	end
end

function generate_all()
	cd(@__DIR__) do

		options = load_options(joinpath(@__DIR__, "generator.toml"))
		for target in JLLEnvs.JLL_ENV_TRIPLES
			target ∉ IDL_SUPPORTED_TRIPLETS && continue

			@info "processing $target"

			options["general"]["output_file_path"] = joinpath(@__DIR__, "..", "lib", "$target.jl")

			# add compiler flags, e.g. "-DXXXXXXXXX"
			args = get_default_args(target)  # Note you must call this function firstly and then append your own flags

			headers = [joinpath(@__DIR__, "..", "include", "idl_export.h")]
			# there is also an experimental `detect_headers` function for auto-detecting top-level headers in the directory
			# headers = detect_headers(clang_dir, args)

			# create context
			ctx = create_context(headers, args, options)

			# run generator
			build!(ctx)

		end
	end
end

# run automatically if launched from the command-line directly.
if !isempty(Base.PROGRAM_FILE)
	generate()
end

