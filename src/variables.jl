# When you instantiate a variable s, that variable can hold
# any type! "reassigning" it doesn't change it's memory address!!
# instead it gets rewritten!

# julia> IDL.execute("s = 120")

# julia> _var = IDL.IDL_GetVarAddr("s")
# Ptr{IDL.IDL_VARIABLE} @0x00000238ce6b7c40

# julia> IDL.execute("s = 'hello'")

# julia> _var = IDL.IDL_GetVarAddr("s")
# Ptr{IDL.IDL_VARIABLE} @0x00000238ce6b7c40

# julia> IDL.execute("s = [1,2,3]")

# julia> _var = IDL.IDL_GetVarAddr("s")
# Ptr{IDL.IDL_VARIABLE} @0x00000238ce6b7c40

# julia> IDL.execute("s = !NULL")

# julia> _var = IDL.IDL_GetVarAddr("s")
# Ptr{IDL.IDL_VARIABLE} @0x00000238ce6b7c40

# julia> IDL.IDL_Delvar(_var)

# julia> _var = IDL.IDL_GetVarAddr("s")
# Ptr{IDL.IDL_VARIABLE} @0x00000238ce6b7c40


## Even deleting a variable simply makes it an undef!
## IDL Variables are always valid basically...

# idl doesn't like '#'
idlgensym(tag="jl") = replace(String(gensym(tag)), "#" => "_")

_var_flags(_var::Ptr{IDL_VARIABLE}) = unsafe_load(_var.flags)
_var_type(_var::Ptr{IDL_VARIABLE}) = unsafe_load(_var.type)
_var_info(_var::Ptr{IDL_VARIABLE}) = (_var_flags(_var), _var_type(_var))
_var_array(_var::Ptr{IDL_VARIABLE}) = unsafe_load(_var.value.arr)
_var_sdef(_var::Ptr{IDL_VARIABLE}) = unsafe_load(_var.value.s)
_var_scalar(_var::Ptr{IDL_VARIABLE}) =
	unsafe_load(Base.getproperty(_var.value, _alltypes_sym(_var_type(_var))))


const ALL_T = Ref{IDL_ALLTYPES}()

abstract type AbstractIDLVariable end
function _varptr end

varflags(v::AbstractIDLVariable) = _var_flags(_varptr(v))
vartype(v::AbstractIDLVariable) = IDL_TYP(_var_type(_varptr(v)))
Base.eltype(v::AbstractIDLVariable) = jltype(vartype(v))
name(v::AbstractIDLVariable) = unsafe_string(IDL_VarName(_varptr(v)))

isconst(v::AbstractIDLVariable) = (varflags(v) & IDL_V_CONST) != 0
istemp(v::AbstractIDLVariable) = (varflags(v) & IDL_V_TEMP) != 0
isfile(v::AbstractIDLVariable) = (varflags(v) & IDL_V_FILE) != 0
# dynamic variables are arrays, structures or strings, because the data is behind a pointer.
isdynamic(v::AbstractIDLVariable) = (varflags(v) & IDL_V_DYNAMIC) != 0
isarray(v::AbstractIDLVariable) = (varflags(v) & IDL_V_ARR) != 0
isstruct(v::AbstractIDLVariable) = (varflags(v) & IDL_V_STRUCT) != 0
isscalar(v::AbstractIDLVariable) = !isarray(v) && !IDL.isfile(v)
isboolean(v::AbstractIDLVariable) = ((varflags(v) & IDL_V_BOOLEAN) != 0) && (vartype(v) == T_BYTE)
issimplearray(v::AbstractIDLVariable) = isarray(v) && !isstruct(v)
Base.isnothing(v::AbstractIDLVariable) = (varflags(v) & IDL_V_NULL) != 0


