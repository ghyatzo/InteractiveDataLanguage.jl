
## Hacky forward declaration of the IDLStruct structure
## So that we can use it for the Nested structure tag type
try struct IDLStruct{N, L, T, n}
	sref::IDL_SREF
	tags::NTuple{n, StructTag}
	ptr::Ptr{UInt8}
end catch; end


struct StructTag{T}
	value::T
	offset::UInt
end

StructTag(sref::IDL_SREF, _data, offset) = begin
	inner_s = IDLStruct(sref, _data + offset)
	StructTag{typeof(inner_s)}(inner_s, offset)
end

StructTag(idlarr::IDL_ARRAY, eltype::Type, _data, offset) = begin
	arr = IDLArray{eltype, Int(idlarr.n_dim)}(idlarr, _data + offset)
	StructTag{typeof(arr)}(arr, offset)
end


Base.eltype(::StructTag{T}) where T = T
value(t::StructTag) = t.value
offset(t::StructTag) = t.offset

gettag(s::StructTag{T}) where T = value(s)
gettag(s::StructTag{Ptr{T}}) where T <: JL_SCALAR = unsafe_load(value(s))
gettag(s::StructTag{IDL_STRING}) = convert(String, unsafe_load(value(s)))


_extract_tag_info(sref::IDL_SREF, i::Int) = begin
	_tagvar = Ref{Ptr{IDL_VARIABLE}}()
	offset = IDL_StructTagInfoByIndex(sref.sdef, i - 1, IDL_MSG_RET, _tagvar)
	if offset == -1
		throw(ArgumentError("The structure does not have an $i-th tag."))
	end

	return _tagvar[], offset
end


function _make_tag(sref::IDL_SREF, i::Int, _data)

	_tagvar, offset = _extract_tag_info(sref, i)
	tagvar_f, tagvar_t = varinfo(_tagvar)

	tagvar_t == IDL_TYP_STRUCT && begin
		innersref = unsafe_load(_tagvar.value.s)
		return StructTag(innersref, _data, offset)
	end

	T = jl_type(tagvar_t)

	(tagvar_f & IDL_V_ARR != 0) && begin
		arr = unsafe_load(unsafe_load(_tagvar.value.arr))
		return StructTag(arr, T, _data, offset)
	end

	return StructTag(Ptr{T}(_data + offset), offset % UInt)
end


struct IDLStruct{N, L, T, n}
	sref::IDL_SREF
	tags::NTuple{n, StructTag}
	ptr::Ptr{UInt8}
end

Base.propertynames(::IDLStruct{N, L, T, n}) where {N, L, T, n} = L
Base.nameof(::IDLStruct{N, L, T, n}) where {N, L, T, n} = N
ntags(::IDLStruct{N, L, T, n}) where {N, L, T, n} = n
tags(::IDLStruct{N, L, T, n}) where {N, L, T, n} = L
tagtypes(::IDLStruct{N, L, T, n}) where {N, L, T, n} = fieldtypes(T)
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
	n = IDL_StructNumTags(sref.sdef) % Int

	tags = ntuple(n) do i
		_tagname = IDL_StructTagNameByIndex(sref.sdef, i - 1, IDL_MSG_RET, C_NULL)
		tagname = unsafe_string(_tagname)
		Symbol(tagname)
	end

	values = ntuple(n) do i
		_make_tag(sref, i, _data)
	end

	_struct_name = Ref{Ptr{Cchar}}()
	IDL_StructTagNameByIndex(sref.sdef, C_NULL, IDL_MSG_RET, _struct_name)
	stname = unsafe_string(_struct_name[])

	if stname == "<Anonymous>"
		stname = "" # the <Anonymous> thing is hardcoded in IDL.
	end
	return IDLStruct{Symbol(stname), tags, typeof(values), n}(sref, values, _data)
end


_clone_tag(s::StructTag{A}, _newdataroot::Ptr) where {T, N, A <: IDLArray{T, N}} = begin
	arrdef = value(s).meta
	newarr = IDLArray{T, N}(arrdef, _newdataroot + offset(s))
	StructTag(newarr, offset(s))
end

_clone_tag(s::StructTag{Ptr{T}}, _newdataroot::Ptr) where T <: JL_SCALAR = begin
	StructTag(Ptr{T}(_newdataroot + offset(s)), offset(s))
end

_clone_tag(s::StructTag{T}, _newdataroot::Ptr) where T <: IDLStruct = begin
	sref = value(s).sref
	StructTag(sref, _newdataroot, offset)
end

function IDLStruct(
	s::IDLStruct{N, L, T, n}, _dataptr::Ptr{UInt8}
) where {N, L, T, n}

	values = ntuple(n) do i
		tag = s.tags[i]

		_clone_tag(tag, _dataptr)
	end

	return IDLStruct{N, L, T, n}(s.sref, values, _dataptr)
end



function IDLStruct{N, L, T, n}(values...) where {N, L, T, n}
	N isa Symbol ||
		throw(TypeError(:IDLStruct, Type{Symbol}, N))

	L isa Tuple{Vararg{Symbol}} ||
		throw(TypeError(:IDLStruct, Tuple{Vararg{Symbol}}, L))

	T <: Tuple ||
		throw(TypeError(:IDLStruct, Tuple{StructTag}, T))

	eltypes = fieldtypes(T)
	length(L) == length(values) == length(eltypes) == n ||
		throw(ArgumentError("Inconsistent length across parameters."))

	for (tag, type) in zip(values, eltypes)
		tag isa type || throw(TypeError(:IDLStruct, type, tag))
	end

	return IDLStruct{N, L, T, n}(values, C_NULL) #FIXME: How to include julia defined data?
end

IDLStruct{N, L}(values...) where {N, L} =
	IDLStruct{N, L, typeof(values), length(L)}(values, C_NULL)

IDLStruct{L, T}(values...) where {L, T <: Tuple} =
	IDLStruct{Symbol(""), L, T, length(L)}(values, C_NULL)

IDLStruct{L}(values...) where {L} =
	IDLStruct{Symbol(""), L, typeof(values), length(L)}(values, C_NULL)



function Base.getproperty(s::IDLStruct{N, L, T, n}, f::Symbol) where {N, L, T, n}
	f in fieldnames(IDLStruct) && return getfield(s, f)

	i = findfirst(==(f), L)
	isnothing(i) && throw(ErrorException("Struct has no tag '$f'"))

	return gettag(s.tags[i])
end

function Base.show(io::IO, s::IDLStruct{N, L, T, n}) where {N, L, T, n}

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
