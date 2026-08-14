#============================================================#
#
#	IDL Structures
#
#	In IDL a structure is always an array of structures
#	(IDL_V_STRUCT implies IDL_V_ARR). The data is laid out AoS:
#	every element repeats the same tag layout with a stride of
#	`elt_len`. Tag offsets and types come from the structure
#	definition (sdef) through the documented C API.
#
#============================================================#

# rooted forever because IDL_MakeStruct may not copy tag names/dims.
# Drop this if it's ever verified that IDL copies them.
const STRUCT_DEF_ROOTS = Any[]

#------------------------------------------------------------
#
#	Introspection of structure definitions
#
#------------------------------------------------------------

structdef(v::AbstractIDLVariable) = sdef(v).sdef

function tag_info(sdef_::IDL_StructDefPtr, i::Int)
	tagvar = Ref{Ptr{IDL_VARIABLE}}()
	offset = IDL_StructTagInfoByIndex(sdef_, Cint(i - 1), IDL_MSG_RET, tagvar)
	offset == -1 && throw(ArgumentError("The structure does not have a tag number $i."))

	# The returned variable describes type and shape of the tag but
	# holds no valid data. Data is always read at `base + offset`.
	return Variable(tagvar[]), Int(offset)
end

ntags(sdef_::IDL_StructDefPtr) = IDL_StructNumTags(sdef_) % Int

function tag_names(sdef_::IDL_StructDefPtr)
	ntuple(ntags(sdef_)) do i
		Symbol(unsafe_string(IDL_StructTagNameByIndex(sdef_, Cint(i - 1), IDL_MSG_RET, C_NULL)))
	end
end

function struct_name(sdef_::IDL_StructDefPtr)
	_sname = Ref{Ptr{Cchar}}()
	IDL_StructTagNameByIndex(sdef_, Cint(0), IDL_MSG_RET, _sname)
	return unsafe_string(_sname[])
end

function findtag(sdef_::IDL_StructDefPtr, f::Symbol)
	# IDL tag names are always uppercase
	f = Symbol(uppercase(string(f)))
	i = findfirst(==(f), tag_names(sdef_))
	isnothing(i) && throw(ErrorException("Struct has no tag '$f'"))
	return i
end

#------------------------------------------------------------
#
#	Single structure view (IDL -> Julia)
#
#------------------------------------------------------------

struct StructView
	sdef_::IDL_StructDefPtr
	base::Ptr{UCHAR} # address of the data of this element
	ref              # keeps the data owner alive
end

ntags(s::StructView) = ntags(s.sdef_)
tags(s::StructView) = tag_names(s.sdef_)

function Base.nameof(s::StructView)
	n = struct_name(s.sdef_)
	return n == "<Anonymous>" ? Symbol() : Symbol(n)
end

Base.propertynames(s::StructView) = tags(s)

function Base.getproperty(s::StructView, f::Symbol)
	f in (:sdef_, :base, :ref) && return getfield(s, f)
	return tag_get(s, findtag(s.sdef_, f))
end

function Base.setproperty!(s::StructView, f::Symbol, val)
	f in (:sdef_, :base, :ref) && return setfield!(s, f, val)
	return tag_set!(s, findtag(s.sdef_, f), val)
end

function tag_get(s::StructView, i::Int)
	proto, offset = tag_info(s.sdef_, i)
	addr = s.base + offset

	# tags that are ARRAYS of nested structs resolve to
	# their first element only. Add a StructArrayView over explicit
	# (sdef, data) if it becomes necessary.
	isstruct(proto) && return StructView(structdef(proto), addr, s)

	isarray(proto) && return TagArrayView(proto, addr)

	eltype(proto) === String && return convert(String, unsafe_load(Ptr{IDL_STRING}(addr)))

	return unsafe_load(Ptr{eltype(proto)}(addr))
end

function tag_set!(s::StructView, i::Int, val)
	proto, offset = tag_info(s.sdef_, i)
	addr = s.base + offset

	if isstruct(proto)
		val isa NamedTuple || throw(ArgumentError("A struct tag can only be set with a NamedTuple."))
		nested = StructView(structdef(proto), addr, s)
		for (k, v_) in pairs(val)
			setproperty!(nested, k, v_)
		end
	elseif isarray(proto)
		copyto!(TagArrayView(proto, addr), val)
	elseif eltype(proto) === String
		str_store!(addr, val)
	else
		unsafe_store!(Ptr{eltype(proto)}(addr), convert(eltype(proto), val))
	end

	return s
