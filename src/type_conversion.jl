const JL_SCALAR = Union{
	# Nothing,
	UInt8,
	Int16,
	UInt16,
	Int32,
	UInt32,
	Int64,
	UInt64,
	Float32,
	Float64,
	ComplexF32,
	ComplexF64,
	# String
}

jltype(t::UInt8) = jltype(Val(Int(t)))
jltype(::Val{IDL_TYP_UNDEF}) = undef
jltype(::Val{IDL_TYP_BYTE}) = Cuchar
jltype(::Val{IDL_TYP_INT}) = Cshort
jltype(::Val{IDL_TYP_UINT}) = Cushort
jltype(::Val{IDL_TYP_LONG}) = Cint
jltype(::Val{IDL_TYP_ULONG}) = Cuint
jltype(::Val{IDL_TYP_LONG64}) = Clonglong
jltype(::Val{IDL_TYP_ULONG64}) = Culonglong
jltype(::Val{IDL_TYP_FLOAT}) = Cfloat
jltype(::Val{IDL_TYP_DOUBLE}) = Cdouble
jltype(::Val{IDL_TYP_COMPLEX}) = ComplexF32
jltype(::Val{IDL_TYP_DCOMPLEX}) = ComplexF64
jltype(::Val{IDL_TYP_STRING}) = String
jltype(::Val{IDL_TYP_STRUCT}) = DataType # TODO...
jltype(::Val{IDL_TYP_PTR}) = error("IDL pointers are not supported")
jltype(::Val{IDL_TYP_OBJREF}) = error("IDL Objects are not supported")


idltype(::Type{Nothing}) = IDL_TYP_UNDEF
idltype(::Type{UInt8}) = IDL_TYP_BYTE
idltype(::Type{Int16}) = IDL_TYP_INT
idltype(::Type{UInt16}) = IDL_TYP_UINT
idltype(::Type{Int32}) = IDL_TYP_LONG
idltype(::Type{UInt32}) = IDL_TYP_ULONG
idltype(::Type{Int64}) = IDL_TYP_LONG64
idltype(::Type{UInt64}) = IDL_TYP_ULONG64
idltype(::Type{Float32}) = IDL_TYP_FLOAT
idltype(::Type{Float64}) = IDL_TYP_DOUBLE
idltype(::Type{ComplexF32}) = IDL_TYP_COMPLEX
idltype(::Type{ComplexF64}) = IDL_TYP_DCOMPLEX
idltype(::Type{String}) = IDL_TYP_STRING


_alltypes_sym(t) = _alltypes_sym(Val(t))
_alltypes_sym(::Val{IDL_TYP_BYTE}) = :c
_alltypes_sym(::Val{IDL_TYP_INT}) = :i
_alltypes_sym(::Val{IDL_TYP_UINT}) = :ui
_alltypes_sym(::Val{IDL_TYP_LONG}) = :l
_alltypes_sym(::Val{IDL_TYP_ULONG}) = :ul
_alltypes_sym(::Val{IDL_TYP_LONG64}) = :l64
_alltypes_sym(::Val{IDL_TYP_ULONG64}) = :ul64
_alltypes_sym(::Val{IDL_TYP_FLOAT}) = :f
_alltypes_sym(::Val{IDL_TYP_DOUBLE}) = :d
_alltypes_sym(::Val{IDL_TYP_COMPLEX}) = :cmp
_alltypes_sym(::Val{IDL_TYP_DCOMPLEX}) = :dcmp
_alltypes_sym(::Val{IDL_TYP_STRING}) = :str
_alltypes_sym(::Val{IDL_TYP_STRUCT}) = :s
_alltypes_sym(::Val{IDL_TYP_PTR}) = :hvid
_alltypes_sym(::Val{IDL_TYP_OBJREF}) = :hvid



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


idlconvert(t::T) where T <: JL_SCALAR = t
idlconvert(t::IDL_STRING) = convert(String, t)
