_ndims(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.n_dim) % Int
_size(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.dim)
# we should return 1 for the dimensions without values, but IDL
# already enforces this.
_size(_a::Ptr{IDL_ARRAY}, d::Integer) = d <= 8 ? unsafe_load(Ptr{Int}(_a.dim), d) : 0
_elsize(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.elt_len)
_length(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.n_elts)
_data(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.data)

# x._customcb = @cfunction($((_p::Ptr{Cuchar}) -> begin
# 	setfield!(x, :_arr, Ptr{IDL_ARRAY}(C_NULL))
# 	nothing
# end), Nothing, (Ptr{Cuchar},))

# unsafe_store!(_arr.free_cb, Base.unsafe_convert(Ptr{Cvoid}, x._customcb))

mutable struct Safety
	engaged::Bool
	Safety() = new(true)
end
safetycheck(s::Safety) = s.engaged
@noinline Base.setproperty!(::Safety, ::Symbol, ::Bool) = error("Can't reset the safety.")

mutable struct ArrayView{T, N} <: AbstractArray{T, N}
	v::Variable
	offset::UInt
	safety::Bool
	_cb::Union{Nothing, Base.CFunction}

	function ArrayView(v::Variable, offset=0; setcb=true)
		@boundscheck checkarray(v)
		N = _ndims(_array(v))
		T = eltype(v)

		arrview = new{T, N}(v, offset, true)
		if setcb
			cb = @cfunction($((::Ptr{Cuchar}) -> begin
				setfield!(arrview, :safety, false)
				return nothing
			end), Nothing, (Ptr{Cuchar},))

			unsafe_store!(_array(v).free_cb, Base.unsafe_convert(Ptr{Cvoid}, cb))
		else
			cb = nothing
		end
		setfield!(arrview, :_cb, cb)

		return arrview
	end
end


# abstract type AbstractArrayView{T, N} <: AbstractArray{T, N} end

# Base.IndexStyle(::AbstractArrayView) = IndexLinear()
# Base.size(x::AbstractArrayView) = safetycheck(x) && _size(_array(x))[1:ndims(x)]
# Base.size(x::AbstractArrayView, d) = _size(_array(x), d)

# Base.eltype(::Type{AbstractArrayView{T, N}}) where {T, N} = T
# Base.length(x::AbstractArrayView) = _length(_array(x))

# Base.firstindex(x::AbstractArrayView) = 1
# Base.lastindex(x::AbstractArrayView) = length(x)

# function Base.iterate(x::AbstractArrayView, state=(eachindex(x),))
#     y = Base.iterate(state...)
#     y === nothing && return nothing
#     x[y[1]], (state[1], Base.tail(y)...)
# end
# Base.IteratorSize(::AbstractArrayView) = Base.HasLength()
# Base.IteratorEltype(::AbstractArrayView) = Base.HasEltype()

# struct UnsafeView{T, N} <: AbstractArrayView{T, N}
# 	v::Variable
# 	offset::UInt

# 	function UnsafeView(v::Variable, offset=0)
# 		@boundscheck checkarray(v)
# 		N = _ndims(_array(v))
# 		T = eltype(v)
# 		return new{T, N}(v, offset)
# 	end
# end

# _array(x::UnsafeView) = _array(x.v)
# _ptr(x::UnsafeView{T, N}) where {T, N} = Ptr{T}(_data(_array(x)) + x.offset)
# _ptr(x::UnsafeView{T, N}) where {T <: AbstractString, N} =
# 	Ptr{IDL_STRING}(_data(_array(x)) + x.offset)

# mutable struct ArrayView2{T, N} <: AbstractArrayView{T, N}
# 	view::UnsafeView{T, N}
# 	safety::Bool
# 	cb::Base.CFunction

# 	function ArrayView2(view::UnsafeView{T, N}) where {T,N}
# 		arrview = new{T, N}(view, true)
# 		cb = @cfunction($((::Ptr{Cuchar}) -> begin
# 			setfield!(arrview, :safety, false)
# 			return nothing
# 		end), Nothing, (Ptr{Cuchar},))
# 		unsafe_store!(_array(view.v).free_cb, Base.unsafe_convert(Ptr{Cvoid}, cb))
# 		setfield!(arrview, :cb, cb)
# 		return arrview
# 	end
# end

function safetycheck(x::ArrayView)
	x.safety ||
	throw(InvalidStateException("""The array the view was pointing to has been freed.

		To keep using this variable extract the variable pointer by calling the `var` method.""", :ArrayView))