## TODO: maybe use the internal "ENSURE etc etc" functions from idl.
isvalid(v::AbstractIDLVariable) = vartype(v) != T_UNDEF
checkvalid(v::AbstractIDLVariable) = isvalid(v) || throw(UndefVarError(Symbol(name(v)), "IDL"))
checkarray(v::AbstractIDLVariable) = isarray(v) || throw(ErrorException("The variable is not an array."))
checkstruct(v::AbstractIDLVariable) = isstruct(v) || throw(ErrorException("The variable is not a structure."))
checkscalar(v::AbstractIDLVariable) = isscalar(v) || throw(ErrorException("The variable is not a scalar."))

_array(v::AbstractIDLVariable) = (checkarray(v); return _var_array(_varptr(v)))

idlcopyvar!(dst::AbstractIDLVariable, src::AbstractIDLVariable) = IDL_VarCopy(_varptr(src), _varptr(dst))

mutable struct Variable <: AbstractIDLVariable
	_v::Ptr{IDL_VARIABLE}

	function Variable(_v::Ptr{IDL_VARIABLE})
		var_f, var_t = _var_info(_v)

		if (var_f & IDL_V_FILE) != 0
			error("File Variables not yet implemented")
		end

		(var_t == IDL_TYP_PTR || var_t == IDL_TYP_OBJREF) &&
			error("Getting variables of type IDL_TYP_PTR or IDL_TYP_OBJREF is not supported.")

		new(_v)
	end
end

_varptr(v::Variable) = v._v

safeprintln(str::String) = ccall(:jl_safe_printf, Cvoid, (Cstring, ), str * "\n")
mutable struct TemporaryVariable <: AbstractIDLVariable
	_v::Ptr{IDL_VARIABLE}
	safety::Bool

	function TemporaryVariable(_v::Ptr{IDL_VARIABLE})
		var_f, var_t = _var_info(_v)

		var_f & IDL_V_TEMP != 0 || error("The variable pointer needs to be pointing to a temporary variable.")
		this = new(_v, true)

		finalizer(this) do this
			if this.safety
				setfield!(this, :safety, false)
				IDL_Deltmp(this._v)
			end
		end
	end
end

_varptr(v::TemporaryVariable) = begin
	v.safety || throw(ErrorException("The temporary variable has been freed."))
	return v._v
end
deltemp(tv::TemporaryVariable) = finalize(tv)

maketemp() = TemporaryVariable(IDL_Gettmp())
maketemp(x::UCHAR) = TemporaryVariable(IDL_GettmpByte(x))
maketemp(x::IDL_INT) = TemporaryVariable(IDL_GettmpInt(x))
maketemp(x::IDL_UINT) = TemporaryVariable(IDL_GettmpUInt(x))
maketemp(x::IDL_LONG) = TemporaryVariable(IDL_GettmpLong(x))
maketemp(x::IDL_ULONG) = TemporaryVariable(IDL_GettmpULong(x))
maketemp(x::IDL_LONG64) = TemporaryVariable(IDL_GettmpLong64(x))
maketemp(x::IDL_ULONG64) = TemporaryVariable(IDL_GettmpULong64(x))
maketemp(x::Cfloat) = TemporaryVariable(IDL_GettmpFloat(x))
maketemp(x::Cdouble) = TemporaryVariable(IDL_GettmpDouble(x))
# maketemp(x::IDL_HVID) = TemporaryVariable(IDL_GettmpPtr(x))
# maketemp(x::IDL_HVID) = TemporaryVariable(IDL_GettmpObjRef(x)))
# TODO: maketemp for complex variables?

function idlcopyvar!(dst::AbstractIDLVariable, src::TemporaryVariable)
	IDL_VarCopy(_varptr(src), _varptr(dst))
	# VarCopy frees the temporary variable if it's the source.
	setfield!(src, :safety, false)
end

### CONVERSION IDL -> JULIA
# for general purpose conversion, we convert, then copy the tmp var into the old var.
Base.convert(::Type{T}, v::AbstractIDLVariable) where T <: JL_SCALAR = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	_tmpv = IDL_VarTypeConvert(v._v, idltype(T))
	r = unsafe_load(Base.getproperty(_tmpv.value, _alltypes_sym(idltype(T))))

	# If the variable is of the same type, the _tmpvar is not created
	# but the variable itself is returned instead.
	_tmpv != v._v && IDL_Deltmp(_tmpv)

	convert(T, r)
