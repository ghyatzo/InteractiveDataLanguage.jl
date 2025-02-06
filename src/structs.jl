abstract type GenericIDLStruct end
abstract type StructTag{T} end

Base.eltype(::StructTag{T}) where {T} = T
offset(s::StructTag) = s.offset

struct NestedStructTag{T <: GenericIDLStruct} <: StructTag{T}
	s::T
	offset::UInt8
end
NestedStructTag(sref, dataptr, offset) = begin
	inner_s = IDLStruct(sref, dataptr + offset)
	return NestedStructTag{typeof(inner_s)}(inner_s, offset)
end
value(t::NestedStructTag) = t.s
gettag(t::NestedStructTag) = value(t)




struct ArrayTag{T, N} <: StructTag{T}
	arr::IDLArray{T, N}
	offset::UInt8
end
ArrayTag{T}(arr::IDL_ARRAY, dataroot, offset) where {T} = begin
	N = arr.n_dim % Int
	return ArrayTag{T, N}(IDLArray{T, N}(arr, dataroot + offset), offset)
end
value(t::ArrayTag) = t.arr
gettag(t::ArrayTag) = value(t)




struct ScalarTag{T} <: StructTag{T}
	ptr::Ptr{T}
	offset::UInt8
	ScalarTag{T}(dataptr, offset) where T = new{T}(dataptr + offset, offset)
end
value(t::ScalarTag) = t.ptr
gettag(t::ScalarTag) = unsafe_load(value(t))
gettag(t::ScalarTag{IDL_STRING}) = convert(String, value(t))


tagoffset(t::StructTag) = t.offset



_extract_tag_info(sref::IDL_SREF, i::Int) = begin
	_tagvar = Ref{Ptr{IDL_VARIABLE}}()
	offset = IDL_StructTagInfoByIndex(sref.sdef, i - 1, IDL_MSG_RET, _tagvar)
	if offset == -1
		throw(ArgumentError("The structure does not have an $i-th tag."))
	end

	return _tagvar[], offset
end


function (::Type{StructTag})(sref::IDL_SREF, i::Int, _data)

	_tagvar, offset = _extract_tag_info(sref, i)
	tagvar_f, tagvar_t = varinfo(_tagvar)

	tagvar_t == IDL_TYP_STRUCT && begin
		innersref = unsafe_load(_tagvar.value.s)
		return NestedStructTag(innersref, _data, offset)
	end

	T = jl_type(tagvar_t)

	(tagvar_f & IDL_V_ARR != 0) && begin
		arr = unsafe_load(unsafe_load(_tagvar.value.arr))
		return ArrayTag{T}(arr, _data, offset)
	end

	return ScalarTag{T}(_data, offset)
end



struct IDLStruct{N, L, T} <: GenericIDLStruct
	sref::IDL_SREF
	tags::Tuple{Vararg{StructTag}}
	ptr::Ptr{UInt8}
end

Base.propertynames(::IDLStruct{N, L, T}) where {N, L, T} = L
Base.nameof(::IDLStruct{N, L, T}) where {N, L, T} = N
ntags(::IDLStruct{N, L, T}) where {N, L, T} = length(L)
tags(::IDLStruct{N, L, T}) where {N, L, T} = L
tagtypes(::IDLStruct{N, L, T}) where {N, L, T} = fieldtypes(T)
tagtype(s::IDLStruct, i::Integer) = tagtypes(s)[i]
tagtype(s::IDLStruct, t::Symbol) = begin
	i = findfirst(==(t), tags(s))
	isnothing(i) && throw(ErrorException("Struct has no tag '$t'"))

	tagtype(s, i)
end

