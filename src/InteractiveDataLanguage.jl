module InteractiveDataLanguage

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

using CEnum: CEnum, @cenum
using StaticArrays: StaticArrays, SizedVector

export IDL,
    idlrun,

    idlvar,
    jlscalar,
    maketemp,

    jlview,
    unsafe_jlview,
    jlarray,
    idlarray,
    idlsimilar,
    maketempwrap,
    idlwrap

# idl must be in path.
if Sys.isunix()
    idl_exec = readchomp(`which idl`)
    if islink(idl_exec)
        idl_dir = dirname(readlink(idl_exec))
    else
        idl_dir = dirname(idl_exec)
    end
    const idl_lib_dir = joinpath(idl_dir,"bin.darwin.x86_64")
    const libidl = joinpath(idl_lib_dir,"libidl.dylib")
else # Windows
    const idl_lib_dir = dirname(readchomp(`where idl`))
    const libidl = joinpath(idl_lib_dir, "idl")
end

safeprintln(str::String) = ccall(:jl_safe_printf, Cvoid, (Cstring, ), str * "\n")

macro comment(_...) end

include("../lib/lib_idl-v1.12.jl")

# === CALLBACKS and REFERENCE ROOTING
const JL_ARR_ROOT = Dict{Ptr, Ref}()

const CB_HOLDING = Dict{Ptr, Base.Callable}()

# longer error messages are given line by line by IDL,
# so we buffer them in this global for better printing.
const ERROR_MSG = Ref{String}("")

@inline preserve_ref__(x__::Ptr, x::Ref) = (JL_ARR_ROOT[convert(Ptr{UInt8}, x__)] = x; return convert(Ptr{UInt8}, x__))
@inline preserve_cb(x__::Ptr, cb::Base.Callable) = CB_HOLDING[x__] = cb



function __jl_drop_array_ref(_p::Ptr{Cuchar})::Cvoid
    #safeprintln("Dropping pointer: $_p")
    delete!(JL_ARR_ROOT, _p)

    return nothing
end

function __passthrough_callback(_p::Ptr{Cuchar})::Cvoid
    cb = CB_HOLDING[_p]::Base.Callable
    cb(_p)

    return nothing
end

function __output_callback(flags, buf::Ptr{UInt8}, n)::Cvoid

    msg = n > 0 ? unsafe_string(buf, n) : ""
    nl = (flags & IDL_TOUT_F_NLPOST) != 0 ? "\n" : ""

    if (flags & IDL_TOUT_F_STDERR) != 0
        ERROR_MSG[] *= "$msg" * nl
        if IDL_SysvErrorCodeValue() != 0
            @error "IDL Error ($(IDL_SysvErrorCodeValue())):\n$(ERROR_MSG[])"
            ERROR_MSG[] = ""
            IDL_MessageResetSysvErrorState()
        end
    else
        print(msg * nl)
    end

    return nothing
end

# We need to get the pointer to the callbacks at runtime and not during compilation.
# See: https://discourse.julialang.org/t/julia-crashes-when-using-a-cfunction-from-another-module/98576/2
const __JL_DROPREF_CB = Base.OncePerProcess{Ptr{Cvoid}}() do
    @cfunction(__jl_drop_array_ref, Nothing, (Ptr{Cuchar},))
end

const __PASSTHROUGH_CB = Base.OncePerProcess{Ptr{Cvoid}}() do
    @cfunction(__passthrough_callback, Nothing, (Ptr{Cuchar},))
end

const __OUTPUT_CB = Base.OncePerProcess{Ptr{Cvoid}}() do
    @cfunction(__output_callback, Cvoid, (Cint, Ptr{UInt8}, Cint))
end


struct IDLMain end
const IDL = IDLMain()

include("type_conversion.jl")
include("variables.jl")
include("arrays.jl")


idlrun(string::AbstractString) = begin
    # remove comments and coalesce line breaks
    string = replace(replace(string, r";.*" => ""), r"\$\s*\n" => "")
    iostring = IOBuffer(string)
    for line in eachline(iostring)
        IDL_ExecuteStr(line)
    end
end

function Base.getindex(v::AbstractIDLVariable)
    return isarray(v) ? jlview(v) : jlscalar(v)
end

function Base.setindex!(v::AbstractIDLVariable, x::T) where
{
    T<:Union{JL_SCALAR, AbstractString}
}
    set!(v, x)
end


Base.getproperty(::IDLMain, x::Symbol) = idlvar(x)
Base.setproperty!(::IDLMain, x::Symbol, v) = idlvar(x, v)


# include("structs.jl")
# include("common.jl")
# include("IDLREPL.jl")

const init = Base.OncePerProcess{Nothing}() do
    @info "Acquiring License..."

    init_data = Ref(IDL_INIT_DATA(IDL_INIT_BACKGROUND))

    err = IDL_Initialize(init_data)

    err == 0 && error("IDL.init: IDL init failed")

    atexit() do
        IDL_Cleanup(IDL_FALSE)
    end

    IDL_ToutPush(__OUTPUT_CB())
end

end # module