end

function str_store!(addr::Ptr{UCHAR}, str::AbstractString)
	p = Ptr{IDL_STRING}(addr)
	# IDL_StrStore assumes an empty descriptor, free the old string first.
	unsafe_load(p).slen > 0 && IDL_StrDelete(p, 1)
	IDL_StrStore(p, str)
end

function Base.show(io::IO, s::StructView)
	nm = nameof(s)
	print(io, nm == Symbol() ? "IDLStruct{" : "$nm{")
	join(io, (string(t, ": ", Base.getproperty(s, t)) for t in tags(s)), ", ")
	print(io, "}")
end

#------------------------------------------------------------
#
#	Array tag view: sizes from the tag prototype variable,
#	data pointer given explicitly.
#
#------------------------------------------------------------

struct TagArrayView{T, N} <: AbstractArrayView{T, N}
	v::Variable
	ptr::Ptr{UCHAR}

	function TagArrayView(v::Variable, ptr::Ptr{UCHAR})
		N = arr_ndims(array__(v))
		return new{eltype(v), N}(v, ptr)
	end
end

array__(x::TagArrayView) 					= vararray__(varptr__(x.v))
data__(x::TagArrayView{T}) where {T} 		= Ptr{T}(x.ptr)
data__(x::TagArrayView{<:AbstractString}) 	= Ptr{IDL_STRING}(x.ptr)

function Base.setindex!(x::TagArrayView{<:AbstractString}, v::AbstractString, i)
	@boundscheck checkbounds(x, i)
	str_store!(x.ptr + sizeof(IDL_STRING) * (Int(i) - 1), v)
end

#------------------------------------------------------------
#
#	Array of structures view
#
#------------------------------------------------------------

struct StructArrayView{N} <: AbstractArray{StructView, N}
	v::Variable
end

Base.IndexStyle(::StructArrayView) = IndexLinear()

function Base.size(x::StructArrayView{N}) where N
	arr_ = unsafe_load(sdef(x.v).arr)
	return ntuple(i -> Int(arr_.dim[i]), Val(N))
end

Base.length(x::StructArrayView) = Int(unsafe_load(sdef(x.v).arr).n_elts)

function Base.getindex(x::StructArrayView, i::Int)
	@boundscheck checkbounds(x, i)
	sref_ = sdef(x.v)
	arr_ = unsafe_load(sref_.arr)
	return StructView(sref_.sdef, arr_.data + (i - 1) * arr_.elt_len, x.v)
end

#============================================================#
#
#	GET API
#
#============================================================#

# In IDL there is no real distinction between a struct and an
# array of structs with one element, so n_elts == 1 always
# resolves to a plain StructView.
function jlstruct(v::AbstractIDLVariable)
	sref_ = sdef(v)
	arr_ = unsafe_load(sref_.arr)

	Int(arr_.n_elts) == 1 && return StructView(sref_.sdef, arr_.data, v)
	return StructArrayView{Int(arr_.n_dim)}(v)
end
jlstruct(name::Symbol) = jlstruct(idlvar(name))

#============================================================#
#
#	Julia -> IDL
#
#	Build the definition with IDL_MakeStruct, let IDL allocate
#	the memory (IDL_MakeTempStruct), then fill the tags with the
#	same machinery used to write into existing structs. This
#	avoids guessing IDL's AoS layout from the Julia side.
#
#============================================================#

_tagdefptr(name::AbstractString) = Base.unsafe_convert(Ptr{Cchar}, name)

_tagdef(name::AbstractString, ::T) where {T <: JL_SCALAR} =
	IDL_STRUCT_TAG_DEF(_tagdefptr(name), Ptr{IDL_LONG64}(C_NULL), Ptr{Cvoid}(Int(idltype(T))), 0x00)

_tagdef(name::AbstractString, ::AbstractString) =
	IDL_STRUCT_TAG_DEF(_tagdefptr(name), Ptr{IDL_LONG64}(C_NULL), Ptr{Cvoid}(Int(T_STRING)), 0x00)

function _tagdef(name::AbstractString, value::AbstractArray{T, N}) where {T <: Union{JL_SCALAR, AbstractString}, N}
	N > IDL_MAX_ARRAY_DIM && throw(ArgumentError("IDL arrays can have at most $IDL_MAX_ARRAY_DIM dimensions."))
	dims = IDL_MEMINT[N, size(value)...]
	push!(STRUCT_DEF_ROOTS, dims)
	return IDL_STRUCT_TAG_DEF(_tagdefptr(name), pointer(dims), Ptr{Cvoid}(Int(idltype(T))), 0x00)
