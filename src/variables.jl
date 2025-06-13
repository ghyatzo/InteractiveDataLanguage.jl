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

#========================================#
#
#	Accessors to C struct fields
#
#========================================#

# idl doesn't like '#'
idlgensym(tag="jl") 					= replace(String(gensym(tag)), "#" => "_")

varflags(var__::Ptr{IDL_VARIABLE}) 		= unsafe_load(var__.flags)
vartype(var__::Ptr{IDL_VARIABLE}) 		= unsafe_load(var__.type)
varinfo(var__::Ptr{IDL_VARIABLE}) 		= (varflags(var__), vartype(var__))
vararray__(var__::Ptr{IDL_VARIABLE}) 	= unsafe_load(var__.value.arr)
varsdef(var__::Ptr{IDL_VARIABLE}) 		= unsafe_load(var__.value.s)
varscalar(var__::Ptr{IDL_VARIABLE}) 	=
	unsafe_load(Base.getproperty(var__.value, _alltypes_sym(vartype(var__))))

const ALL_T = Ref{IDL_ALLTYPES}()

#========================================#
#
#	Generic IDL Variable Interface
#
#========================================#


abstract type AbstractIDLVariable end
function varptr__ end

varflags(v::AbstractIDLVariable) 		= varflags(varptr__(v))
vartype(v::AbstractIDLVariable) 		= IDL_TYP(vartype(varptr__(v)))
Base.eltype(v::AbstractIDLVariable) 	= jltype(vartype(v))
name(v::AbstractIDLVariable) 			= unsafe_string(IDL_VarName(varptr__(v)))

isconst(v::AbstractIDLVariable) 		= (varflags(v) & IDL_V_CONST) != 0
istemp(v::AbstractIDLVariable) 			= (varflags(v) & IDL_V_TEMP) != 0
isfile(v::AbstractIDLVariable) 			= (varflags(v) & IDL_V_FILE) != 0
isdynamic(v::AbstractIDLVariable) 		= (varflags(v) & IDL_V_DYNAMIC) != 0
isarray(v::AbstractIDLVariable) 		= (varflags(v) & IDL_V_ARR) != 0
isstruct(v::AbstractIDLVariable) 		= (varflags(v) & IDL_V_STRUCT) != 0
isscalar(v::AbstractIDLVariable) 		= !isarray(v) && !isfile(v)
isboolean(v::AbstractIDLVariable) 		= ((varflags(v) & IDL_V_BOOLEAN) != 0) && (vartype(v) == T_BYTE)
issimplearray(v::AbstractIDLVariable) 	= isarray(v) && !isstruct(v)
Base.isnothing(v::AbstractIDLVariable) 	= (varflags(v) & IDL_V_NULL) != 0


## TODO: maybe use the internal "ENSURE etc etc" functions from idl.
isvalid(v::AbstractIDLVariable) 	= vartype(v)  != T_UNDEF
checkvalid(v::AbstractIDLVariable) 	= isvalid(v)  || throw(UndefVarError(Symbol(name(v)), "IDL"))
checkarray(v::AbstractIDLVariable) 	= isarray(v)  || throw(ErrorException("The variable is not an array."))
checkstruct(v::AbstractIDLVariable) = isstruct(v) || throw(ErrorException("The variable is not a structure."))
checkscalar(v::AbstractIDLVariable) = isscalar(v) || throw(ErrorException("The variable is not a scalar."))

array__(v::AbstractIDLVariable) = (checkarray(v); return vararray__(varptr__(v)))

idlcopyvar!(dst::AbstractIDLVariable, src::AbstractIDLVariable) = IDL_VarCopy(varptr__(src), varptr__(dst))

#========================================#
#
#	Normal Variable Implementation
#
#========================================#

mutable struct Variable <: AbstractIDLVariable
	const ptr::Ptr{IDL_VARIABLE}

	function Variable(v__::Ptr{IDL_VARIABLE})
		var_f, var_t = varinfo(v__)

		if (var_f & IDL_V_FILE) != 0
			error("File Variables not yet implemented")
		end

		(var_t == IDL_TYP_PTR || var_t == IDL_TYP_OBJREF) &&
			error("Getting variables of type IDL_TYP_PTR or IDL_TYP_OBJREF is not supported.")

		new(v__)
	end
