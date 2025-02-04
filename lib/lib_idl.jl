# module LibIDL

using CEnum

const IDL_LONG64 = Clonglong

const IDL_ULONG64 = Culonglong

# typedef IDL_VARIABLE * ( * IDL_SYSRTN_GENERIC ) ( )
const IDL_SYSRTN_GENERIC = Ptr{Cvoid}

const UCHAR = Cuchar

const IDL_LONG = Clong

struct IDL_ALLTYPES
    data::NTuple{16, UInt8}
end

function Base.getproperty(x::Ptr{IDL_ALLTYPES}, f::Symbol)
    f === :sc && return Ptr{Cchar}(x + 0)
    f === :c && return Ptr{UCHAR}(x + 0)
    f === :i && return Ptr{IDL_INT}(x + 0)
    f === :ui && return Ptr{IDL_UINT}(x + 0)
    f === :l && return Ptr{IDL_LONG}(x + 0)
    f === :ul && return Ptr{IDL_ULONG}(x + 0)
    f === :l64 && return Ptr{IDL_LONG64}(x + 0)
    f === :ul64 && return Ptr{IDL_ULONG64}(x + 0)
    f === :f && return Ptr{Cfloat}(x + 0)
    f === :d && return Ptr{Cdouble}(x + 0)
    f === :cmp && return Ptr{IDL_COMPLEX}(x + 0)
    f === :dcmp && return Ptr{IDL_DCOMPLEX}(x + 0)
    f === :str && return Ptr{IDL_STRING}(x + 0)
    f === :arr && return Ptr{Ptr{IDL_ARRAY}}(x + 0)
    f === :s && return Ptr{IDL_SREF}(x + 0)
    f === :hvid && return Ptr{IDL_HVID}(x + 0)
    f === :memint && return Ptr{IDL_LONG64}(x + 0)
    f === :fileint && return Ptr{IDL_LONG64}(x + 0)
    f === :ptrint && return Ptr{IDL_PTRINT}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::IDL_ALLTYPES, f::Symbol)
    r = Ref{IDL_ALLTYPES}(x)
    ptr = Base.unsafe_convert(Ptr{IDL_ALLTYPES}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IDL_ALLTYPES}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

# =-=-= CUSTOM ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The structure defined in the header idl_export.h is Wrong????
# There is an extra 6 byte padding between flags and value?
# struct IDL_VARIABLE
#     type::UCHAR
#     flags::UCHAR
#     flags2::UCHAR # internal. don't use.
#     value::IDL_ALLTYPES
# end

# For some absurd fucking reason, IDL Variables have an undocumented
# 6 byte pad between the flag byte and the value structure.
# (at least on windows...)
struct IDL_VARIABLE
    type::Cuchar
    flags::Cuchar
    pad::NTuple{6, UInt8}
    value::IDL_ALLTYPES
end

function Base.getproperty(x::Ptr{IDL_VARIABLE}, f::Symbol)
    f === :type && return Ptr{Cuchar}(x + 0)
    f === :flags && return Ptr{Cuchar}(x + 1)
    f === :value && return Ptr{IDL_ALLTYPES}(x + 8)
    return getfield(x, f)
end
## =-=-= ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

const IDL_VPTR = Ptr{IDL_VARIABLE}

function IDL_Deltmp(p)
    ccall((:IDL_Deltmp, libidl), Cvoid, (IDL_VPTR,), p)
end

