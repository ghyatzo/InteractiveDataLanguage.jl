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

_varflags(_var::Ptr{IDL_VARIABLE}) = unsafe_load(_var.flags)
_vartype(_var::Ptr{IDL_VARIABLE}) = unsafe_load(_var.type)
_varinfo(_var::Ptr{IDL_VARIABLE}) = (_varflags(_var), _vartype(_var))

const ALL_T = Ref{IDL_ALLTYPES}()

mutable struct Variable
	_v::Ptr{IDL_VARIABLE}

	function Variable(_v::Ptr{IDL_VARIABLE})
		var_f, var_t = _varinfo(_v)

		if (var_f & IDL_V_FILE) != 0
			error("File Variables not yet implemented")
		end

		(var_t == IDL_TYP_PTR || var_t == IDL_TYP_OBJREF) &&
			error("Getting variables of type IDL_TYP_PTR or IDL_TYP_OBJREF is not supported.")

		new(_v)
	end
end

varflags(v::Variable) = _varflags(v._v)
vartype(v::Variable) = IDL_TYP(_vartype(v._v))
Base.eltype(v::Variable) = jltype(vartype(v))
name(v::Variable) = unsafe_string(IDL_VarName(v._v))

isconst(v::Variable) = (varflags(v) & IDL_V_CONST) != 0
istemp(v::Variable) = (varflags(v) & IDL_V_TEMP) != 0
isfile(v::Variable) = (varflags(v) & IDL_V_FILE) != 0
# dynamic variables are arrays, structures or strings, because the data is behind a pointer.
isdynamic(v::Variable) = (varflags(v) & IDL_V_DYNAMIC) != 0
isarray(v::Variable) = (varflags(v) & IDL_V_ARR) != 0
isstruct(v::Variable) = (varflags(v) & IDL_V_STRUCT) != 0
isscalar(v::Variable) = !isarray(v) && !IDL.isfile(v)
isboolean(v::Variable) = ((varflags(v) & IDL_V_BOOLEAN) != 0) && (vartype(v) == T_BYTE)
issimplearray(v::Variable) = isarray(v) && !isstruct(v)
Base.isnothing(v::Variable) = (varflags(v) & IDL_V_NULL) != 0


## TODO: maybe use the internal "ENSURE etc etc" functions from idl.
isvalid(v::Variable) = vartype(v) != T_UNDEF
checkvalid(v::Variable) = isvalid(v) || throw(UndefVarError(:v, "IDL"))
checkarray(v::Variable) = isarray(v) || throw(ErrorException("The variable is not an array."))
checkstruct(v::Variable) = isstruct(v) || throw(ErrorException("The variable is not a structure."))
checkscalar(v::Variable) = isscalar(v) || throw(ErrorException("The variable is not a scalar."))

_array(v::Variable) = checkvalid(v) && checkarray(v) && unsafe_load(v._v.value.arr)
_sdef(v::Variable) = checkvalid(v) && checkstruct(v) && v._v.value.s
_scalar(v::Variable) = begin
	checkvalid(v) && checkscalar(v)
	Base.getproperty(v._v.value, _alltypes_sym(vartype(v)))
end

# idl doesn't like '#'
idlgensym(tag="jl") = replace(String(gensym(tag)), "#" => "_")