end

varptr__(v::Variable) = getfield(v, :ptr)

#========================================#
#
#	Temporary Variable Implementation
#
#========================================#

safeprintln(str::String) = ccall(:jl_safe_printf, Cvoid, (Cstring, ), str * "\n")
mutable struct TemporaryVariable <: AbstractIDLVariable
	ptr::Ptr{IDL_VARIABLE}
	safety::Bool

	function TemporaryVariable(v__::Ptr{IDL_VARIABLE})
		var_f, var_t = varinfo(v__)

		var_f & IDL_V_TEMP != 0 || error("The variable pointer needs to be pointing to a temporary variable.")
		this = new(v__, true)

		finalizer(this) do this
			if this.safety
				setfield!(this, :safety, false)
				IDL_Deltmp(getfield(this, :ptr))
			end
		end
	end
end

varptr__(v::TemporaryVariable) = begin
	getfield(v, :safety) || throw(ErrorException("The temporary variable has been freed."))
	return getfield(v, :ptr)
end


deltemp(tv::TemporaryVariable) 	= finalize(tv)
maketemp() 						= TemporaryVariable(IDL_Gettmp())
maketemp(x::UCHAR) 				= TemporaryVariable(IDL_GettmpByte(x))
maketemp(x::IDL_INT) 			= TemporaryVariable(IDL_GettmpInt(x))
maketemp(x::IDL_UINT) 			= TemporaryVariable(IDL_GettmpUInt(x))
maketemp(x::IDL_LONG) 			= TemporaryVariable(IDL_GettmpLong(x))
maketemp(x::IDL_ULONG) 			= TemporaryVariable(IDL_GettmpULong(x))
maketemp(x::IDL_LONG64) 		= TemporaryVariable(IDL_GettmpLong64(x))
maketemp(x::IDL_ULONG64) 		= TemporaryVariable(IDL_GettmpULong64(x))
maketemp(x::Cfloat) 			= TemporaryVariable(IDL_GettmpFloat(x))
maketemp(x::Cdouble) 			= TemporaryVariable(IDL_GettmpDouble(x))
# maketemp(x::IDL_HVID) 		= TemporaryVariable(IDL_GettmpPtr(x))
# maketemp(x::IDL_HVID) 		= TemporaryVariable(IDL_GettmpObjRef(x)))
# TODO: maketemp for complex variables?

function idlcopyvar!(dst::AbstractIDLVariable, src::TemporaryVariable)
	IDL_VarCopy(varptr__(src), varptr__(dst))
	# VarCopy frees the temporary variable if it's the source.
	setfield!(src, :safety, false)
end


#============================================================#
#
#	Helper methods to create and retrieve IDL Variables
#
#============================================================#


function set!(v::AbstractIDLVariable, x::T) where {T <: JL_SCALAR}
	all_t__ = Base.unsafe_convert(Ptr{IDL_ALLTYPES}, ALL_T)
	setproperty!(all_t__, _alltypes_sym(idltype(T)), x)
	IDL_StoreScalar(varptr__(v), idltype(T), all_t__)

	return v
end

function set!(v::AbstractIDLVariable, x::AbstractString)

	tmpvar = TemporaryVariable(IDL_StrToSTRING(x))
	# This is efficient, the string data is moved
	idlcopyvar!(v, tmpvar)
	return v
end


function idlvar(name::Symbol)
	var__ = IDL_GetVarAddr(String(name))
	if var__ == C_NULL
		throw(UndefVarError(name, "IDL"))
	end

	return Variable(var__)
end

function idlvar(name::Symbol, ::UndefInitializer)
	var__ = IDL_GetVarAddr(String(name))

	if var__ == C_NULL
		var = Variable(IDL_GetVarAddr1(String(name), IDL_TRUE))
		return var
	end

	IDL_StoreScalarZero(var__, C_NULL)
	return Variable(var__)