end

# [!WARN]
# Complex numbers get truncated. Only the real part gets translated.
# In line with IDL behaviour
Base.convert(::Type{String}, v::AbstractIDLVariable) = begin
	IDL.eltype(v) == String || throw(ArgumentError("The IDL variable is not a string type"))
	unsafe_string(IDL_VarGetString(v._v))
end

Base.convert(::Type{Bool}, v::AbstractIDLVariable) = begin
	isboolean(v) || throw(ArgumentError("Can't convert a non boolean variable into a Bool value"))
	Bool(unsafe_load(_var_scalar(_varptr(v))))
end

# These attempt automatic transformation which is quicker
Base.convert(::Type{Int32}, v::AbstractIDLVariable) = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_LongScalar(v._v)
end
Base.convert(::Type{UInt32}, v::AbstractIDLVariable) = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_ULongScalar(v._v)
end
Base.convert(::Type{Int64}, v::AbstractIDLVariable) = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_Long64Scalar(v._v)
end
Base.convert(::Type{UInt64}, v::AbstractIDLVariable) = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_ULong64Scalar(v._v)
end
Base.convert(::Type{Float64}, v::AbstractIDLVariable) = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_DoubleScalar(v._v)
end


idlvar(name::Symbol) = begin
	_var = IDL_GetVarAddr(String(name))
	if _var == C_NULL
		throw(UndefVarError(name, "IDL"))
	end

	return Variable(_var)
end

_store_scalar!(_var::Ptr{IDL_VARIABLE}, x::T) where {T<:JL_SCALAR} = begin
	@inline
	_all_t = Base.unsafe_convert(Ptr{IDL_ALLTYPES}, ALL_T)
	setproperty!(_all_t, _alltypes_sym(idltype(T)), x)
	IDL_StoreScalar(_var, idltype(T), _all_t)
end

idlvar(name::Symbol, x::T) where {T <: JL_SCALAR} = begin
	_var = IDL_GetVarAddr(String(name))

	if _var == C_NULL
		var = Variable(IDL_GetVarAddr1(String(name), IDL_TRUE))
		idlcopyvar!(var, maketemp(x))
		return var
	end

	_store_scalar!(_var, x)
	return Variable(_var)
end

idlvar(name::Symbol, x::String) = begin
	var = Variable(IDL_GetVarAddr1(String(name), IDL_TRUE))
	tmpvar = TemporaryVariable(IDL_StrToSTRING(x))
	idlcopyvar!(var, tmpvar)

	var
end

set!(v::AbstractIDLVariable, x::T) where {T <: JL_SCALAR} = (@inline _store_scalar!(v._v, x); return v)

set!(v::AbstractIDLVariable, x::AbstractString) = begin
	@inline
	tmpvar = TemporaryVariable(IDL_StrToSTRING(x))
	# This is efficient, the string data is moved
	idlcopyvar!(v, tmpvar)
	return v
end


jlscalar(v::AbstractIDLVariable) = convert(eltype(v), v)
jlscalar(::Type{T}, v::AbstractIDLVariable) where {T<:JL_SCALAR} = convert(T, v)

jlscalar(name::Symbol) = jlscalar(idlvar(name))
jlscalar(::Type{T}, name::Symbol) where {T<:JL_SCALAR} = jlscalar(T, idlvar(name))


function Base.show(io::IO, s::AbstractIDLVariable)
	conststr = isconst(s) ? "CONST " : ""
	tempstr = istemp(s) ? "TEMP " : ""
	validstr = isvalid(s) ? "" : "UNDEF"

	variablename = unsafe_string(IDL.IDL_VarName(s._v))

	print(io, "IDL.Variable: $conststr$tempstr'$variablename' - $validstr")
	isvalid(s) || return

	typestr = isstruct(s) ? "STRUCT" :
		isfile(s) ? "FILE" :
		isboolean(s) ? "BOOL" :
		eltype(s)

	print(io, typestr)
	if issimplearray(s)
		print(io, " (ARRAY)")
	end

end