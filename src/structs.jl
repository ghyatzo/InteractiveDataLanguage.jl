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

struct IDLStruct{name, tagnames, types} <: GenericIDLStruct
	sref::IDL_SREF
	tags::Tuple{Vararg{StructTag}}
	ptr::Ptr{UInt8}
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
	s::IDLStruct{name, tags, types},
	dataptr::Ptr{UInt8}
) where {name, tags, types}

	tagtypes = fieldtypes(types)
	values = ntuple(length(tags)) do i
		type = tagtypes[i]
		tag = s.tags[i]
		type isa ScalarTag &&
			return ScalarTag{eltype(tag)}(dataptr, offset(tag))

		type isa ArrayTag &&
			return ArrayTag{eltype(tag)}(value(tag).meta, dataptr, offset(tag))

		type isa NestedStructTag &&
			NestedStructTag(value(tag).sref, dataptr, offset(tag))
	end

	return IDLStruct{name, tags, types}(s.sref, values, dataptr)
end

function IDLStruct{name, tags, types}(values...) where {name, tags, types}
	name isa Symbol ||
		throw(TypeError(:IDLStruct, Type{Symbol}, name))

	tags isa Tuple{Vararg{Symbol}} ||
		throw(TypeError(:IDLStruct, Tuple{Vararg{Symbol}}, tags))

	types <: Tuple ||
		throw(TypeError(:IDLStruct, Tuple{StructTag}, types))

	length(tags) == length(values) ||
		throw(ArgumentError("Tag names and values must have the same length."))

	eltypes = fieldtypes(types)
	length(eltypes) == length(values) ||
		throw(ArgumentError("Tag types and values must have the same length."))

	for (tag, type) in zip(values, eltypes)
		tag isa type || throw(TypeError(:IDLStruct, type, tag))
	end

	return IDLStruct{name, tags, types}(values, C_NULL) #todo...
end

IDLStruct{name, tags}(values...) where {name, tags} =
	IDLStruct{name, tags, typeof(values)}(values, C_NULL)

IDLStruct{tags, types}(values...) where {tags, types <: Tuple} =
	IDLStruct{Symbol(""), tags, types}(values, C_NULL)

IDLStruct{tags}(values...) where {tags} =
	IDLStruct{Symbol(""), tags, typeof(values)}(values, C_NULL)

Base.propertynames(::IDLStruct{name, tags, types}) where {name, tags, types} = tags
Base.nameof(::IDLStruct{name, tags, types}) where {name, tags, types} = name
ntags(::IDLStruct{name, tags, types}) where {name, tags, types} = length(tags)

function Base.getproperty(s::IDLStruct{name, tags, types}, f::Symbol) where {name, tags, types}
	f in fieldnames(IDLStruct) && return getfield(s, f)

	i = findfirst(==(f), tags)
	isnothing(i) && throw(ErrorException("Struct has no tag '$f'"))

	return gettag(s.tags[i])
end

function Base.show(io::IO, s::IDLStruct{name, tags, types}) where {name, tags, types}
	if name == Symbol()
		print(io, "IDLStruct{")
		tag1, rtags... = tags
		val1, rvalues... = s.tags
		print(io, "$tag1:$val1")
		for (tag, value) in zip(rtags, rvalues)
			print(io, ", $tag:$value")
		end
	else
		print(io, "IDLStruct{$name")
		for (tag, value) in zip(tags, s.tags)
			print(io, ", $tag:$value")
		end
	end

	return print(io, "}")
end

Base.show(io::IO, t::StructTag) = print(io, gettag(t))

# Display() used by the repl, uses show with a ::MIME"text/plain"
# Base.show(io::IO, ::MIME"text/plain", x)
