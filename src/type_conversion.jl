const JL_SCALAR = Union{
	# Nothing,
	UInt8,
	Int16,
	Int32,
	Float32,
	Float64,
	ComplexF32,
	# String
	# struct
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
	t == T_UNDEF ? Nothing :
	t == T_BYTE ? UInt8 :
	t == T_INT ? Int16 :
	t == T_LONG ? Int32 :
	t == T_FLOAT ? Float32 :
	t == T_DOUBLE ? Float64 :
	t == T_COMPLEX ? ComplexF32 :
	t == T_STRING ? String :
	t == T_STRUCT ? DataType :
	t == T_DCOMPLEX ? ComplexF64 :
	t == T_PTR ? Ptr :
	t == T_OBJREF ? Ptr :
	t == T_UINT ? UInt16 :
	t == T_ULONG ? UInt32 :
	t == T_LONG64 ? Int64 :
	t == T_ULONG64 ? UInt64 :
	Nothing
end

idltype(::Type{Nothing}) = T_UNDEF
idltype(::Type{UInt8}) = T_BYTE
idltype(::Type{Int16}) = T_INT
idltype(::Type{Int32}) = T_LONG
idltype(::Type{Float32}) = T_FLOAT
idltype(::Type{Float64}) = T_DOUBLE
idltype(::Type{ComplexF32}) = T_COMPLEX
idltype(::Type{String}) = T_STRING
# TODO: STRUCT
idltype(::Type{ComplexF64}) = T_DCOMPLEX
# TODO: PTR
# TODO: OBJREF
idltype(::Type{UInt16}) = T_UINT
idltype(::Type{UInt32}) = T_ULONG
idltype(::Type{Int64}) = T_LONG64
idltype(::Type{UInt64}) = T_ULONG64

_alltypes_sym(t::IDL_TYP) = begin
	t == T_UNDEF ? :NULL :
	t == T_BYTE ? :c :
	t == T_INT ? :i :
	t == T_LONG ? :l :
	t == T_FLOAT ? :f :
	t == T_DOUBLE ? :d :
	t == T_COMPLEX ? :cmp :
	t == T_STRING ? :str :
	t == T_STRUCT ? :s :
	t == T_DCOMPLEX ? :dcmp :
	t == T_PTR ? :hvid :
	t == T_OBJREF ? :hvid :
	t == T_UINT ? :ui :
	t == T_ULONG ? :ul :
	t == T_LONG64 ? :l64 :
	t == T_ULONG64 ? :ul64 :
	:NULL
end


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
