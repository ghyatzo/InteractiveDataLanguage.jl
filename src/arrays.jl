_ndims(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.n_dim) % Int
_size(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.dim)
# we should return 1 for the dimensions without values, but IDL
# already enforces this.
_size(_a::Ptr{IDL_ARRAY}, d::Integer) = d <= 8 ? unsafe_load(Ptr{Int}(_a.dim), d) : 0
_elsize(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.elt_len)
_length(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.n_elts)
_data(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.data)


mutable struct ArrayView
	v::Variable
	offset::UInt
end
function ArrayView(v::Variable)
	isarray(v) || throw(ArgumentError("The variable be an IDL Array."))
	return ArrayView(v, 0)
end

_array(x::ArrayView) = _array(x.v)
isvalid(x::ArrayView) = isvalid(x.v) && isarray(x.v)

Base.IndexStyle(::ArrayView) = IndexLinear()
Base.ndims(x::ArrayView) = _ndims(_array(x))
Base.size(x::ArrayView) = _size(_array(x))[1:ndims(x)]
Base.size(x::ArrayView, d) = _size(_array(x), d)
# Base.axes(x::ArrayView) = map(Base.OneTo, _size(_array(x)))
Base.eltype(x::ArrayView) = eltype(x.v)
Base.length(x::ArrayView) = _length(_array(x))
# Base.keys(x::ArrayView) = ndims(x) > 1 ? CartesianIndices(axes(x)) : LinearIndices(Base.axes1(x))
# Base.keys(::IndexLinear, x::ArrayView) = LinearIndices(axes(x))
# Base.keys(::IndexCartesian, x::ArrayView) = CartesianIndices(axes(x))
Base.firstindex(x::ArrayView) = 1
Base.lastindex(x::ArrayView) = length(x)

data(x::ArrayView) = begin
	isvalid(x) ||
		throw(InvalidStateException("""The variable no longer points to an array.
			To keep using this variable extract the underlaying variable by calling
			the `var` method.""", :ArrayView))
	Ptr{eltype(x)}(_data(_array(x)) + x.offset)
end

function Base.iterate(x::ArrayView, state=(eachindex(x),))
    y = Base.iterate(state...)
    y === nothing && return nothing
    x[y[1]], (state[1], Base.tail(y)...)
end

Base.isassigned(x::ArrayView, ::Integer) = isvalid(x)
Base.isassigned(x::ArrayView, ::Vararg{Integer}) = isvalid(x)

# FIXME, the passed in tuple must match the number of axes!
Base.checkbounds(x::ArrayView, I...) = Base.checkbounds(Bool, x, I...) || throw(BoundsError(x, I))
Base.checkbounds(::Type{Bool}, x::ArrayView, I...) = Base.checkbounds_indices(Bool, axes(x), I)

Base.checkbounds(x::ArrayView, i::Int) = Base.checkbounds(Bool, x, i) || throw(BoundsError(x, i))
Base.checkbounds(::Type{Bool}, x::ArrayView, i) = Base.checkindex(Bool, Base.OneTo(length(x)), i)

Base.getindex(x::ArrayView, i::Integer) = begin
	@boundscheck checkbounds(x, i)
	idl2jl(unsafe_load(data(x), i))
end

Base.getindex(x::ArrayView, I...) = begin
	_getindex(x, to_indices(x, I)...)
end

_getindex(x::ArrayView, I...) = begin
	@boundscheck checkbounds(x, I...)
	@inbounds getindex(x, Base._sub2ind(axes(x), I...))
end

Base.setindex!(x::ArrayView, v::T, i) where T <: JL_SCALAR = begin
	@boundscheck checkbounds(x, i)
	T == eltype(x) ||
		throw(ArgumentError("Attempting to set an element of type $T to an array of $(eltype(x))s"))

	unsafe_store!(data(x), v, i)
end

Base.setindex!(x::ArrayView, v::AbstractString, i) = begin
	@boundscheck checkbounds(x, i)

	eltype(x) == String ||
		throw(ArgumentError("Attempting to add an element of type String to an array of $(eltype(x))s"))

	IDL_StrStore(data(x) + (sizeof(IDL_STRING) * (Int(i) - 1)), v)
