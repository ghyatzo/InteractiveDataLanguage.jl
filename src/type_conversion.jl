const JL_SCALAR = Union{
	# Nothing,
	UInt8,
	Int16,
	Int32,
	Float32,
	Float64,
	ComplexF32,
	# String
	# Struct
	ComplexF64,
	# Ptr
	# Objref
	UInt16,
	UInt32,
	Int64,
	UInt64,
}

@enum IDL_TYP begin
	T_UNDEF
	T_BYTE
	T_INT
	T_LONG
	T_FLOAT
	T_DOUBLE
	T_COMPLEX
	T_STRING
	T_STRUCT
	T_DCOMPLEX
	T_PTR
	T_OBJREF
	T_UINT
	T_ULONG
	T_LONG64
	T_ULONG64
end

jltype(t::IDL_TYP) = begin
	t == T_UNDEF 	? Nothing 		:
	t == T_BYTE 	? UInt8 		:
	t == T_INT 		? Int16 		:
	t == T_LONG 	? Int32 		:
	t == T_FLOAT 	? Float32 		:
	t == T_DOUBLE 	? Float64 		:
	t == T_COMPLEX 	? ComplexF32 	:
	t == T_STRING 	? String 		:
	t == T_STRUCT 	? DataType 		: # TODO
	t == T_DCOMPLEX ? ComplexF64 	:
	t == T_PTR 		? Ptr 			: # TODO
	t == T_OBJREF 	? IDLObject 	:
	t == T_UINT 	? UInt16 		:
	t == T_ULONG 	? UInt32 		:
	t == T_LONG64 	? Int64 		:
	t == T_ULONG64 	? UInt64 		:
	Nothing
end

idltype(::Type{Nothing}) 	= T_UNDEF
idltype(::Type{UInt8}) 		= T_BYTE
idltype(::Type{Int16}) 		= T_INT
idltype(::Type{Int32}) 		= T_LONG
idltype(::Type{Float32}) 	= T_FLOAT
idltype(::Type{Float64}) 	= T_DOUBLE
idltype(::Type{ComplexF32}) = T_COMPLEX
idltype(::Type{String}) 	= T_STRING
# TODO: STRUCT
idltype(::Type{ComplexF64}) = T_DCOMPLEX
# TODO: PTR
# TODO: OBJREF
idltype(::Type{UInt16}) 	= T_UINT
idltype(::Type{UInt32}) 	= T_ULONG
idltype(::Type{Int64}) 		= T_LONG64
idltype(::Type{UInt64}) 	= T_ULONG64

_alltypes_sym(t::UInt8)   = _alltypes_sym(IDL_TYP(t))
_alltypes_sym(t::IDL_TYP) = begin
	t == T_UNDEF 	? :NULL :
	t == T_BYTE 	? :c 	:
	t == T_INT 		? :i 	:
	t == T_LONG 	? :l 	:
	t == T_FLOAT 	? :f 	:
	t == T_DOUBLE 	? :d 	:
	t == T_COMPLEX 	? :cmp 	:
	t == T_STRING 	? :str 	:
	t == T_STRUCT 	? :s 	:
	t == T_DCOMPLEX ? :dcmp :
	t == T_PTR 		? :hvid :
	t == T_OBJREF 	? :hvid :
	t == T_UINT 	? :ui 	:
	t == T_ULONG 	? :ul 	:
	t == T_LONG64 	? :l64 	:
	t == T_ULONG64 	? :ul64 :
	:NULL
end

IDL_STRING_STR(str::IDL_STRING) = str.slen > 0 ? unsafe_string(str.s) : ""
IDL_STRING_STR(str_::Ptr{IDL_STRING}) = IDL_STRING_STR(unsafe_load(str_))

Base.convert(::Type{String}, x::IDL_STRING) = IDL_STRING_STR(x)
Base.convert(::Type{IDL_STRING}, s::String) = begin
	strref = Ref{IDL_STRING}()
	IDL_StrStore(strref, s)
	strref[]
