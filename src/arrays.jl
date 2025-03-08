_ndims(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.n_dim) % Int
_size(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.dim)[1:_ndims(_a)]
# we should return 1 for the dimensions without values, but IDL
# already enforces this.
_size(_a::Ptr{IDL_ARRAY}, d::Integer) = d <= 8 ? unsafe_load(Ptr{Int}(_a.dim), d) : 0
_elsize(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.elt_len)
_length(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.n_elts)
_data(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.data)
_store_cb!(_a::Ptr{IDL_ARRAY}, cb::Base.CFunction) =
	unsafe_store!(_a.free_cb, Base.unsafe_convert(Ptr{Cvoid}, cb))

mutable struct UnsafeArrayView
	v::Variable
	offset::UInt

	function UnsafeArrayView(v::Variable, offset = zero(UInt8))
		isarray(v) || throw(ArgumentError("The variable must point to an IDL Array."))
		return new(v, offset)
	end
end
unwrap(x::UnsafeArrayView) = x.v
_array(x::UnsafeArrayView) = _array(x.v)
isvalid(x::UnsafeArrayView) = isvalid(x.v) && isarray(x.v)

Base.IndexStyle(::UnsafeArrayView) = IndexCartesian()
Base.eltype(x::UnsafeArrayView) = jltype(_type(x.v))
Base.size(x::UnsafeArrayView) = _size(_array(x))
Base.size(x::UnsafeArrayView, d) = _size(_array(x), d)
Base.length(x::UnsafeArrayView) = _length(_array(x))
Base.ndims(x::UnsafeArrayView) = _ndims(_array(x))
Base.keys(x::UnsafeArrayView) = ndims(x) > 1 ? CartesianIndices(axes(x)) : LinearIndices(Base.axes1(x))
Base.firstindex(x::UnsafeArrayView) = 1
Base.lastindex(x::UnsafeArrayView) = length(x)

data(x::UnsafeArrayView) = begin
	isvalid(x) ||
		throw(InvalidStateException("""The variable no longer points to an array.
			To keep using this variable extract the underlaying variable by calling
			the `unwrap` method.""", :UnsafeArrayView))
	Ptr{eltype(x)}(_data(_array(x)) + x.offset)
end

function Base.iterate(x::UnsafeArrayView, state=(eachindex(x),))
    y = Base.iterate(state...)
    y === nothing && return nothing
    x[y[1]], (state[1], Base.tail(y)...)
end

Base.isassigned(x::UnsafeArrayView, ::Integer) = isvalid(x)
Base.isassigned(x::UnsafeArrayView, ::Vararg{Integer}) = isvalid(x)

# FIXME, the passed in tuple must match the number of axes!
Base.checkbounds(::Type{Bool}, x::UnsafeArrayView, I...) = Base.checkbounds_indices(Bool, axes(x), I)
Base.checkbounds(x::UnsafeArrayView, I...) = Base.checkbounds(Bool, x, I...) || throw(BoundsError(x, I))

Base.checkbounds(::Type{Bool}, x::UnsafeArrayView, i) = Base.checkindex(Bool, Base.OneTo(length(x)), i)
Base.checkbounds(x::UnsafeArrayView, i::Int) = Base.checkbounds(Bool, x, i) || throw(BoundsError(x, i))

Base.getindex(x::UnsafeArrayView, i::Integer) = begin
	@boundscheck checkbounds(x, i)
	idlconvert(unsafe_load(data(x), i))
end

Base.getindex(x::UnsafeArrayView, I...) = begin
	_getindex(x, to_indices(x, I)...)
end

_getindex(x::UnsafeArrayView, I...) = begin
	@boundscheck checkbounds(x, I...)
	@inbounds getindex(x, Base._sub2ind(axes(x), I...))
end

Base.setindex!(x::UnsafeArrayView, v::T, i) where T <: JL_SCALAR = begin
	@boundscheck checkbounds(x, i)
	T == eltype(x) ||
		throw(ArgumentError("Attempting to add an element of type $T to an array of $(eltype(x))s"))

	unsafe_store!(data(x), v, i)
end

Base.setindex!(x::UnsafeArrayView, v::AbstractString, i) = begin
	@boundscheck checkbounds(x, i)

	eltype(x) == String ||
		throw(ArgumentError("Attempting to add an element of type String to an array of $(eltype(x))s"))

	IDL_StrStore(data(x) + (sizeof(IDL_STRING) * (Int(i) - 1)), v)
end

Base.setindex!(x::UnsafeArrayView, v, I...) = begin
	_setindex!(x, v, to_indices(x, I)...)
end

_setindex!(x::UnsafeArrayView, v, I...) = begin
	@boundscheck checkbounds(x, I...)
	@inbounds setindex!(x, v, Base._sub2ind(axes(x), I...))
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
# 	UnsafeArrayView(Variable(_v))
# end
# idlzeros(D::Vararg{Integer}) = idlzeros(Float64, D...)




# mutable struct UnsafeArrayView{T, N} <: AbstractArray{T, N}
# 	_arr::Ptr{IDL_ARRAY}
# 	dataoverride::Ptr{Cuchar}
# 	_customcb::Base.CFunction

# 	function UnsafeArrayView(v::Variable, inheriteddata = C_NULL)
# 		isarray(v) || throw(ArgumentError("The variable must point to an IDL Array."))

# 		_arr = unsafe_load(v._v.value.arr)
# 		N = unsafe_load(_arr.n_dim) % Int
# 		T = eltype(v)

# 		x = new{T, N}(_arr, inheriteddata)

# 		# The default callback invalidates the UnsafeArrayView
# 		x._customcb = @cfunction($((_p::Ptr{Cuchar}) -> begin
# 			setfield!(x, :_arr, Ptr{IDL_ARRAY}(C_NULL))
# 			nothing
# 		end), Nothing, (Ptr{Cuchar},))

# 		unsafe_store!(_arr.free_cb, Base.unsafe_convert(Ptr{Cvoid}, x._customcb))

# 		return x
# 	end
# end



# _dataptr(x::UnsafeArrayView{T, N}) where {T, N} = begin
# 	x.dataoverride == C_NULL ? Ptr{T}(unsafe_load(x._arr.data)) : Ptr{T}(x.dataoverride)
# end