function IDLStruct(sref::IDL_SREF, inherited_data = C_NULL)
	_data = inherited_data == C_NULL ?
		unsafe_load(sref.arr.data) : Ptr{UInt8}(inherited_data)

	# The call returns an Int32, which somehow breaks ntuple
	# We hardcast to an Int...
	N = IDL_StructNumTags(sref.sdef) % Int

	tags = ntuple(N) do i
		_tagname = IDL_StructTagNameByIndex(sref.sdef, i - 1, IDL_MSG_RET, C_NULL)
		tagname = unsafe_string(_tagname)
		Symbol(tagname)
	end

	values = ntuple(N) do i
		StructTag(sref, i, _data)
	end

	_struct_name = Ref{Ptr{Cchar}}()
	IDL_StructTagNameByIndex(sref.sdef, C_NULL, IDL_MSG_RET, _struct_name)
	stname = unsafe_string(_struct_name[])

	if stname == "<Anonymous>"
		stname = "" # the <Anonymous> thing is hardcoded in IDL.
	end
	return IDLStruct{Symbol(stname), tags, typeof(values)}(sref, values, _data)
end



function IDLStruct(
	s::IDLStruct{N, L, T}, dataptr::Ptr{UInt8}
) where {N, L, T}

	tagtypes = fieldtypes(T)
	values = ntuple(length(L)) do i
		type = tagtypes[i]
		tag = s.tags[i]

		type isa ScalarTag &&
			return ScalarTag{eltype(tag)}(dataptr, offset(tag))

		type isa ArrayTag &&
			return ArrayTag{eltype(tag)}(value(tag).meta, dataptr, offset(tag))

		type isa NestedStructTag &&
			NestedStructTag(value(tag).sref, dataptr, offset(tag))
	end

	return IDLStruct{N, L, T}(s.sref, values, dataptr)
end



function IDLStruct{N, L, T}(values...) where {N, L, T}
	N isa Symbol ||
		throw(TypeError(:IDLStruct, Type{Symbol}, N))

	L isa Tuple{Vararg{Symbol}} ||
		throw(TypeError(:IDLStruct, Tuple{Vararg{Symbol}}, L))

	T <: Tuple ||
		throw(TypeError(:IDLStruct, Tuple{StructTag}, T))

	length(L) == length(values) ||
		throw(ArgumentError("Tag names and values must have the same length."))

	eltypes = fieldtypes(T)
	length(eltypes) == length(values) ||
		throw(ArgumentError("Tag types and values must have the same length."))

	for (tag, type) in zip(values, eltypes)
		tag isa type || throw(TypeError(:IDLStruct, type, tag))
	end

	return IDLStruct{N, L, T}(values, C_NULL) #FIXME: How to include julia defined data?
end

IDLStruct{N, L}(values...) where {N, L} =
	IDLStruct{N, L, typeof(values)}(values, C_NULL)

IDLStruct{L, T}(values...) where {L, T <: Tuple} =
	IDLStruct{Symbol(""), L, T}(values, C_NULL)

IDLStruct{L}(values...) where {L} =
	IDLStruct{Symbol(""), L, typeof(values)}(values, C_NULL)



function Base.getproperty(s::IDLStruct{N, L, T}, f::Symbol) where {N, L, T}
	f in fieldnames(IDLStruct) && return getfield(s, f)

	i = findfirst(==(f), L)
	isnothing(i) && throw(ErrorException("Struct has no tag '$f'"))

	return gettag(s.tags[i])
end

function Base.show(io::IO, s::IDLStruct{N, L, T}) where {N, L, T}
	if N == Symbol()
		print(io, "IDLStruct{")
		tag1, rtags... = L
		val1, rvalues... = s.tags
		print(io, "$tag1:$val1")
		for (tag, value) in zip(rtags, rvalues)
			print(io, ", $tag:$value")
		end
	else
		print(io, "IDLStruct{$name")
		for (tag, value) in zip(L, s.tags)
			print(io, ", $tag:$value")
		end
	end

	return print(io, "}")
end

Base.show(io::IO, t::StructTag) = print(io, gettag(t))

# Display() used by the repl, uses show with a ::MIME"text/plain"
# Base.show(io::IO, ::MIME"text/plain", x)