end

Base.setindex!(x::ArrayView, v, I...) = begin
	_setindex!(x, v, to_indices(x, I)...)
end

_setindex!(x::ArrayView, v, I...) = begin
	@boundscheck checkbounds(x, I...)
	@inbounds setindex!(x, v, Base._sub2ind(axes(x), I...))
end


var(x::ArrayView) = x.v

array(v::Variable) = ArrayView(v)
array(name::Symbol) = array(var(name))

copyarray(x::ArrayView) = begin
	N = ndims(x)
	T = eltype(x)

	ret = Array{T, N}(undef, size(x)...)
	for i in eachindex(ret)
		ret[i] = x[i]
	end
	return ret
end
copyarray(v::Variable) = copyarray(array(v))
copyarray(name::Symbol) = copyarray(var(name))



struct JLArrayRoot
	name::String
	ndims::Int
	dims::NTuple{8, Int}
	dataref::Ref
end
_mkarray(name::String, arr::Array{T, N}) where {T<:JL_SCALAR, N} = begin
	N > 8 && throw(ArgumentError("IDL Arrays can have at most 8 dimensions."))

	root = Ref{JLArrayRoot}(JLArrayRoot(
		name, N, (size(arr)..., zeros(8-N)...), arr.ref
	))

	_root = pointer_from_objref(root)

	_root_data = preserve_ref(pointer(arr), root)
	_root_dims = _root + fieldoffset(typeof(root), 1) + fieldoffset(JLArrayRoot, 3)

	_var = IDL_ImportNamedArray(
		root[].name,
		root[].ndims,
		_root_dims,
		idltype(T),
		_root_data,
		FREE_JLARR[],
		C_NULL
	)

	_var
end
array(v::Variable, arr::Array{T, N}) where {T<:JL_SCALAR, N} = begin
	_v = _mkarray(name(v), arr)
	@assert v._v == _v
	array(v)
end

array(name::Symbol, arr::Array{T, N}) where {T<:JL_SCALAR, N} = begin
	array(Variable(_mkarray(String(name), arr)))
end









# idldims(d::Vararg{Integer}) = begin
# 	nd = length(d)
# 	nd > 8 && throw(ArgumentError("IDL Arrays support at most 8 dimensions."))

# 	dims = ones(8)
# 	dims[1:nd] .= d
# 	return dims
# end

# idlzeros(T::Type, D::Vararg{Integer}) = begin
# 	_tmp = IDL_Gettmp()
# 	IDL_MakeTempArray(idltype(T), length(D), idldims(D...), IDL_ARR_INI_ZERO, _tmp)
# 	_v = IDL_GetVarAddr1(idlgensym(), IDL_TRUE)
# 	IDL_VarCopy(_tmp, _v)
# 	ArrayView(Variable(_v))
# end
# idlzeros(D::Vararg{Integer}) = idlzeros(Float64, D...)




# mutable struct ArrayView{T, N} <: AbstractArray{T, N}
# 	_arr::Ptr{IDL_ARRAY}
# 	dataoverride::Ptr{Cuchar}
# 	_customcb::Base.CFunction

# 	function ArrayView(v::Variable, inheriteddata = C_NULL)
# 		isarray(v) || throw(ArgumentError("The variable must point to an IDL Array."))

# 		_arr = unsafe_load(v._v.value.arr)
# 		N = unsafe_load(_arr.n_dim) % Int
# 		T = eltype(v)

# 		x = new{T, N}(_arr, inheriteddata)

# 		# The default callback invalidates the ArrayView
# 		x._customcb = @cfunction($((_p::Ptr{Cuchar}) -> begin
# 			setfield!(x, :_arr, Ptr{IDL_ARRAY}(C_NULL))
# 			nothing
# 		end), Nothing, (Ptr{Cuchar},))

# 		unsafe_store!(_arr.free_cb, Base.unsafe_convert(Ptr{Cvoid}, x._customcb))

# 		return x
# 	end
# end



# _dataptr(x::ArrayView{T, N}) where {T, N} = begin
# 	x.dataoverride == C_NULL ? Ptr{T}(unsafe_load(x._arr.data)) : Ptr{T}(x.dataoverride)
# end





