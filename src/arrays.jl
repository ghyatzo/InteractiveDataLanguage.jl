_ndims(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.n_dim) % Int
_size(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.dim)
# we should return 1 for the dimensions without values, but IDL
# already enforces this.
_size(_a::Ptr{IDL_ARRAY}, d::Integer) = d <= 8 ? unsafe_load(Ptr{Int}(_a.dim), d) : 0
_elsize(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.elt_len)
_length(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.n_elts)
_data(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.data)
_set_free_cb(_arr::Ptr{IDL_ARRAY}, cb::Ptr{Cvoid}) = unsafe_store!(_arr.free_cb, cb)



checkdims(::AbstractArray{T, N}) where {T,N} =
	N > IDL_MAX_ARRAY_DIM && throw(ArgumentError("IDL Arrays can have at most $IDL_MAX_ARRAY_DIM dimensions."))

abstract type AbstractArrayView{T, N} <: AbstractArray{T, N} end
function _array end
function _ptr end

Base.IndexStyle(::AbstractArrayView) = IndexLinear()

Base.eltype(::Type{AbstractArrayView{T, N}}) where {T, N} = T

Base.size(x::AbstractArrayView) = _size(_array(x))[1:ndims(x)]
Base.size(x::AbstractArrayView, d) = _size(_array(x), d)
Base.length(x::AbstractArrayView) = _length(_array(x))
Base.firstindex(x::AbstractArrayView) = 1
Base.lastindex(x::AbstractArrayView) = length(x)

function Base.iterate(x::AbstractArrayView, state=(eachindex(x),))
    y = Base.iterate(state...)
    y === nothing && return nothing
    x[y[1]], (state[1], Base.tail(y)...)
end
Base.IteratorSize(::AbstractArrayView) = Base.HasLength()
Base.IteratorEltype(::AbstractArrayView) = Base.HasEltype()

Base.getindex(x::AbstractArrayView{T, N}, i::Integer) where {T, N} = begin
	@boundscheck checkbounds(x, i)
	convert(T, unsafe_load(_ptr(x), i))
end

Base.setindex!(x::AbstractArrayView{T, N}, v::T, i) where {T <: JL_SCALAR, N} = begin
	@boundscheck checkbounds(x, i)
	unsafe_store!(_ptr(x), v, i)
end

Base.setindex!(x::AbstractArrayView{<:AbstractString}, v::AbstractString, i) = begin
	@boundscheck checkbounds(x, i)
	IDL_StrStore(_ptr(x) + (sizeof(IDL_STRING) * (Int(i) - 1)), v)
end

struct UnsafeView{T, N, V} <: AbstractArrayView{T, N}
	v::V
	offset::UInt

	function UnsafeView(v::V, offset=0) where V <: AbstractIDLVariable
		@boundscheck checkarray(v)
		N = _ndims(_array(v))
		T = eltype(v)
		return new{T, N, V}(v, offset)
	end
end

_array(x::UnsafeView) = unsafe_load(_varptr(x.v).value.arr)
_ptr(x::UnsafeView{T}) where {T} = Ptr{T}(_data(_array(x)) + x.offset)
_ptr(x::UnsafeView{<:AbstractString}) = Ptr{IDL_STRING}(_data(_array(x)) + x.offset)


mutable struct ArrayView{T, N, V} <: AbstractArrayView{T, N}
	v::V
	safety::Bool
	_arr::Ptr{IDL_ARRAY}

	function ArrayView(v::V) where V <: AbstractIDLVariable
		N = _ndims(_array(v))
		T = eltype(v)
		_arr = _array(v)
		this = new{T, N, V}(v, true, _arr)

		cb = @cfunction($((_p::Ptr{Cuchar}) -> begin
			# This callback assumes that when it is called, a valid reference to
			# `this` still exists and has not been gc'ed.
			# safeprintln("$(name(v)) FREED FROM IDL")
			setfield!(this, :safety, false)
			delete!(CB_HOLDING, _p)

			return nothing
		end), Nothing, (Ptr{Cuchar},))

		# each callback is associated with the array data pointer
		# that, when freed, would call it
		preserve_cb(_data(_arr), cb)
		_set_free_cb(_array(v), Base.unsafe_convert(Ptr{Cvoid}, cb))

		finalizer(this) do this
			# We must check that the data has not been freed, since this finalizer
			# can also be called after the IDL data has been freed!
			#
			# If the IDL Array has already been freed (safety false), while this view was still alive
			# Then the original callback has been called successfully and all is good.
			if getfield(this, :safety)
				# this means that the IDL array is still alive.
				# we can unset the callback and delete its ref.
				# safeprintln("$(name(this.v)) FREED FROM JULIA")
				_set_free_cb(this._arr, C_NULL)
				delete!(CB_HOLDING, _data(this._arr))

				setfield!(this, :safety, false)
			end

			return nothing
		end
	end
