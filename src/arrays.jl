
dimsperm(n) = ntuple(n) do i
	n == 1 && return 1
	i == 1 && return 2
	i == 2 && return 1
	return i
end # (1,) or (2,1,3,4...). IDL swaps only the first two dimensions


mutable struct IDLArray{T, N} <: AbstractArray{T, N}
	_arr::Ptr{IDL_ARRAY}
	dataoverride::Ptr{Cuchar}
	_customcb::Base.CFunction

	function IDLArray(v::IDLVariable, inheriteddata = C_NULL)
		isarray(v) || throw(ArgumentError("The variable must point to an IDL Array."))

		_arr = unsafe_load(v._v.value.arr)
		N = unsafe_load(_arr.n_dim) % Int
		T = eltype(v)

		x = new{T, N}(_arr, inheriteddata)

		# The default callback invalidates the IDLArray
		x._customcb = @cfunction($((_p::Ptr{Cuchar}) -> begin
			setfield!(x, :_arr, Ptr{IDL_ARRAY}(C_NULL))
			nothing
		end), Nothing, (Ptr{Cuchar},))

		unsafe_store!(_arr.free_cb, Base.unsafe_convert(Ptr{Cvoid}, x._customcb))

		return x
	end
end
isvalidref(X::IDLArray) = getfield(X, :_arr) != C_NULL
Base.getproperty(X::IDLArray, f::Symbol) = begin
	f == :_arr && return isvalidref(X) ? getfield(X, :_arr) : throw(UndefRefError())
	getfield(X, f)
end

Base.isassigned(X::IDLArray, ::Integer) = isvalidref(X)
Base.isassigned(X::IDLArray, ::Vararg{Integer}) = isvalidref(X)

_dataptr(X::IDLArray{T, N}) where {T, N} = begin
	X.dataoverride == C_NULL ? Ptr{T}(unsafe_load(X._arr.data)) : Ptr{T}(X.dataoverride)
end

_rowcolperm(I::NTuple{N, Int}) where {N} = ntuple(N) do j
	N == 1 && return I[1]
	j == 1 && return I[2]
	j == 2 && return I[1]
	return I[j]
end

setcallback!(X::IDLArray, cb) = begin
	newcb = @cfunction($cb, Nothing, (Ptr{Cuchar},))
	X._customcb = newcb
	unsafe_store!(X._arr.free_cb, Base.unsafe_convert(Ptr{Cvoid}, X._customcb))
end
Base.IndexStyle(::IDLArray) = IndexLinear()
Base.size(X::IDLArray{T, N}) where {T, N} = unsafe_load(X._arr.dim)[1:N]
Base.eltype(::IDLArray{T, N}) where {T, N} = T
Base.length(X::IDLArray) = unsafe_load(X._arr.n_elts)


Base.getindex(X::IDLArray{T, N}, i::Integer) where {T, N} = begin
	@boundscheck checkbounds(X, i)
	__inbound_getindex(X, i)
end
__inbound_getindex(X::IDLArray, i) = unsafe_load(_dataptr(X), i)
__inbound_getindex(X::IDLArray{IDL_STRING}, i::Integer) = IDL_STRING_STR(unsafe_load(_dataptr(X), i))


Base.setindex!(X::IDLArray, v, i) = begin
	@boundscheck checkbounds(X, i)
	__inbound_setindex!(X, v, i)
end
__inbound_setindex!(X::IDLArray, v, i) = unsafe_store!(_dataptr(X), v, i)
__inbound_setindex!(X::IDLArray{IDL_STRING}, s::AbstractString, i::Integer) =
	IDL_StrStore(_dataptr(X) + (sizeof(IDL_STRING) * (Int(i) - 1)), s)