function IDL_MessageVE_UNDEFVAR(var, action)
    ccall((:IDL_MessageVE_UNDEFVAR, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_MessageVE_NOCONST(var, action)
    ccall((:IDL_MessageVE_NOCONST, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_MessageVE_NOEXPR(var, action)
    ccall((:IDL_MessageVE_NOEXPR, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_MessageVE_NOFILE(var, action)
    ccall((:IDL_MessageVE_NOFILE, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_MessageVE_NOSTRUCT(var, action)
    ccall((:IDL_MessageVE_NOSTRUCT, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_MessageVE_NOCOMPLEX(var, action)
    ccall((:IDL_MessageVE_NOCOMPLEX, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_MessageVE_NOSTRING(var, action)
    ccall((:IDL_MessageVE_NOSTRING, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_MessageVE_NOSCALAR(var, action)
    ccall((:IDL_MessageVE_NOSCALAR, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_MessageVE_NOMEMINT64(var, action)
    ccall((:IDL_MessageVE_NOMEMINT64, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_MessageVE_NOTARRAY(var, action)
    ccall((:IDL_MessageVE_NOTARRAY, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_MessageVE_NOTSCALAR(var, action)
    ccall((:IDL_MessageVE_NOTSCALAR, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_MessageVE_REQSTR(var, action)
    ccall((:IDL_MessageVE_REQSTR, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_VarEnsureSimple(v)
    ccall((:IDL_VarEnsureSimple, libidl), Cvoid, (IDL_VPTR,), v)
end

function IDL_MessageVE_STRUC_REQ(var, action)
    ccall((:IDL_MessageVE_STRUC_REQ, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_MessageVE_REQPTR(var, action)
    ccall((:IDL_MessageVE_REQPTR, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_MessageVE_REQOBJREF(var, action)
    ccall((:IDL_MessageVE_REQOBJREF, libidl), Cvoid, (IDL_VPTR, Cint), var, action)
end

function IDL_Delvar(var)
    ccall((:IDL_Delvar, libidl), Cvoid, (IDL_VPTR,), var)
end

const IDL_PTRINT = Clonglong

function IDL_KWFree()
    ccall((:IDL_KWFree, libidl), Cvoid, ())
end

const IDL_SFILE_FLAGS_T = IDL_LONG

function IDL_FileSetClose(unit, allow)
    ccall((:IDL_FileSetClose, libidl), Cvoid, (Cint, Cint), unit, allow)
end

function IDL_StrBase_strlcpy(dst, src, siz)
    ccall((:IDL_StrBase_strlcpy, libidl), Csize_t, (Ptr{Cchar}, Ptr{Cchar}, Csize_t), dst, src, siz)
end

function IDL_StrBase_strlcat(dst, src, siz)
    ccall((:IDL_StrBase_strlcat, libidl), Csize_t, (Ptr{Cchar}, Ptr{Cchar}, Csize_t), dst, src, siz)
end

function IDL_StrBase_strlcatW(dst, src, siz)
    ccall((:IDL_StrBase_strlcatW, libidl), Csize_t, (Ptr{Cwchar_t}, Ptr{Cwchar_t}, Csize_t), dst, src, siz)
end

function IDL_StrBase_strbcopy(dst, src, siz)
    ccall((:IDL_StrBase_strbcopy, libidl), Cint, (Ptr{Cchar}, Ptr{Cchar}, Csize_t), dst, src, siz)
end

function IDL_StrBase_strbcopyW(dst, src, siz)
    ccall((:IDL_StrBase_strbcopyW, libidl), Cint, (Ptr{Cwchar_t}, Ptr{Cwchar_t}, Csize_t), dst, src, siz)
end

@cenum IDLBool_t::UInt32 begin
    IDL_FALSE = 0
    IDL_TRUE = 1
end

const IDL_INT = Cshort

const IDL_UINT = Cushort

const IDL_ULONG = Culong

const IDL_HVID = IDL_ULONG

struct IDL_COMPLEX
    r::Cfloat
    i::Cfloat
end

struct IDL_DCOMPLEX
    r::Cdouble
    i::Cdouble
end

const IDL_STRING_SLEN_T = Cint

struct IDL_STRING
    slen::IDL_STRING_SLEN_T
    stype::Cshort
    s::Ptr{Cchar}
end

struct _idl_ident
    hash::Ptr{_idl_ident}
    name::Ptr{Cchar}
    len::Cint
end

const IDL_IDENT = _idl_ident

# typedef void ( * IDL_ARRAY_FREE_CB ) ( UCHAR * data )
const IDL_ARRAY_FREE_CB = Ptr{Cvoid}

const IDL_ARRAY_DIM = NTuple{8, IDL_LONG64}

struct IDL_ARRAY
    elt_len::IDL_LONG64
    arr_len::IDL_LONG64
    n_elts::IDL_LONG64
    data::Ptr{UCHAR}
    n_dim::UCHAR
    flags::UCHAR
    file_unit::Cshort
    dim::IDL_ARRAY_DIM
    free_cb::IDL_ARRAY_FREE_CB
    offset::IDL_LONG64
    data_guard::IDL_LONG64
end

struct _idl_tagdef
    id::Ptr{IDL_IDENT}
    offset::IDL_LONG64
    var::IDL_VARIABLE
end

const IDL_TAGDEF = _idl_tagdef

struct _idl_structure
    id::Ptr{IDL_IDENT}
    flags::UCHAR
    contains_string::UCHAR
    ntags::Cint
    length::IDL_LONG64
    data_length::IDL_LONG64
    rcount::Cint
    object::Ptr{Cvoid}
    tag_array_mem::Ptr{IDL_ARRAY}
    tags::NTuple{1, IDL_TAGDEF}
end

struct IDL_SREF
    arr::Ptr{IDL_ARRAY}
    sdef::Ptr{_idl_structure}
end

# typedef void ( * IDL_SYSRTN_PRO ) ( int argc , IDL_VPTR argv [ ] , char * argk )
const IDL_SYSRTN_PRO = Ptr{Cvoid}

# typedef IDL_VPTR ( * IDL_SYSRTN_FUN ) ( int argc , IDL_VPTR argv [ ] , char * argk )
const IDL_SYSRTN_FUN = Ptr{Cvoid}

struct IDL_SYSRTN_UNION
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{IDL_SYSRTN_UNION}, f::Symbol)
    f === :generic && return Ptr{IDL_SYSRTN_GENERIC}(x + 0)
    f === :pro && return Ptr{IDL_SYSRTN_PRO}(x + 0)
    f === :fun && return Ptr{IDL_SYSRTN_FUN}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::IDL_SYSRTN_UNION, f::Symbol)
    r = Ref{IDL_SYSRTN_UNION}(x)
    ptr = Base.unsafe_convert(Ptr{IDL_SYSRTN_UNION}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IDL_SYSRTN_UNION}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

# typedef void ( * IDL_PRO_PTR ) ( )
const IDL_PRO_PTR = Ptr{Cvoid}

struct IDL_SYSFUN_DEF2
    funct_addr::IDL_SYSRTN_UNION
    name::Ptr{Cchar}
    arg_min::Cushort
    arg_max::Cushort
    flags::Cint
    extra::Ptr{Cvoid}
end

const IDL_StructDefPtr = Ptr{_idl_structure}

const IDL_STRUCTURE = _idl_structure

@cenum IDL_MSG_SYSCODE_T::UInt32 begin
    IDL_MSG_SYSCODE_NONE = 0
    IDL_MSG_SYSCODE_ERRNO = 1
    IDL_MSG_SYSCODE_WIN = 2
    IDL_MSG_SYSCODE_WINSOCK = 3
end

struct IDL_MSG_DEF
    name::Ptr{Cchar}
    format::Ptr{Cchar}
end

const IDL_MSG_BLOCK = Ptr{Cvoid}

struct IDL_MSG_ERRSTATE
    action::Cint
    msg_block::IDL_MSG_BLOCK
    code::Cint
    global_code::Cint
    syscode_type::IDL_MSG_SYSCODE_T
    syscode::Cint
    msg::NTuple{2048, Cchar}
    sysmsg::NTuple{512, Cchar}
end

const IDL_MSG_ERRSTATE_PTR = Ptr{Cvoid}

struct IDL_CPU_STRUCT
    hw_vector::IDL_LONG
    vector_enable::IDL_LONG
    hw_ncpu::IDL_LONG
    tpool_nthreads::IDL_LONG
    tpool_min_elts::IDL_LONG64
    tpool_max_elts::IDL_LONG64
end

struct IDL_SYS_ERROR_STATE
    name::IDL_STRING
    block::IDL_STRING
    code::IDL_LONG
    sys_code::NTuple{2, IDL_LONG}
    sys_code_type::IDL_STRING
    msg::IDL_STRING
    sys_msg::IDL_STRING
    msg_prefix::IDL_STRING
end

struct IDL_MOUSE_STRUCT
    x::IDL_LONG
    y::IDL_LONG
    button::IDL_LONG
    time::IDL_LONG
end

struct IDL_SYS_VERSION
    arch::IDL_STRING
    os::IDL_STRING
    os_family::IDL_STRING
    os_name::IDL_STRING
    release::IDL_STRING
    build_date::IDL_STRING
    memory_bits::IDL_INT
    file_offset_bits::IDL_INT
end

# typedef void ( * IDL_EXIT_HANDLER_FUNC ) ( void )
const IDL_EXIT_HANDLER_FUNC = Ptr{Cvoid}

struct IDL_EZ_ARG
    allowed_dims::Cshort
    allowed_types::Cint
    access::Cshort
    convert::Cshort
    pre::Cshort
    post::Cshort
    to_delete::IDL_VPTR
    uargv::IDL_VPTR
    value::IDL_ALLTYPES
end

struct IDL_AXIS
    title::IDL_STRING
    type::Cint
    style::Cint
    nticks::Cint
    ticklen::Cfloat
    thick::Cfloat
    range::NTuple{2, Cdouble}
    crange::NTuple{2, Cdouble}
    s::NTuple{2, Cdouble}
    margin::NTuple{2, Cfloat}
    omargin::NTuple{2, Cfloat}
    window::NTuple{2, Cfloat}
    region::NTuple{2, Cfloat}
    charsize::Cfloat
    minor_ticks::Cint
    tickv::NTuple{60, Cdouble}
    annot::NTuple{60, IDL_STRING}
    gridstyle::IDL_LONG
    format::NTuple{10, IDL_STRING}
    tickinterval::Cdouble
    ticklayout::IDL_LONG
    tickunits::NTuple{10, IDL_STRING}
    ret_values::IDL_VPTR
    log_minor_ticks::Cint
end

struct IDL_GR_PT
    data::NTuple{32, UInt8}
end

function Base.getproperty(x::Ptr{IDL_GR_PT}, f::Symbol)
    f === :d && return Ptr{var"struct (unnamed at include/idl_export.h:1354:3)"}(x + 0)
    f === :i && return Ptr{var"struct (unnamed at include/idl_export.h:1360:3)"}(x + 0)
    f === :d_s && return Ptr{var"struct (unnamed at include/idl_export.h:1365:3)"}(x + 0)
    f === :p && return Ptr{NTuple{4, Cfloat}}(x + 0)
    f === :d_arr && return Ptr{NTuple{4, Cdouble}}(x + 0)
    f === :dev && return Ptr{var"struct (unnamed at include/idl_export.h:1378:3)"}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::IDL_GR_PT, f::Symbol)
    r = Ref{IDL_GR_PT}(x)
    ptr = Base.unsafe_convert(Ptr{IDL_GR_PT}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IDL_GR_PT}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

@cenum IDL_GR_PT_TYPE_e::UInt32 begin
    IDL_GR_PT_UNKNOWN = 0
    IDL_GR_PT_INT_STRUCT = 1
    IDL_GR_PT_FLOAT_STRUCT = 2
    IDL_GR_PT_FLOAT_ARRAY = 3
    IDL_GR_PT_DOUBLE_STRUCT = 4
    IDL_GR_PT_DOUBLE_ARRAY = 5
    IDL_GR_PT_DEV_STRUCT = 4
end

struct IDL_GR_TYPED_PT
    type::IDL_GR_PT_TYPE_e
    coord::Cint
    pt::IDL_GR_PT
end

struct IDL_GR_BOX
    origin::IDL_GR_PT
    size::IDL_GR_PT
end

struct IDL_ATTR_STRUCT
    color::IDL_ULONG
    thick::Cfloat
    linestyle::Cint
    t::Ptr{Cdouble}
    clip::Ptr{Cint}
    ax::Ptr{IDL_AXIS}
    ay::Ptr{IDL_AXIS}
    az::Ptr{IDL_AXIS}
    chl::Cint
end

struct IDL_TEXT_STRUCT
    font::Cint
    axes::Cint
    size::Cfloat
    orien::Cfloat
    align::Cfloat
end

struct IDL_TV_STRUCT
    xsize_exp::Cshort
    ysize_exp::Cshort
    xsize::IDL_LONG
    ysize::IDL_LONG
    chl::Cint
    order::Cint
    color_stride::NTuple{3, Cint}
    image_is_scratch::Cint
    b_per_pixel::Cint
end

# typedef void ( * IDL_DEVCORE_FCN_DRAW ) ( IDL_GR_PT * p0 , IDL_GR_PT * p1 , IDL_ATTR_STRUCT * a )
const IDL_DEVCORE_FCN_DRAW = Ptr{Cvoid}

# typedef void ( * IDL_DEVCORE_FCN_RW_PIXELS ) ( UCHAR * data , int x0 , int y0 , int nx , int ny , int dir , IDL_TV_STRUCT * secondary )
const IDL_DEVCORE_FCN_RW_PIXELS = Ptr{Cvoid}

struct IDL_ROI_STATE
    bInterior::IDLBool_t
    iNAllocEdgeLists::IDL_LONG
    iNUsedEdgeLists::IDL_LONG
    ppEdgeLists::Ptr{Ptr{UCHAR}}
    iBottomY::IDL_LONG64
    iTopY::IDL_LONG64
end

struct var"union (unnamed at include/idl_export.h:1471:3)"
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{var"union (unnamed at include/idl_export.h:1471:3)"}, f::Symbol)
    f === :draw && return Ptr{IDL_DEVCORE_FCN_DRAW}(x + 0)
    f === :rw_pixels && return Ptr{IDL_DEVCORE_FCN_RW_PIXELS}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::var"union (unnamed at include/idl_export.h:1471:3)", f::Symbol)
    r = Ref{var"union (unnamed at include/idl_export.h:1471:3)"}(x)
    ptr = Base.unsafe_convert(Ptr{var"union (unnamed at include/idl_export.h:1471:3)"}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{var"union (unnamed at include/idl_export.h:1471:3)"}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct var"union (unnamed at include/idl_export.h:1475:3)"
    data::NTuple{40, UInt8}
end

function Base.getproperty(x::Ptr{var"union (unnamed at include/idl_export.h:1475:3)"}, f::Symbol)
    f === :image && return Ptr{var"struct (unnamed at include/idl_export.h:1476:5)"}(x + 0)
    f === :lines && return Ptr{var"struct (unnamed at include/idl_export.h:1485:5)"}(x + 0)
    f === :fill_style && return Ptr{Cint}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::var"union (unnamed at include/idl_export.h:1475:3)", f::Symbol)
    r = Ref{var"union (unnamed at include/idl_export.h:1475:3)"}(x)
    ptr = Base.unsafe_convert(Ptr{var"union (unnamed at include/idl_export.h:1475:3)"}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{var"union (unnamed at include/idl_export.h:1475:3)"}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct var"union (unnamed at include/idl_export.h:1494:5)"
    data::NTuple{8, UInt8}
end

function Base.getproperty(x::Ptr{var"union (unnamed at include/idl_export.h:1494:5)"}, f::Symbol)
    f === :f && return Ptr{Ptr{Cfloat}}(x + 0)
    f === :d && return Ptr{Ptr{Cdouble}}(x + 0)
    return getfield(x, f)
end

function Base.getproperty(x::var"union (unnamed at include/idl_export.h:1494:5)", f::Symbol)
    r = Ref{var"union (unnamed at include/idl_export.h:1494:5)"}(x)
    ptr = Base.unsafe_convert(Ptr{var"union (unnamed at include/idl_export.h:1494:5)"}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{var"union (unnamed at include/idl_export.h:1494:5)"}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct var"struct (unnamed at include/idl_export.h:1493:3)"
    data::NTuple{24, UInt8}
end

function Base.getproperty(x::Ptr{var"struct (unnamed at include/idl_export.h:1493:3)"}, f::Symbol)
    f === :z && return Ptr{var"union (unnamed at include/idl_export.h:1494:5)"}(x + 0)
    f === :precision && return Ptr{Cint}(x + 8)
    f === :shades && return Ptr{Ptr{Cint}}(x + 16)
    return getfield(x, f)
end

function Base.getproperty(x::var"struct (unnamed at include/idl_export.h:1493:3)", f::Symbol)
    r = Ref{var"struct (unnamed at include/idl_export.h:1493:3)"}(x)
    ptr = Base.unsafe_convert(Ptr{var"struct (unnamed at include/idl_export.h:1493:3)"}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{var"struct (unnamed at include/idl_export.h:1493:3)"}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

struct IDL_POLYFILL_ATTR
    data::NTuple{96, UInt8}
end

function Base.getproperty(x::Ptr{IDL_POLYFILL_ATTR}, f::Symbol)
    f === :fill_type && return Ptr{Cvoid}(x + 0)
    f === :attr && return Ptr{Ptr{IDL_ATTR_STRUCT}}(x + 8)
    f === :rtn && return Ptr{var"union (unnamed at include/idl_export.h:1471:3)"}(x + 16)
    f === :extra && return Ptr{var"union (unnamed at include/idl_export.h:1475:3)"}(x + 24)
    f === :three && return Ptr{var"struct (unnamed at include/idl_export.h:1493:3)"}(x + 64)
    f === :pROIState && return Ptr{Ptr{IDL_ROI_STATE}}(x + 88)
    return getfield(x, f)
end

function Base.getproperty(x::IDL_POLYFILL_ATTR, f::Symbol)
    r = Ref{IDL_POLYFILL_ATTR}(x)
    ptr = Base.unsafe_convert(Ptr{IDL_POLYFILL_ATTR}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IDL_POLYFILL_ATTR}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

# typedef int ( * IDL_DEVCORE_FCN_TEXT ) ( IDL_GR_PT * p , IDL_ATTR_STRUCT * ga , IDL_TEXT_STRUCT * ta , char * text )
const IDL_DEVCORE_FCN_TEXT = Ptr{Cvoid}

# typedef void ( * IDL_DEVCORE_FCN_ERASE ) ( IDL_ATTR_STRUCT * a )
const IDL_DEVCORE_FCN_ERASE = Ptr{Cvoid}

# typedef void ( * IDL_DEVCORE_FCN_CURSOR ) ( int funct , IDL_MOUSE_STRUCT * m )
const IDL_DEVCORE_FCN_CURSOR = Ptr{Cvoid}

# typedef void ( * IDL_DEVCORE_FCN_POLYFILL ) ( int * x , int * y , int n , IDL_POLYFILL_ATTR * poly )
const IDL_DEVCORE_FCN_POLYFILL = Ptr{Cvoid}

# typedef void ( * IDL_DEVCORE_FCN_INTER_EXIT ) ( void )
const IDL_DEVCORE_FCN_INTER_EXIT = Ptr{Cvoid}

# typedef void ( * IDL_DEVCORE_FCN_FLUSH ) ( void )
const IDL_DEVCORE_FCN_FLUSH = Ptr{Cvoid}

# typedef void ( * IDL_DEVCORE_FCN_LOAD_COLOR ) ( IDL_LONG start , IDL_LONG n )
const IDL_DEVCORE_FCN_LOAD_COLOR = Ptr{Cvoid}

# typedef void ( * IDL_DEVCORE_FCN_DEV_SPECIFIC ) ( int argc , IDL_VPTR * argv , char * argk )
const IDL_DEVCORE_FCN_DEV_SPECIFIC = Ptr{Cvoid}

# typedef void ( * IDL_DEVCORE_FCN_DEV_HELP ) ( int argc , IDL_VPTR * argv )
const IDL_DEVCORE_FCN_DEV_HELP = Ptr{Cvoid}

# typedef void ( * IDL_DEVCORE_FCN_LOAD_RTN ) ( void )
const IDL_DEVCORE_FCN_LOAD_RTN = Ptr{Cvoid}

# typedef void ( * IDL_DEVCORE_FCN_RESET_SESSION ) ( void )
const IDL_DEVCORE_FCN_RESET_SESSION = Ptr{Cvoid}

struct IDL_DEVICE_CORE
    draw::IDL_DEVCORE_FCN_DRAW
    text::IDL_DEVCORE_FCN_TEXT
    erase::IDL_DEVCORE_FCN_ERASE
    cursor::IDL_DEVCORE_FCN_CURSOR
    polyfill::IDL_DEVCORE_FCN_POLYFILL
    inter_exit::IDL_DEVCORE_FCN_INTER_EXIT
    flush::IDL_DEVCORE_FCN_FLUSH
    load_color::IDL_DEVCORE_FCN_LOAD_COLOR
    rw_pixels::IDL_DEVCORE_FCN_RW_PIXELS
    dev_specific::IDL_DEVCORE_FCN_DEV_SPECIFIC
    dev_help::IDL_DEVCORE_FCN_DEV_HELP
    load_rtn::IDL_DEVCORE_FCN_LOAD_RTN
    reset_session::IDL_DEVCORE_FCN_RESET_SESSION
end

struct IDL_DEVICE_WINDOW
    window_create::Ptr{Cvoid}
    window_delete::Ptr{Cvoid}
    window_show::Ptr{Cvoid}
    window_set::Ptr{Cvoid}
    window_menu::Ptr{Cvoid}
end

struct IDL_DEVICE_DEF
    name::IDL_STRING
    t_size::NTuple{2, Cint}
    v_size::NTuple{2, Cint}
    ch_size::NTuple{2, Cint}
    px_cm::NTuple{2, Cfloat}
    n_colors::Cint
    table_size::Cint
    fill_dist::Cint
    window::Cint
    unit::Cint
    flags::Cint
    origin::NTuple{2, Cint}
    zoom::NTuple{2, Cint}
    aspect::Cfloat
    core::IDL_DEVICE_CORE
    winsys::IDL_DEVICE_WINDOW
    reserved::Ptr{Cchar}
end

struct IDL_PLOT_COM
    background::Cint
    charsize::Cfloat
    charthick::Cfloat
    clip::NTuple{6, Cint}
    color::IDL_ULONG
    font::Cint
    linestyle::Cint
    multi::NTuple{5, Cint}
    clip_off::Cint
    noerase::Cint
    nsum::Cint
    position::NTuple{4, Cfloat}
    psym::Cint
    region::NTuple{4, Cfloat}
    subtitle::IDL_STRING
    symsize::Cfloat
    t::NTuple{16, Cdouble}
    t3d_on::Cint
    thick::Cfloat
    title::IDL_STRING
    ticklen::Cfloat
    chl::Cint
    sr_restore_pad::Cdouble
    dev::Ptr{IDL_DEVICE_DEF}
end

struct IDL_KW_PAR
    keyword::Ptr{Cchar}
    type::UCHAR
    mask::Cushort
    flags::Cushort
    specified::Ptr{Cint}
    value::Ptr{Cchar}
end

struct IDL_KW_ARR_DESC
    data::Ptr{Cchar}
    nmin::IDL_LONG64
    nmax::IDL_LONG64
    n::IDL_LONG64
end

struct IDL_KW_ARR_DESC_R
    data::Ptr{Cchar}
    nmin::IDL_LONG64
    nmax::IDL_LONG64
    n_offset::Ptr{IDL_LONG64}
end

function IDL_KWGetParams(argc, argv, argk, kw_list, plain_args, mask)
    ccall((:IDL_KWGetParams, libidl), Cint, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}, Ptr{IDL_KW_PAR}, Ptr{IDL_VPTR}, Cint), argc, argv, argk, kw_list, plain_args, mask)
end

function IDL_KWCleanup(fcn)
    ccall((:IDL_KWCleanup, libidl), Cvoid, (Cint,), fcn)
end

const IDL_ATIME_BUF = NTuple{25, Cchar}

struct IDL_USER_INFO
    logname::Ptr{Cchar}
    homedir::Ptr{Cchar}
    pid::Ptr{Cchar}
    host::NTuple{64, Cchar}
    wd::NTuple{1025, Cchar}
    date::IDL_ATIME_BUF
end

@cenum IDL_GETKBRD_T::UInt32 begin
    IDL_GETKBRD_T_CH = 0
    IDL_GETKBRD_T_CH_OR_ESC = 1
    IDL_GETKBRD_T_CH_OR_NAME = 2
end

const IDL_GETKBRD_BUFFER = NTuple{128, Cchar}

struct IDL_POUT_CNTRL
    unit::Cint
    curcol::Cint
    wrap::Cint
    leading::Ptr{Cchar}
    leading_len::Cint
    buf::Ptr{Cchar}
    max_len::Cint
end

struct idl_heap_variable
    hash::Ptr{idl_heap_variable}
    hash_id::IDL_HVID
    refcount::IDL_LONG
    flags::Cint
    var::IDL_VARIABLE
end

const IDL_HEAP_VARIABLE = idl_heap_variable

const IDL_HEAP_VPTR = Ptr{IDL_HEAP_VARIABLE}

struct IDL_RASTER_DEF
    fb::Ptr{UCHAR}
    nx::Cint
    ny::Cint
    bytes_line::Cint
    byte_padding::Cint
    dot_width::Cint
    dither_method::Cint
    dither_threshold::Cint
    bit_tab::NTuple{8, UCHAR}
    flags::Cint
end

const IDL_SFILE_PIPE_EXIT_STATUS = IDL_LONG

struct IDL_SFILE_STAT_TIME
    access::IDL_LONG64
    create::IDL_LONG64
    mod::IDL_LONG64
end

struct IDL_SignalSet_t
    set::NTuple{4, Cdouble}
end

# typedef void ( * IDL_SignalHandler_t ) ( int signo )
const IDL_SignalHandler_t = Ptr{Cvoid}

struct IDL_STRUCT_TAG_DEF
    name::Ptr{Cchar}
    dims::Ptr{IDL_LONG64}
    type::Ptr{Cvoid}
    flags::UCHAR
end

struct IDL_SYSFUN_DEF
    funct_addr::IDL_SYSRTN_GENERIC
    name::Ptr{Cchar}
    arg_min::UCHAR
    arg_max::UCHAR
    flags::UCHAR
end

# typedef void ( * IDL_TOUT_OUTF ) ( int flags , char * buf , int n )
const IDL_TOUT_OUTF = Ptr{Cvoid}

const IDL_INIT_DATA_OPTIONS_T = Cint

struct var"struct (unnamed at include/idl_export.h:2375:3)"
    argc::Cint
    argv::Ptr{Ptr{Cchar}}
end

struct var"struct (unnamed at include/idl_export.h:2390:3)"
    id::Ptr{Cchar}
    data::Ptr{Cuchar}
    length::Cint
end

struct IDL_INIT_DATA
    data::NTuple{56, UInt8}
end

function Base.getproperty(x::Ptr{IDL_INIT_DATA}, f::Symbol)
    f === :options && return Ptr{IDL_INIT_DATA_OPTIONS_T}(x + 0)
    f === :clargs && return Ptr{var"struct (unnamed at include/idl_export.h:2375:3)"}(x + 8)
    f === :hwnd && return Ptr{Ptr{Cvoid}}(x + 24)
    f === :bufferlicense && return Ptr{var"struct (unnamed at include/idl_export.h:2390:3)"}(x + 32)
    return getfield(x, f)
end

function Base.getproperty(x::IDL_INIT_DATA, f::Symbol)
    r = Ref{IDL_INIT_DATA}(x)
    ptr = Base.unsafe_convert(Ptr{IDL_INIT_DATA}, r)
    fptr = getproperty(ptr, f)
    GC.@preserve r unsafe_load(fptr)
end

function Base.setproperty!(x::Ptr{IDL_INIT_DATA}, f::Symbol, v)
    unsafe_store!(getproperty(x, f), v)
end

# typedef void ( * IDL_WIDGET_STUB_SET_SIZE_FUNC ) ( IDL_ULONG id , int width , int height )
const IDL_WIDGET_STUB_SET_SIZE_FUNC = Ptr{Cvoid}

struct IDL_TERMINFO
    lines::Cint
    columns::Cint
end

struct IDL_FILE_STAT
    name::Ptr{Cchar}
    access::Cshort
    flags::IDL_SFILE_FLAGS_T
    fptr::Ptr{Cint}
end

# typedef void ( * IDL_TIMER_CB ) ( void )
const IDL_TIMER_CB = Ptr{Cvoid}

const IDL_TIMER_CONTEXT = IDL_TIMER_CB

const IDL_TIMER_CONTEXT_PTR = Ptr{IDL_TIMER_CONTEXT}

function IDL_Win32MessageLoop(fFlush)
    ccall((:IDL_Win32MessageLoop, libidl), Cvoid, (Cint,), fFlush)
end

function IDL_PoutRaw(unit, buf, n)
    ccall((:IDL_PoutRaw, libidl), Cvoid, (Cint, Ptr{Cchar}, Cint), unit, buf, n)
end

function IDL_TerminalRaw(to_from, fnin)
    ccall((:IDL_TerminalRaw, libidl), Cvoid, (Cint, Cint), to_from, fnin)
end

function IDL_WinPostInit()
    ccall((:IDL_WinPostInit, libidl), Cvoid, ())
end

function IDL_WinCleanup()
    ccall((:IDL_WinCleanup, libidl), Cvoid, ())
end

function IDL_MemAlloc(n, err_str, msg_action)
    ccall((:IDL_MemAlloc, libidl), Ptr{Cvoid}, (IDL_LONG64, Ptr{Cchar}, Cint), n, err_str, msg_action)
end

function IDL_MemRealloc(ptr, n, err_str, action)
    ccall((:IDL_MemRealloc, libidl), Ptr{Cvoid}, (Ptr{Cvoid}, IDL_LONG64, Ptr{Cchar}, Cint), ptr, n, err_str, action)
end

function IDL_MemFree(m, err_str, msg_action)
    ccall((:IDL_MemFree, libidl), Cvoid, (Ptr{Cvoid}, Ptr{Cchar}, Cint), m, err_str, msg_action)
end

function IDL_MemAllocPerm(n, err_str, action)
    ccall((:IDL_MemAllocPerm, libidl), Ptr{Cvoid}, (IDL_LONG64, Ptr{Cchar}, Cint), n, err_str, action)
end

function IDL_MakeTempStruct(sdef, n_dim, dim, var, zero)
    ccall((:IDL_MakeTempStruct, libidl), Ptr{Cchar}, (IDL_StructDefPtr, Cint, Ptr{IDL_LONG64}, Ptr{IDL_VPTR}, Cint), sdef, n_dim, dim, var, zero)
end

function IDL_MakeTempStructVector(sdef, dim, var, zero)
    ccall((:IDL_MakeTempStructVector, libidl), Ptr{Cchar}, (IDL_StructDefPtr, IDL_LONG64, Ptr{IDL_VPTR}, Cint), sdef, dim, var, zero)
end

function IDL_MakeStruct(name, tags)
    ccall((:IDL_MakeStruct, libidl), IDL_StructDefPtr, (Ptr{Cchar}, Ptr{IDL_STRUCT_TAG_DEF}), name, tags)
end

function IDL_StructTagInfoByName(sdef, name, msg_action, var)
    ccall((:IDL_StructTagInfoByName, libidl), IDL_LONG64, (IDL_StructDefPtr, Ptr{Cchar}, Cint, Ptr{IDL_VPTR}), sdef, name, msg_action, var)
end

function IDL_StructTagInfoByIndex(sdef, index, msg_action, var)
    ccall((:IDL_StructTagInfoByIndex, libidl), IDL_LONG64, (IDL_StructDefPtr, Cint, Cint, Ptr{IDL_VPTR}), sdef, index, msg_action, var)
end

function IDL_StructTagNameByIndex(sdef, index, msg_action, struct_name)
    ccall((:IDL_StructTagNameByIndex, libidl), Ptr{Cchar}, (IDL_StructDefPtr, Cint, Cint, Ptr{Ptr{Cchar}}), sdef, index, msg_action, struct_name)
end

function IDL_StructNumTags(sdef)
    ccall((:IDL_StructNumTags, libidl), Cint, (IDL_StructDefPtr,), sdef)
end

function IDL_VarName(v)
    ccall((:IDL_VarName, libidl), Ptr{Cchar}, (IDL_VPTR,), v)
end

function IDL_GetVarAddr1(name, ienter)
    ccall((:IDL_GetVarAddr1, libidl), IDL_VPTR, (Ptr{Cchar}, Cint), name, ienter)
end

function IDL_GetVarAddr(name)
    ccall((:IDL_GetVarAddr, libidl), IDL_VPTR, (Ptr{Cchar},), name)
end

function IDL_FindNamedVariableLevel(name, ienter, level)
    ccall((:IDL_FindNamedVariableLevel, libidl), IDL_VPTR, (Ptr{Cchar}, Cint, Cint), name, ienter, level)
end

function IDL_FindNamedVariable(name, ienter)
    ccall((:IDL_FindNamedVariable, libidl), IDL_VPTR, (Ptr{Cchar}, Cint), name, ienter)
end

function IDL_Rline(s, n, unit, stream, is_tty, prompt, opt)
    ccall((:IDL_Rline, libidl), Ptr{Cchar}, (Ptr{Cchar}, IDL_LONG64, Cint, Ptr{Cint}, Cint, Ptr{Cchar}, Cint), s, n, unit, stream, is_tty, prompt, opt)
end

function IDL_RlineSetStdinOptions(opt)
    ccall((:IDL_RlineSetStdinOptions, libidl), Cvoid, (Cint,), opt)
end

function IDL_Logit(s)
    ccall((:IDL_Logit, libidl), Cvoid, (Ptr{Cchar},), s)
end

function IDL_InitOCX(pInit)
    ccall((:IDL_InitOCX, libidl), Cint, (Ptr{Cvoid},), pInit)
end

function IDL_MessageNameToCode(block, name)
    ccall((:IDL_MessageNameToCode, libidl), Cint, (IDL_MSG_BLOCK, Ptr{Cchar}), block, name)
end

function IDL_MessageDefineBlock(block_name, n, defs)
    ccall((:IDL_MessageDefineBlock, libidl), IDL_MSG_BLOCK, (Ptr{Cchar}, Cint, Ptr{IDL_MSG_DEF}), block_name, n, defs)
end

function IDL_MessageVarError(code, var, action)
    ccall((:IDL_MessageVarError, libidl), Cvoid, (Cint, IDL_VPTR, Cint), code, var, action)
end

function IDL_MessageVarErrorFromBlock(block, code, var, action)
    ccall((:IDL_MessageVarErrorFromBlock, libidl), Cvoid, (IDL_MSG_BLOCK, Cint, IDL_VPTR, Cint), block, code, var, action)
end

function IDL_MessageResetSysvErrorState()
    ccall((:IDL_MessageResetSysvErrorState, libidl), Cvoid, ())
end

function IDL_MessageSJE(value)
    ccall((:IDL_MessageSJE, libidl), Cvoid, (Ptr{Cvoid},), value)
end

function IDL_MessageGJE()
    ccall((:IDL_MessageGJE, libidl), Ptr{Cvoid}, ())
end

function IDL_Message_BADARRDNUM(action)
    ccall((:IDL_Message_BADARRDNUM, libidl), Cvoid, (Cint,), action)
end

function IDL_AppUserDirRootPath()
    ccall((:IDL_AppUserDirRootPath, libidl), Ptr{Cchar}, ())
end

function IDL_scope_varfetch(argc, argv, argk)
    ccall((:IDL_scope_varfetch, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

function IDL_SysvVersionArch()
    ccall((:IDL_SysvVersionArch, libidl), Ptr{IDL_STRING}, ())
end

function IDL_SysvVersionOS()
    ccall((:IDL_SysvVersionOS, libidl), Ptr{IDL_STRING}, ())
end

function IDL_SysvVersionOSFamily()
    ccall((:IDL_SysvVersionOSFamily, libidl), Ptr{IDL_STRING}, ())
end

function IDL_SysvVersionRelease()
    ccall((:IDL_SysvVersionRelease, libidl), Ptr{IDL_STRING}, ())
end

function IDL_ProgramNameFunc()
    ccall((:IDL_ProgramNameFunc, libidl), Ptr{Cchar}, ())
end

function IDL_ProgramNameLCFunc()
    ccall((:IDL_ProgramNameLCFunc, libidl), Ptr{Cchar}, ())
end

function IDL_SysvDirFunc()
    ccall((:IDL_SysvDirFunc, libidl), Ptr{IDL_STRING}, ())
end

function IDL_SysvErrCodeValue()
    ccall((:IDL_SysvErrCodeValue, libidl), IDL_LONG, ())
end

function IDL_SysvErrorStateAddr()
    ccall((:IDL_SysvErrorStateAddr, libidl), Ptr{IDL_SYS_ERROR_STATE}, ())
end

function IDL_SysvErrStringFunc()
    ccall((:IDL_SysvErrStringFunc, libidl), Ptr{IDL_STRING}, ())
end

function IDL_SysvSyserrStringFunc()
    ccall((:IDL_SysvSyserrStringFunc, libidl), Ptr{IDL_STRING}, ())
end

function IDL_SysvErrorCodeValue()
    ccall((:IDL_SysvErrorCodeValue, libidl), IDL_LONG, ())
end

function IDL_SysvSyserrorCodesAddr()
    ccall((:IDL_SysvSyserrorCodesAddr, libidl), Ptr{IDL_LONG}, ())
end

function IDL_SysvOrderValue()
    ccall((:IDL_SysvOrderValue, libidl), IDL_LONG, ())
end

function IDL_SysvValuesGetFloat(type)
    ccall((:IDL_SysvValuesGetFloat, libidl), Cfloat, (Cint,), type)
end

function IDL_SysvValuesGetDouble(type)
    ccall((:IDL_SysvValuesGetDouble, libidl), Cdouble, (Cint,), type)
end

function IDL_SignalSetInit(set, signo)
    ccall((:IDL_SignalSetInit, libidl), Cvoid, (Ptr{IDL_SignalSet_t}, Cint), set, signo)
end

function IDL_SignalSetAdd(set, signo)
    ccall((:IDL_SignalSetAdd, libidl), Cvoid, (Ptr{IDL_SignalSet_t}, Cint), set, signo)
end

function IDL_SignalSetDel(set, signo)
    ccall((:IDL_SignalSetDel, libidl), Cvoid, (Ptr{IDL_SignalSet_t}, Cint), set, signo)
end

function IDL_SignalSetIsMember(set, signo)
    ccall((:IDL_SignalSetIsMember, libidl), Cint, (Ptr{IDL_SignalSet_t}, Cint), set, signo)
end

function IDL_SignalMaskGet(set)
    ccall((:IDL_SignalMaskGet, libidl), Cvoid, (Ptr{IDL_SignalSet_t},), set)
end

function IDL_SignalMaskSet(set, oset)
    ccall((:IDL_SignalMaskSet, libidl), Cvoid, (Ptr{IDL_SignalSet_t}, Ptr{IDL_SignalSet_t}), set, oset)
end

function IDL_SignalMaskBlock(set, oset)
    ccall((:IDL_SignalMaskBlock, libidl), Cvoid, (Ptr{IDL_SignalSet_t}, Ptr{IDL_SignalSet_t}), set, oset)
end

function IDL_SignalBlock(signo, oset)
    ccall((:IDL_SignalBlock, libidl), Cvoid, (Cint, Ptr{IDL_SignalSet_t}), signo, oset)
end

function IDL_SignalSuspend(set)
    ccall((:IDL_SignalSuspend, libidl), Cvoid, (Ptr{IDL_SignalSet_t},), set)
end

function IDL_SignalRegister(signo, func, msg_action)
    ccall((:IDL_SignalRegister, libidl), Cint, (Cint, IDL_SignalHandler_t, Cint), signo, func, msg_action)
end

function IDL_SignalUnregister(signo, func, msg_action)
    ccall((:IDL_SignalUnregister, libidl), Cint, (Cint, IDL_SignalHandler_t, Cint), signo, func, msg_action)
end

function IDL_FilePathFromRoot(flags, pathbuf, root, file, ext, nsubdir, subdir)
    ccall((:IDL_FilePathFromRoot, libidl), Ptr{Cchar}, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Cint, Ptr{Ptr{Cchar}}), flags, pathbuf, root, file, ext, nsubdir, subdir)
end

function IDL_FilePathFromRootW(flags, pathbuf, root, file, ext, nsubdir, subdir)
    ccall((:IDL_FilePathFromRootW, libidl), Ptr{Cwchar_t}, (Cint, Ptr{Cwchar_t}, Ptr{Cwchar_t}, Ptr{Cwchar_t}, Ptr{Cwchar_t}, Cint, Ptr{Ptr{Cwchar_t}}), flags, pathbuf, root, file, ext, nsubdir, subdir)
end

function IDL_FilePathFromDist(flags, pathbuf, file, ext, nsubdir, subdir)
    ccall((:IDL_FilePathFromDist, libidl), Ptr{Cchar}, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Cint, Ptr{Ptr{Cchar}}), flags, pathbuf, file, ext, nsubdir, subdir)
end

function IDL_FilePathFromDistW(flags, pathbuf, file, ext, nsubdir, subdir)
    ccall((:IDL_FilePathFromDistW, libidl), Ptr{Cwchar_t}, (Cint, Ptr{Cwchar_t}, Ptr{Cwchar_t}, Ptr{Cwchar_t}, Cint, Ptr{Ptr{Cwchar_t}}), flags, pathbuf, file, ext, nsubdir, subdir)
end

function IDL_FilePathFromDistBin(flags, pathbuf, file, ext)
    ccall((:IDL_FilePathFromDistBin, libidl), Ptr{Cchar}, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}), flags, pathbuf, file, ext)
end

function IDL_FilePathFromDistBinW(flags, pathbuf, file, ext)
    ccall((:IDL_FilePathFromDistBinW, libidl), Ptr{Cwchar_t}, (Cint, Ptr{Cwchar_t}, Ptr{Cwchar_t}, Ptr{Cwchar_t}), flags, pathbuf, file, ext)
end

function IDL_FilePathFromDistHelp(flags, pathbuf, file, ext)
    ccall((:IDL_FilePathFromDistHelp, libidl), Ptr{Cchar}, (Cint, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}), flags, pathbuf, file, ext)
end

function IDL_FilePathFromDistHelpW(flags, pathbuf, file, ext)
    ccall((:IDL_FilePathFromDistHelpW, libidl), Ptr{Cwchar_t}, (Cint, Ptr{Cwchar_t}, Ptr{Cwchar_t}, Ptr{Cwchar_t}), flags, pathbuf, file, ext)
end

function IDL_FilePathGetTmpDir(path)
    ccall((:IDL_FilePathGetTmpDir, libidl), Cvoid, (Ptr{Cchar},), path)
end

function IDL_FilePathGetTmpDirW(path)
    ccall((:IDL_FilePathGetTmpDirW, libidl), Cvoid, (Ptr{Cwchar_t},), path)
end

function IDL_FilePathExpand(path, msg_action)
    ccall((:IDL_FilePathExpand, libidl), Cint, (Ptr{Cchar}, Cint), path, msg_action)
end

function IDL_FilePathExpandW(wcharPath, msg_action)
    ccall((:IDL_FilePathExpandW, libidl), Cint, (Ptr{Cwchar_t}, Cint), wcharPath, msg_action)
end

function IDL_FilePathSearch(argc, argv, argk)
    ccall((:IDL_FilePathSearch, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

function IDL_MakeTempArray(type, n_dim, dim, init, var)
    ccall((:IDL_MakeTempArray, libidl), Ptr{Cchar}, (Cint, Cint, Ptr{IDL_LONG64}, Cint, Ptr{IDL_VPTR}), type, n_dim, dim, init, var)
end

function IDL_MakeTempVector(type, dim, init, var)
    ccall((:IDL_MakeTempVector, libidl), Ptr{Cchar}, (Cint, IDL_LONG64, Cint, Ptr{IDL_VPTR}), type, dim, init, var)
end

function IDL_ToutPush(outf)
    ccall((:IDL_ToutPush, libidl), Cvoid, (IDL_TOUT_OUTF,), outf)
end

function IDL_ToutPop()
    ccall((:IDL_ToutPop, libidl), IDL_TOUT_OUTF, ())
end

function IDL_ExitRegister(proc)
    ccall((:IDL_ExitRegister, libidl), Cvoid, (IDL_EXIT_HANDLER_FUNC,), proc)
end

function IDL_ExitUnregister(proc)
    ccall((:IDL_ExitUnregister, libidl), Cvoid, (IDL_EXIT_HANDLER_FUNC,), proc)
end

function IDL_CvtVAXToFloat(fp, n)
    ccall((:IDL_CvtVAXToFloat, libidl), Cvoid, (Ptr{Cfloat}, IDL_LONG64), fp, n)
end

function IDL_CvtFloatToVAX(fp, n)
    ccall((:IDL_CvtFloatToVAX, libidl), Cvoid, (Ptr{Cfloat}, IDL_LONG64), fp, n)
end

function IDL_CvtVAXToDouble(dp, n)
    ccall((:IDL_CvtVAXToDouble, libidl), Cvoid, (Ptr{Cdouble}, IDL_LONG64), dp, n)
end

function IDL_CvtDoubleToVAX(dp, n)
    ccall((:IDL_CvtDoubleToVAX, libidl), Cvoid, (Ptr{Cdouble}, IDL_LONG64), dp, n)
end

function IDL_HeapVarHashFind(hash_id)
    ccall((:IDL_HeapVarHashFind, libidl), IDL_HEAP_VPTR, (IDL_HVID,), hash_id)
end

function IDL_HeapVarNew(hvid_type, value, flags, msg_action)
    ccall((:IDL_HeapVarNew, libidl), IDL_HEAP_VPTR, (Cint, IDL_VPTR, Cint, Cint), hvid_type, value, flags, msg_action)
end

function IDL_HeapIncrRefCount(hvid, n)
    ccall((:IDL_HeapIncrRefCount, libidl), Cvoid, (Ptr{IDL_HVID}, IDL_LONG64), hvid, n)
end

function IDL_HeapDecrRefCount(hvid, n)
    ccall((:IDL_HeapDecrRefCount, libidl), Cvoid, (Ptr{IDL_HVID}, IDL_LONG64), hvid, n)
end

function IDL_ObjCallMethodByString(methName, obj, result, argc, argv, argk)
    ccall((:IDL_ObjCallMethodByString, libidl), Cint, (Ptr{Cchar}, IDL_HVID, Ptr{IDL_VPTR}, Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), methName, obj, result, argc, argv, argk)
end

function IDL_ObjNewCreateBaseVar(classname_v)
    ccall((:IDL_ObjNewCreateBaseVar, libidl), IDL_HEAP_VPTR, (IDL_VPTR,), classname_v)
end

function IDL_ObjNew(argc, argv, argk)
    ccall((:IDL_ObjNew, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

function IDL_ObjIsA(argc, argv)
    ccall((:IDL_ObjIsA, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_TimerSet(length, callback, from_callback, context)
    ccall((:IDL_TimerSet, libidl), Cvoid, (IDL_LONG, IDL_TIMER_CB, Cint, IDL_TIMER_CONTEXT_PTR), length, callback, from_callback, context)
end

function IDL_TimerCancel(context)
    ccall((:IDL_TimerCancel, libidl), Cvoid, (IDL_TIMER_CONTEXT,), context)
end

function IDL_TimerBlock(stop)
    ccall((:IDL_TimerBlock, libidl), Cvoid, (Cint,), stop)
end

function IDL_EzCall(argc, argv, arg_struct)
    ccall((:IDL_EzCall, libidl), Cvoid, (Cint, Ptr{IDL_VPTR}, Ptr{IDL_EZ_ARG}), argc, argv, arg_struct)
end

function IDL_EzCallCleanup(argc, argv, arg_struct)
    ccall((:IDL_EzCallCleanup, libidl), Cvoid, (Cint, Ptr{IDL_VPTR}, Ptr{IDL_EZ_ARG}), argc, argv, arg_struct)
end

function IDL_EzReplaceWithTranspose(v, orig)
    ccall((:IDL_EzReplaceWithTranspose, libidl), Cvoid, (Ptr{IDL_VPTR}, IDL_VPTR), v, orig)
end

function IDL_PlotComAddr()
    ccall((:IDL_PlotComAddr, libidl), Ptr{IDL_PLOT_COM}, ())
end

function IDL_ColorMapAddr()
    ccall((:IDL_ColorMapAddr, libidl), Ptr{UCHAR}, ())
end

function IDL_PolyfillSoftware(x, y, n, s)
    ccall((:IDL_PolyfillSoftware, libidl), Cvoid, (Ptr{Cint}, Ptr{Cint}, Cint, Ptr{IDL_POLYFILL_ATTR}), x, y, n, s)
end

function IDL_GraphText(p, ga, a, text)
    ccall((:IDL_GraphText, libidl), Cdouble, (Ptr{IDL_GR_PT}, Ptr{IDL_ATTR_STRUCT}, Ptr{IDL_TEXT_STRUCT}, Ptr{Cchar}), p, ga, a, text)
end

function IDL_WidgetIssueStubEvent(rec, value)
    ccall((:IDL_WidgetIssueStubEvent, libidl), Cvoid, (Ptr{Cchar}, IDL_LONG), rec, value)
end

function IDL_WidgetSetStubIds(rec, t_id, b_id)
    ccall((:IDL_WidgetSetStubIds, libidl), Cvoid, (Ptr{Cchar}, Culong, Culong), rec, t_id, b_id)
end

function IDL_WidgetGetStubIds(rec, t_id, b_id)
    ccall((:IDL_WidgetGetStubIds, libidl), Cvoid, (Ptr{Cchar}, Ptr{Culong}, Ptr{Culong}), rec, t_id, b_id)
end

function IDL_WidgetStubLock(set)
    ccall((:IDL_WidgetStubLock, libidl), Cvoid, (Cint,), set)
end

function IDL_WidgetStubGetParent(id, szDisplay)
    ccall((:IDL_WidgetStubGetParent, libidl), Ptr{Cvoid}, (IDL_ULONG, Ptr{Cchar}), id, szDisplay)
end

function IDL_WidgetStubLookup(id)
    ccall((:IDL_WidgetStubLookup, libidl), Ptr{Cchar}, (IDL_ULONG,), id)
end

function IDL_WidgetStubSetSizeFunc(rec, func)
    ccall((:IDL_WidgetStubSetSizeFunc, libidl), Cvoid, (Ptr{Cchar}, IDL_WIDGET_STUB_SET_SIZE_FUNC), rec, func)
end

function IDL_Wait(argc, argv)
    ccall((:IDL_Wait, libidl), Cvoid, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_GetUserIDAsString(s, n)
    ccall((:IDL_GetUserIDAsString, libidl), Ptr{Cchar}, (Ptr{Cchar}, Csize_t), s, n)
end

function IDL_GetProcessIDAsString(s, n)
    ccall((:IDL_GetProcessIDAsString, libidl), Ptr{Cchar}, (Ptr{Cchar}, Csize_t), s, n)
end

function IDL_GetUserInfo(user_info)
    ccall((:IDL_GetUserInfo, libidl), Cvoid, (Ptr{IDL_USER_INFO},), user_info)
end

function IDL_GetKbrd(should_wait)
    ccall((:IDL_GetKbrd, libidl), Cint, (Cint,), should_wait)
end

function IDL_TTYReset()
    ccall((:IDL_TTYReset, libidl), Cvoid, ())
end

function IDL_FileTermName()
    ccall((:IDL_FileTermName, libidl), Ptr{Cchar}, ())
end

function IDL_FileTermIsTty()
    ccall((:IDL_FileTermIsTty, libidl), Cint, ())
end

function IDL_FileTermLines()
    ccall((:IDL_FileTermLines, libidl), Cint, ())
end

function IDL_FileTermColumns()
    ccall((:IDL_FileTermColumns, libidl), Cint, ())
end

function IDL_FileEnsureStatus(action, unit, flags)
    ccall((:IDL_FileEnsureStatus, libidl), Cint, (Cint, Cint, Cint), action, unit, flags)
end

function IDL_FileSetMode(unit, binary)
    ccall((:IDL_FileSetMode, libidl), Cvoid, (Cint, Cint), unit, binary)
end

function IDL_FileOpenUnitBasic(unit, filename, access_mode, flags, msg_action, errstate)
    ccall((:IDL_FileOpenUnitBasic, libidl), Cint, (Cint, Ptr{Cchar}, Cint, IDL_SFILE_FLAGS_T, Cint, IDL_MSG_ERRSTATE_PTR), unit, filename, access_mode, flags, msg_action, errstate)
end

function IDL_FileOpen(argc, argv, argk, access_mode, extra_flags, longjmp_safe, msg_attr)
    ccall((:IDL_FileOpen, libidl), Cint, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}, Cint, IDL_SFILE_FLAGS_T, Cint, Cint), argc, argv, argk, access_mode, extra_flags, longjmp_safe, msg_attr)
end

function IDL_FileCloseUnit(unit, flags, exit_status, msg_action, errstate)
    ccall((:IDL_FileCloseUnit, libidl), Cint, (Cint, Cint, Ptr{IDL_SFILE_PIPE_EXIT_STATUS}, Cint, IDL_MSG_ERRSTATE_PTR), unit, flags, exit_status, msg_action, errstate)
end

function IDL_FileClose(argc, argv, argk)
    ccall((:IDL_FileClose, libidl), Cvoid, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

function IDL_FileFlushUnit(unit)
    ccall((:IDL_FileFlushUnit, libidl), Cvoid, (Cint,), unit)
end

function IDL_FileGetUnit(argc, argv)
    ccall((:IDL_FileGetUnit, libidl), Cvoid, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_FileFreeUnit(argc, argv)
    ccall((:IDL_FileFreeUnit, libidl), Cvoid, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_FileSetPtr(unit, pos, extend, msg_action)
    ccall((:IDL_FileSetPtr, libidl), Cint, (Cint, IDL_LONG64, Cint, Cint), unit, pos, extend, msg_action)
end

function IDL_FileEOF(unit)
    ccall((:IDL_FileEOF, libidl), Cint, (Cint,), unit)
end

function IDL_FileStat(unit, stat_blk)
    ccall((:IDL_FileStat, libidl), Cvoid, (Cint, Ptr{IDL_FILE_STAT}), unit, stat_blk)
end

function IDL_FileVaxFloat(argc, argv, argk)
    ccall((:IDL_FileVaxFloat, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

function IDL_SysRtnAdd(defs, is_function, cnt)
    ccall((:IDL_SysRtnAdd, libidl), Cint, (Ptr{IDL_SYSFUN_DEF2}, Cint, Cint), defs, is_function, cnt)
end

function IDL_SysRtnNumEnabled(is_function, enabled)
    ccall((:IDL_SysRtnNumEnabled, libidl), IDL_LONG64, (Cint, Cint), is_function, enabled)
end

function IDL_SysRtnGetEnabledNames(is_function, str, enabled)
    ccall((:IDL_SysRtnGetEnabledNames, libidl), Cvoid, (Cint, Ptr{IDL_STRING}, Cint), is_function, str, enabled)
end

function IDL_SysRtnEnable(is_function, names, n, option, disfcn)
    ccall((:IDL_SysRtnEnable, libidl), Cvoid, (Cint, Ptr{IDL_STRING}, IDL_LONG64, Cint, IDL_SYSRTN_GENERIC), is_function, names, n, option, disfcn)
end

function IDL_SysRtnGetRealPtr(is_function, name)
    ccall((:IDL_SysRtnGetRealPtr, libidl), IDL_SYSRTN_GENERIC, (Cint, Ptr{Cchar}), is_function, name)
end

function IDL_SysRtnGetCurrentName()
    ccall((:IDL_SysRtnGetCurrentName, libidl), Ptr{Cchar}, ())
end

function IDL_AddSystemRoutine(defs, is_function, cnt)
    ccall((:IDL_AddSystemRoutine, libidl), Cint, (Ptr{IDL_SYSFUN_DEF}, Cint, Cint), defs, is_function, cnt)
end

function IDL_LMGRLicenseInfo(iFlags)
    ccall((:IDL_LMGRLicenseInfo, libidl), Cint, (Cint,), iFlags)
end

function IDL_LMGRSetLicenseInfo(iFlags)
    ccall((:IDL_LMGRSetLicenseInfo, libidl), Cint, (Cint,), iFlags)
end

function IDL_LMGRLicenseCheckout(szFeature, szVersion)
    ccall((:IDL_LMGRLicenseCheckout, libidl), Cint, (Ptr{Cchar}, Ptr{Cchar}), szFeature, szVersion)
end

function IDL_OutputFormatFunc(type)
    ccall((:IDL_OutputFormatFunc, libidl), Ptr{Cchar}, (Cint,), type)
end

function IDL_OutputFormatLenFunc(type)
    ccall((:IDL_OutputFormatLenFunc, libidl), Cint, (Cint,), type)
end

function IDL_TypeSizeFunc(type)
    ccall((:IDL_TypeSizeFunc, libidl), Cint, (Cint,), type)
end

function IDL_TypeNameFunc(type)
    ccall((:IDL_TypeNameFunc, libidl), Ptr{Cchar}, (Cint,), type)
end

function IDL_nonavailable_rtn(argc, argv, argk)
    ccall((:IDL_nonavailable_rtn, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

# no prototype is found for this function at idl_export.h:3042:22, please use with caution
function IDL_GetExitStatus()
    ccall((:IDL_GetExitStatus, libidl), Cint, ())
end

function IDL_BailOut(stop)
    ccall((:IDL_BailOut, libidl), Cint, (Cint,), stop)
end

function IDL_Cleanup(just_cleanup)
    ccall((:IDL_Cleanup, libidl), Cint, (Cint,), just_cleanup)
end

function IDL_Initialize(init_data)
    ccall((:IDL_Initialize, libidl), Cint, (Ptr{IDL_INIT_DATA},), init_data)
end

function IDL_Init(options, argc, argv)
    ccall((:IDL_Init, libidl), Cint, (IDL_INIT_DATA_OPTIONS_T, Ptr{Cint}, Ptr{Ptr{Cchar}}), options, argc, argv)
end

function IDL_Win32Init(iOpts, hinstExe, hwndExe, hAccel)
    ccall((:IDL_Win32Init, libidl), Cint, (IDL_INIT_DATA_OPTIONS_T, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), iOpts, hinstExe, hwndExe, hAccel)
end

function IDL_Main(argc, argv)
    ccall((:IDL_Main, libidl), Cint, (Cint, Ptr{Ptr{Cchar}}), argc, argv)
end

function IDL_ExecuteStr(cmd)
    ccall((:IDL_ExecuteStr, libidl), Cint, (Ptr{Cchar},), cmd)
end

function IDL_Execute(argc, argv)
    ccall((:IDL_Execute, libidl), Cint, (Cint, Ptr{Ptr{Cchar}}), argc, argv)
end

function IDL_RuntimeExec(file)
    ccall((:IDL_RuntimeExec, libidl), Cint, (Ptr{Cchar},), file)
end

function IDL_unform_io(type, argc, argv, argk)
    ccall((:IDL_unform_io, libidl), Cvoid, (Cint, Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), type, argc, argv, argk)
end

function IDL_Print(argc, argv, argk)
    ccall((:IDL_Print, libidl), Cvoid, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

function IDL_PrintF(argc, argv, argk)
    ccall((:IDL_PrintF, libidl), Cvoid, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

function IDL_VarCopy(src, dst)
    ccall((:IDL_VarCopy, libidl), Cvoid, (IDL_VPTR, IDL_VPTR), src, dst)
end

function IDL_StoreScalar(dest, type, value)
    ccall((:IDL_StoreScalar, libidl), Cvoid, (IDL_VPTR, Cint, Ptr{IDL_ALLTYPES}), dest, type, value)
end

function IDL_StoreScalarZero(dest, type)
    ccall((:IDL_StoreScalarZero, libidl), Cvoid, (IDL_VPTR, Cint), dest, type)
end

function IDL_LongScalar(v)
    ccall((:IDL_LongScalar, libidl), IDL_LONG, (IDL_VPTR,), v)
end

function IDL_ULongScalar(v)
    ccall((:IDL_ULongScalar, libidl), IDL_ULONG, (IDL_VPTR,), v)
end

function IDL_Long64Scalar(v)
    ccall((:IDL_Long64Scalar, libidl), IDL_LONG64, (IDL_VPTR,), v)
end

function IDL_ULong64Scalar(v)
    ccall((:IDL_ULong64Scalar, libidl), IDL_ULONG64, (IDL_VPTR,), v)
end

function IDL_DoubleScalar(v)
    ccall((:IDL_DoubleScalar, libidl), Cdouble, (IDL_VPTR,), v)
end

function IDL_MEMINTScalar(v)
    ccall((:IDL_MEMINTScalar, libidl), IDL_LONG64, (IDL_VPTR,), v)
end

function IDL_FILEINTScalar(v)
    ccall((:IDL_FILEINTScalar, libidl), IDL_LONG64, (IDL_VPTR,), v)
end

function IDL_CastUL64_f(value)
    ccall((:IDL_CastUL64_f, libidl), Cfloat, (IDL_ULONG64,), value)
end

function IDL_CastUL64_d(value)
    ccall((:IDL_CastUL64_d, libidl), Cdouble, (IDL_ULONG64,), value)
end

function IDL_CastFloat_UL(value)
    ccall((:IDL_CastFloat_UL, libidl), IDL_ULONG, (Cfloat,), value)
end

function IDL_CastDouble_UL(value)
    ccall((:IDL_CastDouble_UL, libidl), IDL_ULONG, (Cdouble,), value)
end

function IDL_transpose(argc, argv)
    ccall((:IDL_transpose, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_StrBase_strcasecmp(str1, str2)
    ccall((:IDL_StrBase_strcasecmp, libidl), Cint, (Ptr{Cchar}, Ptr{Cchar}), str1, str2)
end

function IDL_StrBase_strncasecmp(str1, str2, nchars)
    ccall((:IDL_StrBase_strncasecmp, libidl), Cint, (Ptr{Cchar}, Ptr{Cchar}, Csize_t), str1, str2, nchars)
end

function IDL_VarGetData(v, n, pd, ensure_simple)
    ccall((:IDL_VarGetData, libidl), Cvoid, (IDL_VPTR, Ptr{IDL_LONG64}, Ptr{Ptr{Cchar}}, Cint), v, n, pd, ensure_simple)
end

function IDL_VarGet1EltStringDesc(v, tc_v, like_print)
    ccall((:IDL_VarGet1EltStringDesc, libidl), Ptr{IDL_STRING}, (IDL_VPTR, Ptr{IDL_VPTR}, Cint), v, tc_v, like_print)
end

function IDL_VarGetString(v)
    ccall((:IDL_VarGetString, libidl), Ptr{Cchar}, (IDL_VPTR,), v)
end

function IDL_ImportArray(n_dim, dim, type, data, free_cb, s)
    ccall((:IDL_ImportArray, libidl), IDL_VPTR, (Cint, Ptr{IDL_LONG64}, Cint, Ptr{UCHAR}, IDL_ARRAY_FREE_CB, IDL_StructDefPtr), n_dim, dim, type, data, free_cb, s)
end

function IDL_ImportNamedArray(name, n_dim, dim, type, data, free_cb, s)
    ccall((:IDL_ImportNamedArray, libidl), IDL_VPTR, (Ptr{Cchar}, Cint, Ptr{IDL_LONG64}, Cint, Ptr{UCHAR}, IDL_ARRAY_FREE_CB, IDL_StructDefPtr), name, n_dim, dim, type, data, free_cb, s)
end

function IDL_VarTypeConvert(v, type)
    ccall((:IDL_VarTypeConvert, libidl), IDL_VPTR, (IDL_VPTR, Cint), v, type)
end

function IDL_VarMakeTempFromTemplate(template_var, type, sdef, result_addr, zero)
    ccall((:IDL_VarMakeTempFromTemplate, libidl), Ptr{Cchar}, (IDL_VPTR, Cint, IDL_StructDefPtr, Ptr{IDL_VPTR}, Cint), template_var, type, sdef, result_addr, zero)
end

function IDL_StrUpCase(dest, src)
    ccall((:IDL_StrUpCase, libidl), Cvoid, (Ptr{Cchar}, Ptr{Cchar}), dest, src)
end

function IDL_StrDownCase(dest, src)
    ccall((:IDL_StrDownCase, libidl), Cvoid, (Ptr{Cchar}, Ptr{Cchar}), dest, src)
end

function IDL_StrDup(str, n)
    ccall((:IDL_StrDup, libidl), Cvoid, (Ptr{IDL_STRING}, IDL_LONG64), str, n)
end

function IDL_StrDelete(str, n)
    ccall((:IDL_StrDelete, libidl), Cvoid, (Ptr{IDL_STRING}, IDL_LONG64), str, n)
end

function IDL_StrStore(s, fs)
    ccall((:IDL_StrStore, libidl), Cvoid, (Ptr{IDL_STRING}, Ptr{Cchar}), s, fs)
end

function IDL_StrEnsureLength(s, n)
    ccall((:IDL_StrEnsureLength, libidl), Cvoid, (Ptr{IDL_STRING}, Cint), s, n)
end

function IDL_StrToSTRING(s)
    ccall((:IDL_StrToSTRING, libidl), IDL_VPTR, (Ptr{Cchar},), s)
end

function IDL_stregex(argc, argv, argk)
    ccall((:IDL_stregex, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

function IDL_String_Remove(argc, argv, argk)
    ccall((:IDL_String_Remove, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

function IDL_Variable_Diff(argc, argv, argk)
    ccall((:IDL_Variable_Diff, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

function IDL_Variable_toString(argc, argv, argk)
    ccall((:IDL_Variable_toString, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

function IDL_grMesh_Clip(fPlane, clipSide, pfVin, iNVerts, piCin, iNConn, pfVout, iNVout, piCout, iNCout, vpAuxInKW, vpAuxOutKW, vpCut)
    ccall((:IDL_grMesh_Clip, libidl), IDL_LONG, (Ptr{Cfloat}, Cshort, Ptr{Cfloat}, IDL_LONG, Ptr{IDL_LONG}, IDL_LONG, Ptr{Ptr{Cfloat}}, Ptr{IDL_LONG}, Ptr{Ptr{IDL_LONG}}, Ptr{IDL_LONG}, IDL_VPTR, IDL_VPTR, IDL_VPTR), fPlane, clipSide, pfVin, iNVerts, piCin, iNConn, pfVout, iNVout, piCout, iNCout, vpAuxInKW, vpAuxOutKW, vpCut)
end

function IDL_BasicTypeConversion(argc, argv, type)
    ccall((:IDL_BasicTypeConversion, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}, Cint), argc, argv, type)
end

function IDL_CvtByte(argc, argv)
    ccall((:IDL_CvtByte, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_CvtFix(argc, argv)
    ccall((:IDL_CvtFix, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_CvtLng(argc, argv)
    ccall((:IDL_CvtLng, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_CvtFlt(argc, argv)
    ccall((:IDL_CvtFlt, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_CvtDbl(argc, argv)
    ccall((:IDL_CvtDbl, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_CvtUInt(argc, argv)
    ccall((:IDL_CvtUInt, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_CvtULng(argc, argv)
    ccall((:IDL_CvtULng, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_CvtLng64(argc, argv)
    ccall((:IDL_CvtLng64, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_CvtULng64(argc, argv)
    ccall((:IDL_CvtULng64, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_CvtMEMINT(argc, argv)
    ccall((:IDL_CvtMEMINT, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_CvtFILEINT(argc, argv)
    ccall((:IDL_CvtFILEINT, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_CvtComplex(argc, argv, argk)
    ccall((:IDL_CvtComplex, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

function IDL_CvtDComplex(argc, argv)
    ccall((:IDL_CvtDComplex, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}), argc, argv)
end

function IDL_CvtString(argc, argv, argk)
    ccall((:IDL_CvtString, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

function IDL_KWProcessByOffset(argc, argv, argk, kw_list, plain_args, mask, base)
    ccall((:IDL_KWProcessByOffset, libidl), Cint, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}, Ptr{IDL_KW_PAR}, Ptr{IDL_VPTR}, Cint, Ptr{Cvoid}), argc, argv, argk, kw_list, plain_args, mask, base)
end

function IDL_KWProcessByAddr(argc, argv, argk, kw_list, plain_args, mask, free_required)
    ccall((:IDL_KWProcessByAddr, libidl), Cint, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}, Ptr{IDL_KW_PAR}, Ptr{IDL_VPTR}, Cint, Ptr{Cint}), argc, argv, argk, kw_list, plain_args, mask, free_required)
end

function IDL_KWFreeAll()
    ccall((:IDL_KWFreeAll, libidl), Cvoid, ())
end

function IDL_CvtBytscl(argc, argv, argk)
    ccall((:IDL_CvtBytscl, libidl), IDL_VPTR, (Cint, Ptr{IDL_VPTR}, Ptr{Cchar}), argc, argv, argk)
end

function IDL_DitherMethodNamesFunc(method)
    ccall((:IDL_DitherMethodNamesFunc, libidl), Ptr{Cchar}, (Cint,), method)
end

function IDL_RasterDrawThick(p0, p1, a, routine, dot_width)
    ccall((:IDL_RasterDrawThick, libidl), Cvoid, (Ptr{IDL_GR_PT}, Ptr{IDL_GR_PT}, Ptr{IDL_ATTR_STRUCT}, IDL_DEVCORE_FCN_POLYFILL, Cint), p0, p1, a, routine, dot_width)
end

function IDL_RasterPolyfill(x, y, n, p, r)
    ccall((:IDL_RasterPolyfill, libidl), Cvoid, (Ptr{Cint}, Ptr{Cint}, Cint, Ptr{IDL_POLYFILL_ATTR}, Ptr{IDL_RASTER_DEF}), x, y, n, p, r)
end

function IDL_RasterDraw(p0, p1, a, r)
    ccall((:IDL_RasterDraw, libidl), Cvoid, (Ptr{IDL_GR_PT}, Ptr{IDL_GR_PT}, Ptr{IDL_ATTR_STRUCT}, Ptr{IDL_RASTER_DEF}), p0, p1, a, r)
end

function IDL_Raster8Image(data, nx, ny, x0, y0, xsize, ysize, secondary, rs, bReverse)
    ccall((:IDL_Raster8Image, libidl), Cvoid, (Ptr{UCHAR}, IDL_ULONG, IDL_ULONG, IDL_ULONG, IDL_ULONG, IDL_ULONG, IDL_ULONG, Ptr{IDL_TV_STRUCT}, Ptr{IDL_RASTER_DEF}, IDLBool_t), data, nx, ny, x0, y0, xsize, ysize, secondary, rs, bReverse)
end

function IDL_RasterImage(data, nx, ny, x0, y0, xsize, ysize, secondary, rs, bReverse)
    ccall((:IDL_RasterImage, libidl), Cvoid, (Ptr{UCHAR}, IDL_ULONG, IDL_ULONG, IDL_ULONG, IDL_ULONG, IDL_ULONG, IDL_ULONG, Ptr{IDL_TV_STRUCT}, Ptr{IDL_RASTER_DEF}, IDLBool_t), data, nx, ny, x0, y0, xsize, ysize, secondary, rs, bReverse)
end

function IDL_Dither(data, ncols, nrows, r, x0, y0, secondary)
    ccall((:IDL_Dither, libidl), Cvoid, (Ptr{UCHAR}, Cint, Cint, Ptr{IDL_RASTER_DEF}, Cint, Cint, Ptr{IDL_TV_STRUCT}), data, ncols, nrows, r, x0, y0, secondary)
end

function IDL_BitmapLandscape(in, out, y0)
    ccall((:IDL_BitmapLandscape, libidl), Cvoid, (Ptr{IDL_RASTER_DEF}, Ptr{IDL_RASTER_DEF}, Cint), in, out, y0)
end

function IDL_Freetmp(p)
    ccall((:IDL_Freetmp, libidl), Cvoid, (IDL_VPTR,), p)
end

function IDL_Gettmp()
    ccall((:IDL_Gettmp, libidl), IDL_VPTR, ())
end

function IDL_GettmpByte(value)
    ccall((:IDL_GettmpByte, libidl), IDL_VPTR, (UCHAR,), value)
end

function IDL_GettmpInt(value)
    ccall((:IDL_GettmpInt, libidl), IDL_VPTR, (IDL_INT,), value)
end

function IDL_GettmpLong(value)
    ccall((:IDL_GettmpLong, libidl), IDL_VPTR, (IDL_LONG,), value)
end

function IDL_GettmpFloat(value)
    ccall((:IDL_GettmpFloat, libidl), IDL_VPTR, (Cfloat,), value)
end

function IDL_GettmpDouble(value)
    ccall((:IDL_GettmpDouble, libidl), IDL_VPTR, (Cdouble,), value)
end

function IDL_GettmpPtr(value)
    ccall((:IDL_GettmpPtr, libidl), IDL_VPTR, (IDL_HVID,), value)
end

function IDL_GettmpObjRef(value)
    ccall((:IDL_GettmpObjRef, libidl), IDL_VPTR, (IDL_HVID,), value)
end

function IDL_GettmpUInt(value)
    ccall((:IDL_GettmpUInt, libidl), IDL_VPTR, (IDL_UINT,), value)
end

function IDL_GettmpULong(value)
    ccall((:IDL_GettmpULong, libidl), IDL_VPTR, (IDL_ULONG,), value)
end

function IDL_GettmpLong64(value)
    ccall((:IDL_GettmpLong64, libidl), IDL_VPTR, (IDL_LONG64,), value)
end

function IDL_GettmpULong64(value)
    ccall((:IDL_GettmpULong64, libidl), IDL_VPTR, (IDL_ULONG64,), value)
end

function IDL_GettmpFILEINT(value)
    ccall((:IDL_GettmpFILEINT, libidl), IDL_VPTR, (IDL_LONG64,), value)
end

function IDL_GettmpMEMINT(value)
    ccall((:IDL_GettmpMEMINT, libidl), IDL_VPTR, (IDL_LONG64,), value)
end

# no prototype is found for this function at idl_export.h:3193:27, please use with caution
function IDL_GettmpNULL()
    ccall((:IDL_GettmpNULL, libidl), IDL_VPTR, ())
end

function IDL_GetScratch(p, n_elts, elt_size)
    ccall((:IDL_GetScratch, libidl), Ptr{Cchar}, (Ptr{IDL_VPTR}, IDL_LONG64, IDL_LONG64), p, n_elts, elt_size)
end

function IDL_GetScratchOnThreshold(auto_buf, auto_elts, n_elts, elt_size, tempvar)
    ccall((:IDL_GetScratchOnThreshold, libidl), Ptr{Cchar}, (Ptr{Cchar}, IDL_LONG64, IDL_LONG64, IDL_LONG64, Ptr{IDL_VPTR}), auto_buf, auto_elts, n_elts, elt_size, tempvar)
end

function IDL_AddDevice(dev, msg_action)
    ccall((:IDL_AddDevice, libidl), Cint, (Ptr{IDL_DEVICE_DEF}, Cint), dev, msg_action)
end

function IDL_RgbToHsv(r, g, b, h, s, v, n)
    ccall((:IDL_RgbToHsv, libidl), Cvoid, (Ptr{UCHAR}, Ptr{UCHAR}, Ptr{UCHAR}, Ptr{Cfloat}, Ptr{Cfloat}, Ptr{Cfloat}, Cint), r, g, b, h, s, v, n)
end

function IDL_RgbToHls(r, g, b, h, l, s, n)
    ccall((:IDL_RgbToHls, libidl), Cvoid, (Ptr{UCHAR}, Ptr{UCHAR}, Ptr{UCHAR}, Ptr{Cfloat}, Ptr{Cfloat}, Ptr{Cfloat}, Cint), r, g, b, h, l, s, n)
end

function IDL_HsvToRgb(h, s, v, r, g, b, n)
    ccall((:IDL_HsvToRgb, libidl), Cvoid, (Ptr{Cfloat}, Ptr{Cfloat}, Ptr{Cfloat}, Ptr{UCHAR}, Ptr{UCHAR}, Ptr{UCHAR}, Cint), h, s, v, r, g, b, n)
end

function IDL_HlsToRgb(h, l, s, r, g, b, n)
    ccall((:IDL_HlsToRgb, libidl), Cvoid, (Ptr{Cfloat}, Ptr{Cfloat}, Ptr{Cfloat}, Ptr{UCHAR}, Ptr{UCHAR}, Ptr{UCHAR}, Cint), h, l, s, r, g, b, n)
end

struct var"struct (unnamed at include/idl_export.h:1476:5)"
    data::Ptr{UCHAR}
    d1::Cint
    d2::Cint
    im_verts::Ptr{Cfloat}
    im_w::Ptr{Cfloat}
    interp::UCHAR
    transparent::UCHAR
    im_depth::UCHAR
end

struct var"struct (unnamed at include/idl_export.h:1485:5)"
    angle::Cfloat
    spacing::Cint
    ct::Cfloat
    st::Cfloat
end

struct var"struct (unnamed at include/idl_export.h:1354:3)"
    x::Cfloat
    y::Cfloat
    z::Cfloat
    h::Cfloat
end

struct var"struct (unnamed at include/idl_export.h:1360:3)"
    x::Cint
    y::Cint
end

struct var"struct (unnamed at include/idl_export.h:1365:3)"
    x::Cdouble
    y::Cdouble
    z::Cdouble
    h::Cdouble
end

struct var"struct (unnamed at include/idl_export.h:1378:3)"
    x::Cint
    y::Cint
    z::Cfloat
    h::Cfloat
end

const IDL_M_GENERIC = -1

const IDL_M_NAMED_GENERIC = -2

const IDL_M_SYSERR = -4

const IDL_M_BADARRDIM = -158

const IDL_SIZEOF_C_LONG = 4

const IDL_SIZEOF_C_PTR = 8

const IDL_DEBUGGING = 1

const FALSE = 0

const TRUE = 1

# const IDL_STDCALL = __stdcall

# Skipping MacroDefinition: IDL_CDECL __cdecl

const IDL_MAX_ARRAY_DIM = 8

const IDL_MAXPARAMS = 65535

const IDL_TYP_LONG64 = 14

const IDL_TYP_PTRINT = IDL_TYP_LONG64

const IDL_MAXIDLEN = 1000

const IDL_MAXPATH = 1024

const IDL_TYP_UNDEF = 0

const IDL_TYP_BYTE = 1

const IDL_TYP_INT = 2

const IDL_TYP_LONG = 3

const IDL_TYP_FLOAT = 4

const IDL_TYP_DOUBLE = 5

const IDL_TYP_COMPLEX = 6

const IDL_TYP_STRING = 7

const IDL_TYP_STRUCT = 8

const IDL_TYP_DCOMPLEX = 9

const IDL_TYP_PTR = 10

const IDL_TYP_OBJREF = 11

const IDL_TYP_UINT = 12

const IDL_TYP_ULONG = 13

const IDL_TYP_ULONG64 = 15

const IDL_MAX_TYPE = 15

const IDL_NUM_TYPES = 16

const IDL_TYP_MEMINT = IDL_TYP_LONG64

const IDL_TYP_UMEMINT = IDL_TYP_ULONG64

const IDL_MEMINT = IDL_LONG64

const IDL_UMEMINT = IDL_ULONG64

const IDL_TYP_FILEINT = IDL_TYP_LONG64

const IDL_FILEINT = IDL_LONG64

const IDL_TYP_B_SIMPLE = 62207

const IDL_TYP_B_ALL = 65535

const IDL_V_CONST = 1

const IDL_V_TEMP = 2

const IDL_V_ARR = 4

const IDL_V_FILE = 8

const IDL_V_DYNAMIC = 16

const IDL_V_STRUCT = 32

const IDL_V_NULL = 64

const IDL_V_BOOLEAN = 128

const IDL_V_NOT_SCALAR = (IDL_V_ARR | IDL_V_FILE) | IDL_V_STRUCT

const IDL_A_FILE = 1

const IDL_A_NO_GUARD = 2

const IDL_A_FILE_PACKED = 4

const IDL_A_FILE_OFFSET = 8

const IDL_A_SHM = 16

const IDL_A_CALLBACK_OFFSET = 32

const IDL_STRING_MAX_SLEN = 2147483647

const IDL_FUN_RET = IDL_SYSRTN_GENERIC

const IDL_SYSFUN_DEF_F_OBSOLETE = 1

const IDL_SYSFUN_DEF_F_KEYWORDS = 2

const IDL_SYSFUN_DEF_F_METHOD = 32

const IDL_SYSFUN_DEF_F_NOPROFILE = 512

const IDL_SYSFUN_DEF_F_STATIC = 1024

const IDL_MSG_ACTION_CODE = 0x0000ffff

const IDL_MSG_ACTION_ATTR = 0xffff0000

const IDL_MSG_RET = 0

const IDL_MSG_EXIT = 1

const IDL_MSG_LONGJMP = 2

const IDL_MSG_IO_LONGJMP = 3

const IDL_MSG_INFO = 4

const IDL_MSG_SUPPRESS = 7

const IDL_MSG_ATTR_NOPRINT = 0x00010000

const IDL_MSG_ATTR_MORE = 0x00020000

const IDL_MSG_ATTR_NOPREFIX = 0x00040000

const IDL_MSG_ATTR_QUIET = 0x00080000

const IDL_MSG_ATTR_NOTRACE = 0x00100000

const IDL_MSG_ATTR_BELL = 0x00200000

const IDL_MSG_ATTR_SYS = 0x00400000

const IDL_MSG_ERR_BUF_LEN = 2048

const IDL_MSG_SYSERR_BUF_LEN = 512

const IDL_VENDOR_NAME = "L3Harris Geospatial Solutions, Inc."

const IDL_PRODUCT_NAME = "IDL"

const IDL_PRODUCT_NAME_LC = "idl"

const IDL_VERSION_MAJOR = 8

const IDL_VERSION_MINOR = 9

const IDL_VERSION_SUB = 0

const IDL_REVISION = 452795

const IDL_MAJOR_STRING = string(IDL_VERSION_MAJOR)

const IDL_MINOR_STRING = string(IDL_VERSION_MINOR)

const IDL_SUBMINOR_STRING = string(IDL_VERSION_SUB)

const IDL_VERSION_STRING = "$IDL_MAJOR_STRING.$IDL_MINOR_STRING.$IDL_SUBMINOR_STRING"

const IDL_VERSION_STRING_NOSUBMINOR = "$IDL_MAJOR_STRING.$IDL_MINOR_STRING"

const IDL_REVISION_STRING = string(IDL_REVISION)

const IDL_ARR_INI_ZERO = 0

const IDL_ARR_INI_NOP = 1

const IDL_ARR_INI_INDEX = 2

const IDL_ARR_INI_TEST = 3

const IDL_BARR_INI_ZERO = IDL_ARR_INI_ZERO

const IDL_BARR_INI_NOP = IDL_ARR_INI_NOP

const IDL_BARR_INI_INDEX = IDL_ARR_INI_INDEX

const IDL_BARR_INI_TEST = IDL_ARR_INI_TEST

const IDL_EZ_ACCESS_R = 1

const IDL_EZ_ACCESS_W = 2

const IDL_EZ_ACCESS_RW = 3

# manual substitution for the macro
# #define IDL_TYP_MASK(type_code)      (1 << type_code)
const IDL_EZ_TYP_NUMERIC = ((((((((((1 << IDL_TYP_INT) | (1 << IDL_TYP_LONG)) | (1 << IDL_TYP_FLOAT)) | (1 << IDL_TYP_DOUBLE)) | (1 << IDL_TYP_COMPLEX)) | (1 << IDL_TYP_BYTE)) | (1 << IDL_TYP_DCOMPLEX)) | (1 << IDL_TYP_UINT)) | (1 << IDL_TYP_ULONG)) | (1 << IDL_TYP_LONG64)) | (1 << IDL_TYP_ULONG64)

const IDL_EZ_DIM_ARRAY = 510

const IDL_EZ_DIM_ANY = 511

const IDL_EZ_PRE_SQMATRIX = 1

const IDL_EZ_PRE_TRANSPOSE = 2

const IDL_EZ_POST_WRITEBACK = 1

const IDL_EZ_POST_TRANSPOSE = 2

const IDL_MAX_TICKN = 60

const IDL_MAX_TICKUNIT_COUNT = 10

const IDL_COLOR_MAP_SIZE = 256

const IDL_NUM_LINESTYLES = 6

const IDL_X0 = 0

const IDL_Y0 = 1

const IDL_X1 = 2

const IDL_Y1 = 3

const IDL_Z0 = 4

const IDL_Z1 = 5

const IDL_AX_LOG = 1

const IDL_AX_MAP = 2

const IDL_AX_MAP1 = 3

const IDL_AX_EXACT = 1

const IDL_AX_EXTEND = 2

const IDL_AX_NONE = 4

const IDL_AX_NOBOX = 8

const IDL_AX_NOZERO = 16

const IDL_GR_PRECISION_SINGLE = 0

const IDL_GR_PRECISION_DOUBLE = 1

const IDL_TICKLAYOUT_STANDARD = 0

const IDL_TICKLAYOUT_NOAXISLINES = 1

const IDL_TICKLAYOUT_BOXOUTLINE = 2

const IDL_CURS_SET = 1

const IDL_CURS_RD = 2

const IDL_CURS_RD_WAIT = 3

const IDL_CURS_HIDE = 4

const IDL_CURS_SHOW = 5

const IDL_CURS_RD_MOVE = 6

const IDL_CURS_RD_BUTTON_UP = 7

const IDL_CURS_RD_BUTTON_DOWN = 8

const IDL_CURS_HIDE_ORIGINAL = 9

const IDL_COORD_DATA = 0

const IDL_COORD_DEVICE = 1

const IDL_COORD_NORMAL = 2

const IDL_COORD_MARGIN = 3

const IDL_COORD_IDEVICE = 4

const IDL_PX = 0

const IDL_PY = 1

const IDL_PZ = 2

const IDL_PH = 3

const IDL_D_SCALABLE_PIXELS = 1

const IDL_D_ANGLE_TEXT = 1 << 1

const IDL_D_THICK = 1 << 2

const IDL_D_IMAGE = 1 << 3

const IDL_D_COLOR = 1 << 4

const IDL_D_POLYFILL = 1 << 5

const IDL_D_MONOSPACE = 1 << 6

const IDL_D_READ_PIXELS = 1 << 7

const IDL_D_WINDOWS = 1 << 8

const IDL_D_WHITE_BACKGROUND = 1 << 9

const IDL_D_NO_HDW_TEXT = 1 << 10

const IDL_D_POLYFILL_LINE = 1 << 11

const IDL_D_HERSH_CONTROL = 1 << 12

const IDL_D_PLOTTER = 1 << 13

const IDL_D_WORDS = 1 << 14

const IDL_D_KANJI = 1 << 15

const IDL_D_WIDGETS = 1 << 16

const IDL_D_Z = 1 << 17

const IDL_D_TRUETYPE_FONT = 1 << 18

const IDL_KW_ARRAY = 1 << 12

const IDL_KW_OUT = 1 << 13

const IDL_KW_VIN = IDL_KW_OUT | IDL_KW_ARRAY

const IDL_KW_ZERO = 1 << 14

const IDL_KW_VALUE = 1 << 15

const IDL_KW_VALUE_MASK = 1 << 12 - 1

# Skipping MacroDefinition: IDL_KW_FAST_SCAN { ( char * ) "" , 0 , 0 , 0 , 0 , 0 }

# Skipping MacroDefinition: IDL_KW_COMMON_ARR_DESC_TAGS char * data ; /* Address of array to receive data. */ IDL_MEMINT nmin ; /* Minimum # of elements allowed. */ IDL_MEMINT nmax ;

const IDL_KW_MARK = 1

const IDL_KW_CLEAN = 2

# const IDL_KW_RESULT_FIRST_FIELD = Cint(_idl_kw_free)

# Skipping MacroDefinition: IDL_KW_FREE if ( kw . _idl_kw_free ) IDL_KWFree ( )

const IDL_LMGR_CLIENTSERVER = 0x01

const IDL_LMGR_DEMO = 0x02

const IDL_LMGR_EMBEDDED = 0x04

const IDL_LMGR_RUNTIME = 0x08

const IDL_LMGR_STUDENT = 0x10

const IDL_LMGR_TRIAL = 0x20

const IDL_LMGR_CALLAPPNOCHECKOUT = 0x40

const IDL_LMGR_CALLAPPLICINTERNAL = 0x80

const IDL_LMGR_VM = 0x0100

const IDL_LMGR_SET_NOCOMPILE = 0x02

const IDL_LMGR_SET_NORESTORE = 0x04

const IDL_USER_INFO_MAXHOSTLEN = 64

const IDL_POUT_SL = 1

const IDL_POUT_FL = 2

const IDL_POUT_NOSP = 4

const IDL_POUT_NOBREAK = 8

const IDL_POUT_LEADING = 16

const IDL_POUT_FORCE_FL = 32

const IDL_HV_F_STATIC = 1024

const IDL_HEAPNEW_NOCOPY = 1

const IDL_HEAPNEW_GCDISABLE = 2

const IDL_HEAPNEW_ZEROREF = 4

const IDL_DITHER_REVERSE = 0

const IDL_DITHER_THRESHOLD = 1

const IDL_DITHER_FLOYD_STEINBERG = 2

const IDL_DITHER_ORDERED = 3

const IDL_DITHER_F_WHITE = 0x01

const IDL_RASTER_1BYTEPP = 0x02

const IDL_RASTER_MSB_LEFT = [0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01]

const IDL_RASTER_MSB_RIGHT = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80]

const IDL_RLINE_OPT_NOSAVE = 1

const IDL_RLINE_OPT_NOJOURNAL = 2

const IDL_RLINE_OPT_JOURCMT = 4

const IDL_RLINE_OPT_NOEDIT = 8

const IDL_STD_INHERIT = 1

const IDL_SRE_B_DISABLE = 1

const IDL_SRE_B_EXCLUSIVE = 2

const IDL_SRE_ENABLE = 0

const IDL_SRE_ENABLE_EXCLUSIVE = IDL_SRE_B_EXCLUSIVE

const IDL_SRE_DISABLE = IDL_SRE_B_DISABLE

const IDL_SRE_DISABLE_EXCLUSIVE = IDL_SRE_B_DISABLE | IDL_SRE_B_EXCLUSIVE

const IDL_KW_ARGS = 128

# Skipping MacroDefinition: IDL_SysvErrString IDL_SysvErrorState . msg

# Skipping MacroDefinition: IDL_SysvSyserrString IDL_SysvErrorState . sys_msg

# Skipping MacroDefinition: IDL_SysvErrorCode IDL_SysvErrorState . code

# Skipping MacroDefinition: IDL_SysvSyserrorCodes IDL_SysvErrorState . sys_code

const IDL_SYSVVALUES_INF = 0

const IDL_SYSVVALUES_NAN = 1

const IDL_TOUT_F_STDERR = 1

const IDL_TOUT_F_NLPOST = 4

const IDL_TOUT_MORE_RSP_QUIT = 0

const IDL_TOUT_MORE_RSP_PAGE = 1

const IDL_TOUT_MORE_RSP_LINE = 2

const IDL_INIT_GUI = 1

const IDL_INIT_GUI_AUTO = IDL_INIT_GUI | 2

const IDL_INIT_RUNTIME = 4

const IDL_INIT_BACKGROUND = 32

const IDL_INIT_QUIET = 64

const IDL_INIT_NOCMDLINE = 1 << 12

const IDL_INIT_OCX = IDL_INIT_NOCMDLINE

const IDL_INIT_VM = 1 << 13

const IDL_INIT_NOVM = 1 << 14

const IDL_INIT_NOTTYEDIT = 1 << 15

const IDL_INIT_CLARGS = 1 << 17

const IDL_INIT_HWND = 1 << 18

const IDL_INIT_BUFFER_LICENSE = 1 << 31

const IDL_OPEN_R = 1

const IDL_OPEN_W = 2

const IDL_OPEN_NEW = 4

const IDL_OPEN_APND = 8

const IDL_F_ISATTY = IDL_SFILE_FLAGS_T(1)

const IDL_F_ISAGUI = IDL_SFILE_FLAGS_T(2)

const IDL_F_NOCLOSE = IDL_SFILE_FLAGS_T(4)

const IDL_F_MORE = IDL_SFILE_FLAGS_T(8)

const IDL_F_XDR = IDL_SFILE_FLAGS_T(16)

const IDL_F_DEL_ON_CLOSE = IDL_SFILE_FLAGS_T(32)

const IDL_F_SR = IDL_SFILE_FLAGS_T(64)

const IDL_F_SWAP_ENDIAN = IDL_SFILE_FLAGS_T(128)

const IDL_F_VAX_FLOAT = IDL_SFILE_FLAGS_T(1) << 8

const IDL_F_COMPRESS = IDL_SFILE_FLAGS_T(1) << 9

const IDL_F_UNIX_F77 = IDL_SFILE_FLAGS_T(1) << 10

const IDL_F_PIPE = IDL_SFILE_FLAGS_T(1) << 11

const IDL_F_UNIX_PIPE = IDL_F_PIPE

const IDL_F_UNIX_RAWIO = IDL_SFILE_FLAGS_T(1) << 12

const IDL_F_UNIX_NOSTDIO = IDL_F_UNIX_RAWIO

const IDL_F_UNIX_SPECIAL = IDL_SFILE_FLAGS_T(1) << 13

const IDL_F_STDIO = IDL_SFILE_FLAGS_T(1) << 14

const IDL_F_SOCKET = IDL_SFILE_FLAGS_T(1) << 15

const IDL_F_VMS_FIXED = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_VARIABLE = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_SEGMENTED = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_STREAM = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_STREAM_STRICT = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_RMSBLK = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_RMSBLKUDF = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_INDEXED = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_PRINT = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_SUBMIT = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_TRCLOSE = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_CCLIST = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_CCFORTRAN = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_CCNONE = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_SHARED = IDL_SFILE_FLAGS_T(0)

const IDL_F_VMS_SUPERSEDE = IDL_SFILE_FLAGS_T(0)

const IDL_F_DOS_NOAUTOMODE = IDL_SFILE_FLAGS_T(0)

const IDL_F_DOS_BINARY = IDL_SFILE_FLAGS_T(0)

const IDL_F_MAC_BINARY = IDL_SFILE_FLAGS_T(0)

const IDL_STDIN_UNIT = 0

const IDL_STDOUT_UNIT = -1

const IDL_STDERR_UNIT = -2

const IDL_NON_UNIT = -100

const IDL_EFS_USER = 1

const IDL_EFS_OPEN = 2

const IDL_EFS_CLOSED = 4

const IDL_EFS_READ = 8

const IDL_EFS_WRITE = 16

const IDL_EFS_NOTTY = 32

const IDL_EFS_NOGUI = 64

const IDL_EFS_NOPIPE = 128

const IDL_EFS_NOXDR = 1 << 8

const IDL_EFS_ASSOC = 1 << 9

const IDL_EFS_NOT_RAWIO = 1 << 10

const IDL_EFS_NOT_NOSTDIO = IDL_EFS_NOT_RAWIO

const IDL_EFS_NOCOMPRESS = 1 << 11

const IDL_EFS_STDIO = 1 << 12

const IDL_EFS_NOSOCKET = 1 << 13

const IDL_EFS_SOCKET_LISTEN = 1 << 14

const IDL_FCU_FREELUN = 2

# const strcasecmp = _stricmp

# const strncasecmp = _strnicmp

# const wstrcasecmp = _wcsicmp

# const wstrncasecmp = _wcsnicmp

# const snwprintf = _snwprintf

# const vsnprintf = _vsnprintf

# const strlcpy = IDL_StrBase_strlcpy

# const strlcat = IDL_StrBase_strlcat

# const strlcatW = IDL_StrBase_strlcatW

# const strbcopy = IDL_StrBase_strbcopy

# const strbcopyW = IDL_StrBase_strbcopyW

# const strcasestr = IDL_StrBase_strcasestr

# end # module