end

function idlvar(name::Symbol, x::T) where {T <: JL_SCALAR}
	var__ = IDL_GetVarAddr(String(name))

	if var__ == C_NULL
		var = Variable(IDL_GetVarAddr1(String(name), IDL_TRUE))
		idlcopyvar!(var, maketemp(x))
		return var
	end

	v = set!(Variable(var__), x)
end

function idlvar(name::Symbol, x::String)
	var = Variable(IDL_GetVarAddr1(String(name), IDL_TRUE))
	tmpvar = TemporaryVariable(IDL_StrToSTRING(x))
	idlcopyvar!(var, tmpvar)

	return var
end

#========================================#
#
#	Converting from IDL to Julia
#
#========================================#

error_convert_incompatible_types(t1::Type, t2::Type) =
	throw(ArgumentError("Can't convert two incompatible types: $t1 to $t2"))

# for general purpose conversion, we convert, then copy the tmp var into the old var.
function Base.convert(::Type{T}, v::AbstractIDLVariable) where T <: JL_SCALAR
	isscalar(v) || error_convert_incompatible_types(eltype(v), T)
	_tmpv = IDL_VarTypeConvert(varptr__(v), idltype(T))
	r = unsafe_load(Base.getproperty(_tmpv.value, _alltypes_sym(idltype(T))))

	# If the variable is of the same type, the _tmpvar is not created
	# but the variable itself is returned instead.
	_tmpv != varptr__(v) && IDL_Deltmp(_tmpv)

	convert(T, r)
end

# [!WARN]
# Complex numbers get truncated. Only the real part gets translated.
# In line with IDL behaviour
function Base.convert(::Type{String}, v::AbstractIDLVariable)
	eltype(v) == String || error_convert_incompatible_types(eltype(v), String)
	unsafe_string(IDL_VarGetString(varptr__(v)))
end

function Base.convert(::Type{Bool}, v::AbstractIDLVariable)
	isboolean(v) || error_convert_incompatible_types(eltype(v), Bool)
	Bool(unsafe_load(varscalar(varptr__(v))))
end

# These attempt automatic transformation which is quicker
function Base.convert(::Type{Int32}, v::AbstractIDLVariable)
	isscalar(v) || error_convert_incompatible_types(eltype(v), Int32)
	IDL_LongScalar(varptr__(v))
end

function Base.convert(::Type{UInt32}, v::AbstractIDLVariable)
	isscalar(v) || error_convert_incompatible_types(eltype(v), UInt32)
	IDL_ULongScalar(varptr__(v))
end

function Base.convert(::Type{Int64}, v::AbstractIDLVariable)
	isscalar(v) || error_convert_incompatible_types(eltype(v), Int64)
	IDL_Long64Scalar(varptr__(v))
end

function Base.convert(::Type{UInt64}, v::AbstractIDLVariable)
	isscalar(v) || error_convert_incompatible_types(eltype(v), UInt64)
	IDL_ULong64Scalar(varptr__(v))
end

function Base.convert(::Type{Float64}, v::AbstractIDLVariable)
	isscalar(v) || error_convert_incompatible_types(eltype(v), Float64)
	IDL_DoubleScalar(varptr__(v))
end



jlscalar(v::AbstractIDLVariable) = convert(eltype(v), v)
jlscalar(::Type{T}, v::AbstractIDLVariable) where {T<:JL_SCALAR} = convert(T, v)

jlscalar(name::Symbol) = jlscalar(idlvar(name))
jlscalar(::Type{T}, name::Symbol) where {T<:JL_SCALAR} = jlscalar(T, idlvar(name))


function Base.show(io::IO, s::AbstractIDLVariable)
	conststr = isconst(s) ? "CONST " : ""
	tempstr = istemp(s) ? "TEMP " : ""
	validstr = isvalid(s) ? "" : "UNDEF"

	variablename = unsafe_string(IDL_VarName(varptr__(s)))

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