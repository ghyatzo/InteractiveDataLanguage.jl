#========================================#
#
#	Accessors to C struct fields
#
#========================================#

arr_ndims(a__::Ptr{IDL_ARRAY}) 				= unsafe_load(a__.n_dim) % Int
arr_size(a__::Ptr{IDL_ARRAY}) 				= unsafe_load(a__.dim)

# we should return 1 for the dimensions without values, but IDL
# already enforces this.
arr_size(a__::Ptr{IDL_ARRAY}, d::Integer) 	=
	d <= IDL_MAX_ARRAY_DIM ? unsafe_load(Ptr{Int}(a__.dim), d) : 0
arr_elsize(a__::Ptr{IDL_ARRAY}) 			= unsafe_load(a__.elt_len)
arr_length(a__::Ptr{IDL_ARRAY}) 			= unsafe_load(a__.n_elts)
arr_data__(a__::Ptr{IDL_ARRAY}) 			= unsafe_load(a__.data)

_set_free_cb(arr__::Ptr{IDL_ARRAY}, cb::Ptr{Cvoid}) = unsafe_store!(arr__.free_cb, cb)


checkdims(::AbstractArray{T, N}) where {T,N} =
	N > IDL_MAX_ARRAY_DIM && throw(ArgumentError("IDL Arrays can have at most $IDL_MAX_ARRAY_DIM dimensions."))

#========================================#
#
#	Generic IDL Array View Interface
#
#========================================#

abstract type AbstractArrayView{T, N} <: AbstractArray{T, N} end
function array__ end
function data__ end

Base.IndexStyle(::AbstractArrayView) 				= IndexLinear()
Base.eltype(::Type{AbstractArrayView{T}}) where {T} = T
Base.size(x::AbstractArrayView{T, N}) where {T,N} 	= @inbounds arr_size(array__(x))[1:N]
Base.size(x::AbstractArrayView, d) 					= arr_size(array__(x), d)
Base.length(x::AbstractArrayView) 					= arr_length(array__(x))
Base.firstindex(x::AbstractArrayView) 				= 1
Base.lastindex(x::AbstractArrayView) 				= length(x)

function Base.iterate(x::AbstractArrayView, state=(eachindex(x),))
	y = Base.iterate(state...)
	y === nothing && return nothing
	x[y[1]], (state[1], Base.tail(y)...)
end

function Base.getindex(x::AbstractArrayView{T, N}, i::Integer) where {T, N}
	@boundscheck checkbounds(x, i)
	convert(T, unsafe_load(data__(x), i))
end

function Base.setindex!(x::AbstractArrayView{T, N}, v, i) where {T <: JL_SCALAR, N}
	@boundscheck checkbounds(x, i)
	unsafe_store!(data__(x), convert(T, v), i)
end

function Base.setindex!(x::AbstractArrayView{<:AbstractString}, v::AbstractString, i)
	@boundscheck checkbounds(x, i)
	IDL_StrStore(data__(x) + (sizeof(IDL_STRING) * (Int(i) - 1)), v)
end


#========================================#
#
#	Unsafe View with no checks
#
#========================================#


struct UnsafeView{T, N, V} <: AbstractArrayView{T, N}
	v::V
	offset::UInt

	function UnsafeView(v::V, offset=0) where V <: AbstractIDLVariable
		N = arr_ndims(array__(v))
		T = eltype(v)
		return new{T, N, V}(v, offset)
	end
end

array__(x::UnsafeView) 					= vararray__(varptr__(x.v))
data__(x::UnsafeView{T}) where {T} 		= Ptr{T}(arr_data__(array__(x)) + x.offset)
data__(x::UnsafeView{<:AbstractString}) = Ptr{IDL_STRING}(arr_data__(array__(x)) + x.offset)

idlvar(x::UnsafeView) = getfield(x, :v)

#========================================#
#
#	Normal View with safety checks
#
#========================================#


mutable struct ArrayView{T, N, V} <: AbstractArrayView{T, N}
	safety::Bool
	extern::Bool
	const v::V
	const arr::Ptr{IDL_ARRAY}

	function ArrayView(v::V) where V <: AbstractIDLVariable
		arr__ = array__(v)
		N = arr_ndims(arr__)
		T = eltype(v)

		this = new{T, N, V}(true, false, v, arr__)
		weakthis = WeakRef(this)

		cb = (p__::Ptr{Cuchar}) -> begin
			# This callback assumes that when it is called, a valid reference to
			# `this` still exists and has not been gc'ed.
			# we need to hold a weak ref so that storing the cb does not prevent the view from being gc'ed.
			local this = weakthis.value
			if this !== nothing
				setfield!(this, :safety, false)
				setfield!(this, :extern, true)
			end
			# if called, it means that the data is not valid anymore, delete this callback in any case.
			delete!(CB_HOLDING, p__)

			return nothing
		end

		# each callback is associated with the array data pointer
		# that, when freed, would call it
		preserve_cb(arr_data__(arr__), cb)
		_set_free_cb(array__(v), __PASSTHROUGH_CB[])

		finalizer(this) do this
			# We must check that the data has not been freed, since this finalizer
			# can also be called after the IDL data has been freed!
			#
			# If the IDL Array has already been freed (safety false), while this view was still alive
			# Then the original callback has been called successfully and all is gucci.
			if getfield(this, :safety)
				# otherwise the IDL array is still alive.
				# we can unset the callback and delete its ref.
				_set_free_cb(getfield(this, :arr), C_NULL)
				delete!(CB_HOLDING, arr_data__(getfield(this, :arr)))

				setfield!(this, :safety, false)
				setfield!(this, :extern, false)
			end

			return nothing
		end
	end
