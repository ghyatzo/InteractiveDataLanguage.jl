const JL_SCALAR = Union{
	Nothing,
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
	String
}
const JL_ALLTYPES = Union{<:JL_SCALAR, IDL_SREF, IDL_ARRAY}

function idl_type(jl_t::Type{T}) where T <: JL_SCALAR
	idl_t = begin
		jl_t == Nothing 	? IDL_TYP_UNDEF 	:
		jl_t == UInt8 		? IDL_TYP_BYTE 		:
		jl_t == Int16 		? IDL_TYP_INT 		:
		jl_t == UInt16 		? IDL_TYP_UINT 		:
		jl_t == Int32 		? IDL_TYP_LONG 		:
		jl_t == UInt32 		? IDL_TYP_ULONG 	:
		jl_t == Int64 		? IDL_TYP_LONG64 	:
		jl_t == UInt64 		? IDL_TYP_ULONG64 	:
		jl_t == Float32 	? IDL_TYP_FLOAT 	:
		jl_t == Float64 	? IDL_TYP_DOUBLE 	:
		jl_t == ComplexF32  ? IDL_TYP_COMPLEX 	:
		jl_t == ComplexF64  ? IDL_TYP_DCOMPLEX 	:
		jl_t == String 		? IDL_TYP_STRING 	:
		throw(ArgumentError("type $jl_t is not supported as scalar idl type."))
	end
end

function idl_alltypes_symbol(idl_t)
	v_symbol = begin
		idl_t == IDL_TYP_BYTE 	  ? :c 	  :
		idl_t == IDL_TYP_INT 	  ? :i 	  :
		idl_t == IDL_TYP_UINT 	  ? :ui   :
		idl_t == IDL_TYP_LONG 	  ? :l 	  :
		idl_t == IDL_TYP_ULONG 	  ? :ul   :
		idl_t == IDL_TYP_LONG64   ? :l64  :
		idl_t == IDL_TYP_ULONG64  ? :ul64 :
		idl_t == IDL_TYP_FLOAT 	  ? :f 	  :
		idl_t == IDL_TYP_DOUBLE   ? :d 	  :
		idl_t == IDL_TYP_COMPLEX  ? :cmp  :
		idl_t == IDL_TYP_DCOMPLEX ? :dcmp :
		idl_t == IDL_TYP_STRING   ? :str  :
		idl_t == IDL_TYP_OBJREF   ? :hvid :
		idl_t == IDL_TYP_PTR      ? :hvid :
		throw(ArgumentError("type $idl_t is not scalar valued"))
	end
end

function jl_type(idl_t)
	jl_t = begin
		idl_t == IDL_TYP_UNDEF 	  ? nothing 	:
		idl_t == IDL_TYP_BYTE 	  ? Cuchar 		:
		idl_t == IDL_TYP_INT 	  ? Cshort 		:
		idl_t == IDL_TYP_UINT 	  ? Cushort 	:
		idl_t == IDL_TYP_LONG	  ? Cint		:
		idl_t == IDL_TYP_ULONG	  ? Cuint		:
		idl_t == IDL_TYP_LONG64	  ? Clonglong	:
		idl_t == IDL_TYP_ULONG64  ? Culonglong	:
		idl_t == IDL_TYP_FLOAT	  ? Cfloat		:
		idl_t == IDL_TYP_DOUBLE	  ? Cdouble		:
		idl_t == IDL_TYP_COMPLEX  ? ComplexF32 	:
		idl_t == IDL_TYP_DCOMPLEX ? ComplexF64 	:
		idl_t == IDL_TYP_STRING	  ? IDL_STRING  : # this structure is defined in the clang wrapper and is a valid julia type
		throw(ArgumentError("type $idl_t is not scalar valued or not supported."))
	end
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
