swaprowcol(dims, n) = begin
	nc, nr, r... = dims
	(nr, nc, r...)[1:n]
end

dimsperm(n) = ntuple(n) do i
	n == 1 && return 1
	i == 1 && return 2
	i == 2 && return 1
	return i
end # (1,) or (2,1,3,4...). IDL swaps only the first two dimensions

struct IDLArray{T, N} <: AbstractArray{T, N}
	meta::IDL_ARRAY
	dataoverride::Ptr{Cuchar}
end

function IDLArray{T}(arr::IDL_ARRAY, inheriteddata = C_NULL) where T
	return IDLArray{T, Int(arr.n_dim)}(arr, inheriteddata)
end

_dataptr(X::IDLArray{T, N}) where {T, N} =
	X.dataoverride == C_NULL ? Ptr{T}(X.meta.data) : Ptr{T}(X.dataoverride)

Base.IndexStyle(::IDLArray) = IndexLinear()
Base.size(X::IDLArray{T, N}) where {T, N} = X.meta.dim[1:N]
Base.eltype(::IDLArray{T, N}) where {T, N} = T
Base.length(x::IDLArray) = x.meta.n_elts


Base.getindex(X::IDLArray, i) = unsafe_load(_dataptr(X), i)
Base.getindex(X::IDLArray{IDL_STRING}, i::Integer) = IDL_STRING_STR(unsafe_load(_dataptr(X), i))


Base.setindex!(X::IDLArray, v, i) = unsafe_store!(_dataptr(X), v, i)
Base.setindex!(X::IDLArray{IDL_STRING}, s::AbstractString, i::Integer) =
	IDL_StrStore(_dataptr(X) + (sizeof(IDL_STRING) * (Int(i) - 1)), s)
