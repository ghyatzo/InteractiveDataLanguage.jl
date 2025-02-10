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

struct IDLVariable
	_v::Ptr{IDL_VARIABLE}
end
makevar(_v::Ptr{IDL_VARIABLE}) = begin
	var_f, var_t = varinfo(_var)

	if (var_f & IDL_V_FILE) != 0
		error("File Variables not yet implemented")
	end

	(var_t == IDL_TYP_PTR || var_t == IDL_TYP_OBJREF) &&
		error("Getting variables of type IDL_TYP_PTR or IDL_TYP_OBJREF is not supported.")

	IDLVariable(_v)
end
flags(v::IDLVariable) = unsafe_load(v._v.flags)

# const variables should not be changed. not enforced by IDL.
isconst(v::IDLVariable) = (flags(v) & IDL_V_CONST) != 0
istemp(v::IDLVariable) = (flags(v) & IDL_V_TEMP) != 0
isarray(v::IDLVariable) = (flags(v) & IDL_V_ARR) != 0
isfile(v::IDLVariable) = (flags(v) & IDL_V_FILE) != 0
# dynamic variables are arrays, structures or strings, because the
# data is behind a pointer.
isdynamic(v::IDLVariable) = (flags(v) & IDL_V_DYNAMIC) != 0
isstruct(v::IDLVariable) = (flags(v) & IDL_V_STRUCT) != 0
isscalar(v::IDLVariable) = !isarray(v) && !IDL.isfile(v)
Base.isnothing(v::IDLVariable) = (flags(v) & IDL_V_NULL) != 0

Base.eltype(v::IDLVariable) = begin
	# TODO: check if array of struct
	jltype(unsafe_load(v._v.type))
end

# make temporary variables
maketemp() = makevar(IDL_Gettmp(Cvoid))
maketemp(v::UCHAR) = makevar(IDL_GettmpByte(v))
maketemp(v::IDL_INT) = makevar(IDL_GettmpInt(v))
maketemp(c::IDL_LONG) = makevar(IDL_GettmpLong(v))
maketemp(c::Cfloat) = makevar(IDL_GettmpFloat(v))
maketemp(c::Cdouble) = makevar(IDL_GettmpDouble(v))
# maketemp(c::IDL_HVID) = makevar(IDL_GettmpPtr(v))
# maketemp(c::IDL_HVID) = makevar(IDL_GettmpObjRef(v))
maketemp(c::IDL_UINT) = makevar(IDL_GettmpUInt(v))
maketemp(c::IDL_ULONG) = makevar(IDL_GettmpULong(v))
maketemp(c::IDL_LONG64) = makevar(IDL_GettmpLong64(v))
maketemp(c::IDL_ULONG64) = makevar(IDL_GettmpULong64(v))
freetmp(v::IDLVariable) = makevar(IDL_Freetmp(v._v))
deltmp(v::IDLVariable) = istemp(v) && IDL_Deltmp(v._v)


# for general purpose conversion, we convert, then copy the tmp var into the old var.
Base.convert(::Type{T}, v::IDLVariable) where T <: JL_SCALAR = begin
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


Base.convert(::Type{String}, v::IDLVariable) = begin
	typeof(v) == String || throw(ArgumentError("The IDL variable is not a string type"))
	unsafe_string(IDL_VarGetString(v._v))
end
# These attempt automatic transformation which is quicker
Base.convert(::Type{Int32}, v::IDLVariable) = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_LongScalar(v._v)
end
Base.convert(::Type{UInt32}, v::IDLVariable) = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_ULongScalar(v._v)
end
Base.convert(::Type{Int64}, v::IDLVariable) = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_Long64Scalar(v._v)
end
Base.convert(::Type{UInt64}, v::IDLVariable) = begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_ULong64Scalar(v._v)
end
Base.convert(::Type{Float64}, v::IDLVariable) =  begin
	isscalar(v) || throw(ArgumentError("Can't convert a non scalar variable into a scalar value."))
	IDL_DoubleScalar(v._v)
end