# make temporary variables
_deltemp(v::Variable) = isvalid(v) && istemp(v) && IDL_Deltmp(v._v)
maketemp() = finalizer(_deltemp, Variable(IDL_Gettmp()))
maketemp(x::UCHAR) = finalizer(_deltemp, Variable(IDL_GettmpByte(x)))
maketemp(x::IDL_INT) = finalizer(_deltemp, Variable(IDL_GettmpInt(x)))
maketemp(x::IDL_UINT) = finalizer(_deltemp, Variable(IDL_GettmpUInt(x)))
maketemp(x::IDL_LONG) = finalizer(_deltemp, Variable(IDL_GettmpLong(x)))
maketemp(x::IDL_ULONG) = finalizer(_deltemp, Variable(IDL_GettmpULong(x)))
maketemp(x::IDL_LONG64) = finalizer(_deltemp, Variable(IDL_GettmpLong64(x)))
maketemp(x::IDL_ULONG64) = finalizer(_deltemp, Variable(IDL_GettmpULong64(x)))
maketemp(x::Cfloat) = finalizer(_deltemp, Variable(IDL_GettmpFloat(x)))
maketemp(x::Cdouble) = finalizer(_deltemp, Variable(IDL_GettmpDouble(x)))
# maketemp(x::IDL_HVID) = finalizer(Variable(IDL_GettmpPtr(x)))
# maketemp(x::IDL_HVID) = finalizer(Variable(IDL_GettmpObjRef(x)))
deltemp(v::Variable) = finalize(v)



### CONVERSION IDL -> JULIA

# for general purpose conversion, we convert, then copy the tmp var into the old var.
Base.convert(::Type{T}, v::Variable) where T <: JL_SCALAR = begin
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
Base.convert(::Type{String}, v::Variable) = begin
	IDL.eltype(v) == String || throw(ArgumentError("The IDL variable is not a string type"))
	unsafe_string(IDL_VarGetString(v._v))
end

Base.convert(::Type{Bool}, v::Variable) = begin
	isboolean(v) || throw(ArgumentError("Can't convert a non boolean variable into a Bool value"))
	Bool(unsafe_load(_scalar(v)))
end

# These attempt automatic transformation which is quicker
Base.convert(::Type{Int32}, v::Variable) = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_LongScalar(v._v)
end
Base.convert(::Type{UInt32}, v::Variable) = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_ULongScalar(v._v)
end
Base.convert(::Type{Int64}, v::Variable) = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_Long64Scalar(v._v)
end
Base.convert(::Type{UInt64}, v::Variable) = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_ULong64Scalar(v._v)
end
Base.convert(::Type{Float64}, v::Variable) = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_DoubleScalar(v._v)
end


var(name::Symbol) = begin
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

var(name::Symbol, x::T) where {T <: JL_SCALAR} = begin
	_var = IDL_GetVarAddr(String(name))

	if _var == C_NULL
		_var = IDL_GetVarAddr1(String(name), IDL_TRUE)
		tmp = maketemp(x)
		IDL_VarCopy(tmp._v, _var)
		return Variable(_var)
	end

	_store_scalar!(_var, x)
	return Variable(_var)
end

var(name::Symbol, x::String) = begin
	_var = IDL_GetVarAddr1(String(name), IDL_TRUE)
	_tmpvar = IDL_StrToSTRING(x)
	IDL_VarCopy(_tmpvar, _var)
	IDL_Deltmp(_tmpvar)

	Variable(_var)
end

set!(v::Variable, x::T) where {T <: JL_SCALAR} = (@inline _store_scalar!(v._v, x); return v)

set!(v::Variable, x::AbstractString) = begin
	@inline
	_tmpvar = IDL_StrToSTRING(x)
	# This is efficient, the string data is moved
	IDL_VarCopy(_tmpvar, v._v)
	IDL_Deltmp(_tmpvar)
	v
end


jlscalar(v::Variable) = convert(eltype(v), v)
jlscalar(::Type{T}, v::Variable) where {T<:JL_SCALAR} = convert(T, v)

jlscalar(name::Symbol) = jlscalar(var(name))
jlscalar(::Type{T}, name::Symbol) where {T<:JL_SCALAR} = jlscalar(T, var(name))


Base.getindex(v::Variable) = jlscalar(v)
Base.setindex!(v::Variable, x::T) where {T<:JL_SCALAR} = set!(v, x)
Base.setindex!(v::Variable, x::AbstractString) = set!(v, x)


function Base.show(io::IO, s::Variable)
	conststr = isconst(s) ? "CONST " : ""
	tempstr = istemp(s) ? "TEMP " : ""
	validstr = isvalid(s) ? "" : "INVALID"

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