end

function safetycheck(x::ArrayView)
	getfield(x, :safety) || throw(InvalidStateException("""
		The array the view was pointing to has been freed.\n
		To keep using this variable extract the variable pointer by calling the `var` method.""",
	:ArrayView))
end

_array(x::ArrayView) = safetycheck(x) && _array(x.v)
_ptr(x::ArrayView{T}) where {T} = Ptr{T}(_data(_array(x)))
_ptr(x::ArrayView{<: AbstractString}) = Ptr{IDL_STRING}(_data(_array(x)))

idlvar(x::ArrayView) = x.v

# From IDL memory to Julia
unsafe_jlview(v::AbstractIDLVariable) = UnsafeView(v)
unsafe_jlview(name::Symbol) = unsafe_jlview(idlvar(name))

jlview(v::AbstractIDLVariable) = ArrayView(v)
jlview(name::Symbol) = jlview(idlvar(name))

jlarray(x::AbstractArrayView{T, N}) where {T, N} = copyto!(similar(x), x)
jlarray(v::AbstractIDLVariable) = jlarray(unsafe_jlview(v))
jlarray(name::Symbol) = jlarray(idlvar(name))

# From Julia Memory to IDL
const DIMS = SizedVector{IDL_MAX_ARRAY_DIM}(zeros(IDL_MEMINT, IDL_MAX_ARRAY_DIM))

function idldims(arr::AbstractArray{T, N}) where {T, N}
	checkdims(arr)

	DIMS[1:N] .= IDL_MEMINT.(size(arr))
	DIMS[N+1:end] .= zero(IDL_MEMINT)

	return DIMS
end

function idlsimilar(arr::AbstractArray{T, N}) where {T, N}
	_tmpvarref = Ref{Ptr{IDL_VARIABLE}}()

	IDL_MakeTempArray(idltype(T), N, idldims(arr), IDL_ARR_INI_NOP, _tmpvarref)

	return TemporaryVariable(_tmpvarref[])
end

function maketempwrap(arr::Array{T,N}) where {T<:JL_SCALAR, N}
	checkdims(arr)

	_rooted_data = preserve_ref(pointer(arr), arr.ref)

	_var = IDL_ImportArray(
		N, idldims(arr), idltype(T), _rooted_data, JL_DROPREF[], C_NULL
	)

	TemporaryVariable(_var)
end

function maketemp(arr::Array{T, N}) where {T, N}
	tmpvar = idlsimilar(arr)
	copyto!(unsafe_jlview(tmpvar), arr)

	return tmpvar
end

function idlwrap(name::Symbol, arr::Array{T, N}) where {T<:JL_SCALAR, N}
	checkdims(arr)

	_rooted_data = preserve_ref(pointer(arr), arr.ref)

	_var = IDL_ImportNamedArray(
		name, N, idldims(arr), idltype(T), _rooted_data, JL_DROPREF[], C_NULL
	)

	return Variable(_var)
end

idlwrap(v::Variable, arr::Array{T, N}) where {T<:JL_SCALAR, N} = idlwrap(Symbol(name(v)), arr)


function idlarray(v::Variable, arr::Array{T, N}) where {T, N}

	tmpvar = idlsimilar(arr)
	idlcopyvar!(v, tmpvar)
	copyto!(unsafe_jlview(v), arr)

	return v
end

idlarray(name::Symbol, arr::Array{T, N}) where {T,N} = idlarray(idlvar(name), arr)



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





