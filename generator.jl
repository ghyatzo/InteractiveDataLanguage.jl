using Clang.Generators


cd(@__DIR__)

options = load_options(joinpath(@__DIR__, "generator.toml"))
options["add_record_constructors"] = true

# add compiler flags, e.g. "-DXXXXXXXXX"
args = get_default_args()  # Note you must call this function firstly and then append your own flags

headers = ["include/idl_export.h"]
# there is also an experimental `detect_headers` function for auto-detecting top-level headers in the directory
# headers = detect_headers(clang_dir, args)

# create context
ctx = create_context(headers, args, options)

# run generator
build!(ctx)