end

_array(x::ArrayView) = _array(x.v)
_ptr(x::ArrayView{T, N}) where {T, N} =
	@boundscheck safetycheck(x) && Ptr{T}(_data(_array(x)) + x.offset)
_ptr(x::ArrayView{T, N}) where {T <: AbstractString, N} =
	@boundscheck safetycheck(x) && Ptr{IDL_STRING}(_data(_array(x)) + x.offset)

Base.IndexStyle(::ArrayView) = IndexLinear()
Base.size(x::ArrayView) = safetycheck(x) && _size(_array(x))[1:ndims(x)]
Base.size(x::ArrayView, d) = _size(_array(x), d)

Base.eltype(::Type{ArrayView{T, N}}) where {T, N} = T
Base.length(x::ArrayView) = _length(_array(x))

Base.firstindex(x::ArrayView) = 1
Base.lastindex(x::ArrayView) = length(x)

function Base.iterate(x::ArrayView, state=(eachindex(x),))
    y = Base.iterate(state...)
    y === nothing && return nothing
    x[y[1]], (state[1], Base.tail(y)...)
end
Base.IteratorSize(::ArrayView) = Base.HasLength()
Base.IteratorEltype(::ArrayView) = Base.HasEltype()

# # FIXME, the passed in tuple must match the number of axes!
# Base.checkbounds(x::ArrayView, I...) = Base.checkbounds(Bool, x, I...) || throw(BoundsError(x, I))
# Base.checkbounds(::Type{Bool}, x::ArrayView, I...) = Base.checkbounds_indices(Bool, axes(x), I)

# Base.checkbounds(x::ArrayView, i::Int) = Base.checkbounds(Bool, x, i) || throw(BoundsError(x, i))
# Base.checkbounds(::Type{Bool}, x::ArrayView, i) = Base.checkindex(Bool, Base.OneTo(length(x)), i)

Base.getindex(x::ArrayView{T, N}, i::Integer) where {T, N} = begin
	@boundscheck checkbounds(x, i)
	convert(T, unsafe_load(_ptr(x), i))
end

# Base.getindex(x::ArrayView, I...) = begin
# 	_getindex(x, to_indices(x, I)...)
# end

# _getindex(x::ArrayView, I...) = begin
# 	@boundscheck checkbounds(x, I...)
# 	@inbounds getindex(x, Base._sub2ind(axes(x), I...))
# end

Base.setindex!(x::ArrayView, v::T, i) where T <: JL_SCALAR = begin
	@boundscheck checkbounds(x, i)
	T == eltype(x) ||
		throw(ArgumentError("Attempting to set an element of type $T to an array of $(eltype(x))s"))

	unsafe_store!(_ptr(x), v, i)
end

Base.setindex!(x::ArrayView, v::AbstractString, i) = begin
	@boundscheck checkbounds(x, i)

	eltype(x) == String ||
		throw(ArgumentError("Attempting to add an element of type String to an array of $(eltype(x))s"))

	IDL_StrStore(_ptr(x) + (sizeof(IDL_STRING) * (Int(i) - 1)), v)
end

# Base.setindex!(x::ArrayView, v, I...) = begin
# 	_setindex!(x, v, to_indices(x, I)...)
# end

# _setindex!(x::ArrayView, v, I...) = begin
# 	@boundscheck checkbounds(x, I...)
# 	@inbounds setindex!(x, v, Base._sub2ind(axes(x), I...))
# end


idlvar(x::ArrayView) = x.v

idlview(v::Variable) = ArrayView(v)
idlview(name::Symbol) = view(idlvar(name))

unsafe_idlview(v::Variable) = ArrayView(v; setcb=false)
unsafe_idlview(name::Symbol) = unsafe_idlview(idlvar(name))

jlarray(x::ArrayView{T, N}) where {T, N} = copyto!(similar(x), x)
jlarray(v::Variable) = jlarray(unsafe_idlview(v))
jlarray(name::Symbol) = jlarray(idlvar(name))


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
idlarray(v::Variable, arr::Array{T, N}) where {T<:JL_SCALAR, N} = begin
	_v = _mkarray(name(v), arr)
	@assert v._v == _v
	unsafe_idlview(v)
end

idlarray(name::Symbol, arr::Array{T, N}) where {T<:JL_SCALAR, N} = begin
	unsafe_idlview(Variable(_mkarray(String(name), arr)))
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