end

Base.convert(::Type{IDL_COMPLEX}, c::ComplexF32) = IDL_COMPLEX(c.re, c.im)
Base.convert(::Type{IDL_DCOMPLEX}, c::ComplexF64) = IDL_DCOMPLEX(c.re, c.im)
Base.convert(::Type{ComplexF32}, idlc::IDL_COMPLEX) = ComplexF32(idlc.r, idlc.i)
Base.convert(::Type{ComplexF64}, idlc::IDL_DCOMPLEX) = ComplexF64(idlc.r, idlc.i)


_idl2jl(t::T) where T <: JL_SCALAR = t
_idl2jl(t::IDL_STRING) = convert(String, t)


#------------------------------------------------------------
#
#	Julia values as IDL source text
#
#------------------------------------------------------------

# IDL literals carry their type in a suffix: B/S/US/L/UL/LL/ULL for the
# integer widths (the same table the tests use), `d` for double. IDL reads
# an exponent-less `d` as double, so `1.0e-320` is written `1.0d-320`.
_idl_int_suffix(::Type{UInt8})  = "B"
_idl_int_suffix(::Type{Int16})  = "S"
_idl_int_suffix(::Type{UInt16}) = "US"
_idl_int_suffix(::Type{Int32})  = "L"
_idl_int_suffix(::Type{UInt32}) = "UL"
_idl_int_suffix(::Type{Int64})  = "LL"
_idl_int_suffix(::Type{UInt64}) = "ULL"
_idl_int_suffix(::Type{T}) where T = throw(ArgumentError("IDL has no integer type for $(T)."))

idl_literal(x::Integer) = string(x) * _idl_int_suffix(typeof(x))
idl_literal(x::Bool) = x ? "1B" : "0B"

function idl_literal(x::Float32)
	isnan(x) && return "!VALUES.F_NAN"
	isinf(x) && return x > 0 ? "!VALUES.F_INFINITY" : "-!VALUES.F_INFINITY"
	# Julia writes the exponent of a Float32 with an `f`
	return replace(string(x), 'f' => 'e')
end

function idl_literal(x::Float64)
	isnan(x) && return "!VALUES.D_NAN"
	isinf(x) && return x > 0 ? "!VALUES.D_INFINITY" : "-!VALUES.D_INFINITY"
	i = findfirst(c -> c == 'e', string(x))
	i === nothing && return string(x) * "d"
	return string(x)[1:(i - 1)] * "d" * string(x)[(i + 1):end]
end

idl_literal(z::ComplexF32) = "complex($(idl_literal(real(z))), $(idl_literal(imag(z))))"
idl_literal(z::ComplexF64) = "dcomplex($(idl_literal(real(z))), $(idl_literal(imag(z))))"

idl_literal(::Nothing) = "!NULL"

function idl_literal(s::AbstractString)
	occursin('\n', s) && throw(ArgumentError("IDL strings cannot contain newlines."))
	return "'" * replace(s, "'" => "''") * "'"
end

function idl_literal(a::AbstractArray)
	eltype(a) <: Union{JL_SCALAR, Bool, AbstractString} ||
		throw(ArgumentError("IDL cannot take an array of $(eltype(a))."))
	isempty(a) && throw(ArgumentError("IDL cannot express an empty array."))

	values = join(map(idl_literal, vec(a)), ", ")
	return ndims(a) <= 1 ? "[$values]" : "reform([$values], $(join(size(a), ", ")))"
end

function idl_literal(nt::NamedTuple)
	isempty(nt) && throw(ArgumentError("IDL cannot express an empty structure."))

	# IDL tag names are always uppercase
	tags = join(("$(uppercase(string(k))): $(idl_literal(v))" for (k, v) in pairs(nt)), ", ")
	return "{$tags}"
end

idl_literal(x) = throw(ArgumentError("IDL cannot take a $(typeof(x))."))

_idl_args(args...) = join(map(idl_literal, args), ", ")
