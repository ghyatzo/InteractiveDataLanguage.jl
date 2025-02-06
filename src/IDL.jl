module IDL

# References (in no particular order)
# [1] https://www.nv5geospatialsoftware.com/docs/PassingStructures.html
# [2] https://www.irya.unam.mx/computo/sites/manuales/IDL/Content/Creating%20IDL%20Programs/Components%20of%20the%20IDL%20Language/Creating_and_Defining_St.html
# [3] https://www.geo.mtu.edu/geoschem/docs/IDL_Manuals/EXTERNAL%20DEVELOPMENT%20GUIDE.pdf
# [4] https://www.nv5geospatialsoftware.com/docs/Error_Handling_System_Va.html
# [5] https://www.nv5geospatialsoftware.com/docs/MESSAGE.html
# [6] https://www.nv5geospatialsoftware.com/docs/EDG.html
# [7] https://math.nist.gov/mcsd/savg/idl2/callexternal.htm
# [8] https://www.nv5geospatialsoftware.com/docs/UsingCallableIDL.html
# [9] https://discourse.julialang.org/t/mutate-ntuple-at-position/17682/6
# [10] https://discourse.julialang.org/t/how-to-keep-a-reference-for-c-structure-to-avoid-gc/9310
# [11] https://github.com/JuliaPy/PyCall.jl/blob/314ac274326e78f12fbcb73ae0f17f63a3f4bba9/src/pytype.jl#L314
# [12] https://nv5geospatialsoftware.co.jp/docs/Columns__Rows__and_Array.html
# [13] https://discourse.julialang.org/t/memory-management-and-packagecompiler-libraries/72980/7
# [14] https://discourse.julialang.org/t/cconvert-and-unsafe-convert-with-immutable-struct-containing-a-pointer/124479/5
# [15] https://github.com/tk3369/julia-notebooks/blob/master/ccall%20-%20using%20cconvert%20and%20unsafe_convert.ipynb

using StaticArrays

if Sys.isunix()
    idl_exec = chomp(read(`which idl`,String))
    if islink(idl_exec)
        idl_dir = dirname(readlink(idl_exec))
    else
        idl_dir = dirname(idl_exec)
    end
    idl_lib_dir = joinpath(idl_dir,"bin.darwin.x86_64")
    const libidl_rpc = joinpath(idl_lib_dir,"libidl_rpc.dylib")
    const idlrpc = joinpath(idl_dir,"idlrpc")
    const libidl = joinpath(idl_lib_dir,"libidl.dylib")
else # Windows
    const idl_lib_dir = dirname(chomp(read(`where idl`, String))) # idl must be in path.
    const libidl = joinpath(idl_lib_dir, "idl")
end

include("../lib/lib_idl.jl")

# === Manual Wrappers of (maybe) used macros
IDL_STRING_STR(str::IDL_STRING) = str.slen > 0 ? unsafe_string(str.s) : ""
IDL_STRING_STR(str_::Ptr{IDL_STRING}) = IDL_STRING_STR(unsafe_load(str_))

# === InitData Default Constructor
IDL_INIT_DATA(init_options::Int64) = IDL_INIT_DATA(convert(IDL_INIT_DATA_OPTIONS_T, init_options))
function IDL_INIT_DATA(init_options::IDL_INIT_DATA_OPTIONS_T)
    ref = Ref{IDL_INIT_DATA}()
    GC.@preserve ref begin
        x = Base.unsafe_convert(Ptr{IDL_INIT_DATA}, ref)
        x.options = init_options
        ref[]
    end
end

Base.getproperty(x::Ptr{IDL_ARRAY}, f::Symbol) = begin
    fieldid = findfirst(==(f), fieldnames(IDL_ARRAY))
    isnothing(fieldid) && error("IDL_ARRAY does not have the field $f")
    Ptr{fieldtype(IDL_ARRAY, f)}(x + fieldoffset(IDL_ARRAY, fieldid))
end

const JL_REF_HOLDING = Dict{Ptr, Ref}()

free_jl_array_ref(_p::Ptr{Cuchar}) = begin
    @debug "Dropping pointer: $_p"
    delete!(JL_REF_HOLDING, _p)
    nothing
end
const FREE_JLARR = Ref{Ptr{Cvoid}}()

preserve_ref(_x::Ptr, x::Ref) = begin
    JL_REF_HOLDING[_x] = x
    _x
end

preserve_ref(x::Ref) = begin
    _x = pointer_from_objref(x)
    JL_REF_HOLDING[_x] = x
    _x
end

varflags(_var::Ptr{IDL_VARIABLE}) = unsafe_load(_var.flags)
vartype(_var::Ptr{IDL_VARIABLE}) = unsafe_load(_var.type)
varinfo(_var::Ptr{IDL_VARIABLE}) = (varflags(_var), vartype(_var))
include("type_conversion.jl")

include("arrays.jl")
include("common.jl")

# include("IDLREPL.jl")

function output_callback(flags, buf::Ptr{UInt8}, n)::Cvoid
    msg = n > 0 ? unsafe_string(buf, n) : ""

    if (flags & IDL_TOUT_F_STDERR) != 0
        IDL_MessageResetSysvErrorState()
        @warn "IDL Error: $msg"
    else
        (flags & IDL_TOUT_F_NLPOST) != 0 ? println(msg) : print(msg)
    end
end

const OUTPUT_CB = Ref{Ptr{Cvoid}}()

function __init__()
    @info "Initializing IDL..."
    init_options = IDL_INIT_BACKGROUND # | IDL_INIT_QUIET

    init_data = Ref(IDL_INIT_DATA(init_options))

    err = IDL_Initialize(init_data)

    err == 0 && error("IDL.init: IDL init failed")

    atexit() do
        IDL_Cleanup(IDL_FALSE)
    end

    # We need to get the pointer to the callbacks at runtime
    # and not during compilation.
    # See: https://discourse.julialang.org/t/julia-crashes-when-using-a-cfunction-from-another-module/98576/2

    OUTPUT_CB[] = @cfunction(output_callback, Cvoid, (Cint, Ptr{UInt8}, Cint))
    FREE_JLARR[] = @cfunction(free_jl_array_ref, Nothing, (Ptr{Cuchar},))

    IDL_ToutPush(OUTPUT_CB[])

    # Initializing REPL
    #idl_repl()
end

end