end

function safetycheck(x::ArrayView)
	getfield(x, :safety) || throw(InvalidStateException("""
		The array the view was pointing to has been freed $(getfield(x, :extern) ? " by IDL" : " by Julia.")\n
		To continue using the binding convert it back to a generic variable with `idlvar`.""",
	:ArrayView))
end

array__(x::ArrayView) 					= (safetycheck(x); return array__(x.v))
data__(x::ArrayView{T}) where {T} 		= Ptr{T}(arr_data__(array__(x)))
data__(x::ArrayView{<: AbstractString}) = Ptr{IDL_STRING}(arr_data__(array__(x)))

idlvar(x::ArrayView) = getfield(x, :v)

#============================================================#
#
#	Initialize IDL memory from Julia
#
#============================================================#

# Initialize a container for specifying the dimensions passed through the ccall.
# IDL will copy its contents, so we can reuse it.
const DIMS = SizedVector{IDL_MAX_ARRAY_DIM}(zeros(IDL_MEMINT, IDL_MAX_ARRAY_DIM))

function idldims(arr::AbstractArray{T, N}) where {T, N}
	checkdims(arr)

	DIMS[1:N] .= IDL_MEMINT.(size(arr))
	DIMS[N+1:end] .= zero(IDL_MEMINT)
	# IDL is colum major in memory but arrays have first and second dimensions swapped

	return DIMS
end

function idldims(arr::AbstractVector)

	DIMS .= zero(IDL_MEMINT)
	DIMS[1] = length(arr)

	return DIMS
end

function idlsimilar(arr::AbstractArray{T, N}) where {T <: JL_SCALAR, N}
	tmpvarref__ = Ref{Ptr{IDL_VARIABLE}}()

	IDL_MakeTempArray(idltype(T), N, idldims(arr), IDL_ARR_INI_NOP, tmpvarref__)

	return TemporaryVariable(tmpvarref__[])
end

function idlsimilar(arr::AbstractArray{<:AbstractString, N}) where {N}
	tmpvarref__ = Ref{Ptr{IDL_VARIABLE}}()

	IDL_MakeTempArray(T_STRING, N, idldims(arr), IDL_ARR_INI_NOP, tmpvarref__)

	return TemporaryVariable(tmpvarref__[])
end

function maketempwrap(arr::Array{T,N}) where {T<:JL_SCALAR, N}
	@boundscheck checkdims(arr)

	rooted_data__ = preserve_ref__(pointer(arr), arr.ref)

	var__ = IDL_ImportArray(
		N, idldims(arr), idltype(T), rooted_data__, __JL_DROPREF[], C_NULL
	)

	TemporaryVariable(var__)
end

function maketemp(arr::Array{T, N}) where {T<:JL_SCALAR, N}
	tmpvar = idlsimilar(arr)
	copyto!(unsafe_jlview(tmpvar), arr)

	return tmpvar
end

function maketemp(arr::Array{<:AbstractString, N}) where {N}
	tmpvar = idlsimilar(arr)
	copyto!(unsafe_jlview(tmpvar), arr)

	return tmpvar
end

function idlwrap(name::Symbol, arr::Array{T, N}) where {T<:JL_SCALAR, N}
	@boundscheck checkdims(arr)

	rooted_data__ = preserve_ref__(pointer(arr), arr.ref)

	var__ = IDL_ImportNamedArray(
		name, N, idldims(arr), idltype(T), rooted_data__, __JL_DROPREF[], C_NULL
	)

	return Variable(var__)
end

idlwrap(v::Variable, arr::Array{T, N}) where {T<:JL_SCALAR, N} = idlwrap(Symbol(name(v)), arr)

function idlarray(v::Variable, arr::Array{T, N}) where {T<:JL_SCALAR, N}

	tmpvar = idlsimilar(arr)
	idlcopyvar!(v, tmpvar)
	copyto!(unsafe_jlview(v), arr)

	return v
end

idlarray(name::Symbol, arr::Array{T, N}) where {T<:JL_SCALAR, N} = idlarray(idlvar(name, undef), arr)

#============================================================#
#
#	From IDL memory to Julia
#
#============================================================#


idlvar(name::Symbol, x::Array{T, N}) where {T<:JL_SCALAR, N} = idlarray(name, x)

# From IDL memory to Julia
unsafe_jlview(v::AbstractIDLVariable) = UnsafeView(v)
unsafe_jlview(name::Symbol) = unsafe_jlview(idlvar(name))

jlview(v::AbstractIDLVariable) = ArrayView(v)
jlview(name::Symbol) = jlview(idlvar(name))

jlarray(x::AbstractArrayView{T, N}) where {T, N} = copyto!(similar(x), x)
jlarray(v::AbstractIDLVariable) = jlarray(unsafe_jlview(v))
jlarray(name::Symbol) = jlarray(idlvar(name))



