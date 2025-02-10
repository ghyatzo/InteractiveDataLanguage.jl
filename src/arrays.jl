ndims(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.n_dim) % Int
Base.size(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.dim)[1:ndims(_a)]
Base.elsize(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.elt_len)
Base.length(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.n_elts)
data(_a::Ptr{IDL_ARRAY}) = unsafe_load(_a.data)
_store_cb!(_a::Ptr{IDL_ARRAY}, cb::Base.CFunction) =
	unsafe_store!(_a.free_cb, Base.unsafe_convert(Ptr{Cvoid}, cb))

mutable struct IDLArray
	parent::IDLVariable
	valid::Bool # make atomic in the future
	offset::UInt
	_cb::Base.CFunction

	function IDLArray(v::IDLVariable, offset = zero(UInt8))
		isarray(v) || throw(ArgumentError("The variable must point to an IDL Array."))

		x = new(v, true, offset)

		x._cb = @cfunction($((_p::Ptr{Cuchar}) -> begin

			if !isvalid(x.parent)
				x.valid = false
			end

			# is array but not a struct.
			if !issimplearray(x.parent)
				x.valid = false
			end

			if x.valid
				_store_cb!(array(x.parent), x._cb)
			end

			return nothing
		end), Nothing, (Ptr{Cuchar},))

		_store_cb!(array(x.parent), x._cb)
	end
end
deconstruct(x::IDLArray) = x.parent
array(x::IDLArray) = array(x.parent)
isvalid(x::IDLArray) = x.valid

Base.IndexStyle(::IDLArray) = IndexLinear()
Base.eltype(x::IDLArray) = jltype(_type(x.parent))
Base.size(x::IDLArray) = size(array(x))
Base.length(x::IDLArray) = length(array(x))

data(x::IDLArray) = begin
	isvalid(x) ||
		throw(InvalidStateException("""The variable no longer points to an array.
			To keep using this variable extract the underlaying variable by calling
			the `deconstruct` method.""", :IDLArray))
	Ptr{eltype(x)}(data(array(x)) + x.offset)
end

setcallback!(x::IDLArray, cb) = begin
	newcb = @cfunction($cb, Nothing, (Ptr{Cuchar},))
	x._cb = newcb
	_store_cb!(array(x.parent), x._cb)
end

Base.isassigned(x::IDLArray, ::Integer) = isvalid(x)
Base.isassigned(x::IDLArray, ::Vararg{Integer}) = isvalid(x)

Base.getindex(x::IDLArray, i::Integer) = begin
	@boundscheck checkbounds(x, i)
	idlconvert(unsafe_load(data(x), i))
end


Base.setindex!(x::IDLArray, v::T, i) where T <: JL_SCALAR = begin
	@boundscheck checkbounds(x, i)
	T == eltype(x) ||
		throw(ArgumentError("Attempting to add an element of type $T to an array of $(eltype(x))s"))

	unsafe_store!(data(x), v, i)
end

Base.setindex!(x::IDLArray, v::AbstractString, i) = begin
	@boundscheck checkbounds(x, i)

	eltype(x) == String ||
		throw(ArgumentError("Attempting to add an element of type String to an array of $(eltype(x))s"))

	IDL_StrStore(data(x) + (sizeof(IDL_STRING) * (Int(i) - 1)), v)
end



# mutable struct IDLArray{T, N} <: AbstractArray{T, N}
# 	_arr::Ptr{IDL_ARRAY}
# 	dataoverride::Ptr{Cuchar}
# 	_customcb::Base.CFunction

# 	function IDLArray(v::IDLVariable, inheriteddata = C_NULL)
# 		isarray(v) || throw(ArgumentError("The variable must point to an IDL Array."))

# 		_arr = unsafe_load(v._v.value.arr)
# 		N = unsafe_load(_arr.n_dim) % Int
# 		T = eltype(v)

# 		x = new{T, N}(_arr, inheriteddata)

# 		# The default callback invalidates the IDLArray
# 		x._customcb = @cfunction($((_p::Ptr{Cuchar}) -> begin
# 			setfield!(x, :_arr, Ptr{IDL_ARRAY}(C_NULL))
# 			nothing
# 		end), Nothing, (Ptr{Cuchar},))

# 		unsafe_store!(_arr.free_cb, Base.unsafe_convert(Ptr{Cvoid}, x._customcb))

# 		return x
# 	end
# end



# _dataptr(x::IDLArray{T, N}) where {T, N} = begin
# 	x.dataoverride == C_NULL ? Ptr{T}(unsafe_load(x._arr.data)) : Ptr{T}(x.dataoverride)
# end