end

function _tagdef(name::AbstractString, value::NamedTuple)
	innersdef = IDL_MakeStruct(C_NULL, tagdefs(value))
	return IDL_STRUCT_TAG_DEF(_tagdefptr(name), Ptr{IDL_LONG64}(C_NULL), Ptr{Cvoid}(innersdef), 0x00)
end

function _tagdef(name::AbstractString, value::NTuple{N, T}) where {N, T <: JL_SCALAR}
	dims = IDL_MEMINT[1, N]
	push!(STRUCT_DEF_ROOTS, dims)
	return IDL_STRUCT_TAG_DEF(_tagdefptr(name), pointer(dims), Ptr{Cvoid}(Int(idltype(T))), 0x00)
end

function _tagdef(name::AbstractString, value::AbstractArray{<:NamedTuple, N}) where N
	N > IDL_MAX_ARRAY_DIM && throw(ArgumentError("IDL arrays can have at most $IDL_MAX_ARRAY_DIM dimensions."))
	innersdef = IDL_MakeStruct(C_NULL, tagdefs(first(value)))
	dims = IDL_MEMINT[N, size(value)...]
	push!(STRUCT_DEF_ROOTS, dims)
	return IDL_STRUCT_TAG_DEF(_tagdefptr(name), pointer(dims), Ptr{Cvoid}(innersdef), 0x00)
end

_tagdef(name::AbstractString, value) = throw(ArgumentError("""
	Unsupported type `$(typeof(value))` for the tag `$name`.
	Struct tags can only hold scalars, strings, arrays of those,
	NamedTuples (nested structs) and arrays of NamedTuples.
"""))

function tagdefs(nt::NamedTuple)
	# IDL tag names are always uppercase
	names = uppercase.(string.(keys(nt)))

	defs = map(names, nt) do name, value
		push!(STRUCT_DEF_ROOTS, name)
		_tagdef(name, value)
	end

	# the tag array must be null terminated
	push!(defs, IDL_STRUCT_TAG_DEF(Ptr{Cchar}(C_NULL), Ptr{IDL_LONG64}(C_NULL), C_NULL, 0x00))
	push!(STRUCT_DEF_ROOTS, defs)
	return defs
end

function maketemp(ntarr::AbstractArray{<:NamedTuple, N}, structname::Symbol=Symbol()) where N
	sname = if structname == Symbol()
		C_NULL
	else
		# IDL structure names are always uppercase
		n = uppercase(string(structname))
		push!(STRUCT_DEF_ROOTS, n)
		_tagdefptr(n)
	end

	sdef_ = IDL_MakeStruct(sname, tagdefs(first(ntarr)))

	tmpvar__ = Ref{Ptr{IDL_VARIABLE}}()
	err = IDL_MakeTempStruct(sdef_, N, idldims(ntarr), tmpvar__, IDL_TRUE)
	if tmpvar__[] == C_NULL
		errmsg = err == C_NULL ? "" : unsafe_string(err)
		error("IDL_MakeTempStruct failed" * (isempty(errmsg) ? "" : ": $errmsg"))
	end

	tv = TemporaryVariable(tmpvar__[])

	arr_ = unsafe_load(sdef(tv).arr)
	for (i, nt) in enumerate(ntarr)
		sv = StructView(sdef_, arr_.data + (i - 1) * arr_.elt_len, tv)
		for (k, v_) in pairs(nt)
			setproperty!(sv, k, v_)
		end
	end

	return tv
end
maketemp(nt::NamedTuple, structname::Symbol=Symbol()) = maketemp([nt], structname)

function idlstruct(
	name::Symbol,
	nt::Union{NamedTuple, AbstractArray{<:NamedTuple}},
	structname::Symbol=Symbol(),
)
	return idlvar(name, maketemp(nt, structname))
end

# Instantiate an existing named structure definition with zeroed tags,
# like `s = {SOMETYPE}` on the IDL side.
function idlstruct(name::Symbol; type::Symbol)
	idlrun("$(name) = {$(type)}")
	return idlvar(name)
end

Base.setproperty!(::IDLMain, x::Symbol, v::NamedTuple) = idlstruct(x, v)
