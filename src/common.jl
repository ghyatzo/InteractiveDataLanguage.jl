# struct IDLError
# 	msg::String
# 	sysmsg::String
# 	code::Int
# end

# function extractError()
# 	err_msg = IDL_STRING_STR(IDL_SysvErrStringFunc())
# 	syserr_msg = IDL_STRING_STR(IDL_SysvSyserrStringFunc())
# 	code = IDL_SysvErrCodeValue() # SysvErrorCodeValue()?

# 	return IDLError(err_msg, syserr_msg, code)
# end



###=== IDL -> JULIA ===###

function get_var end

function get_var(name::AbstractString)
	_var = IDL_GetVarAddr(name)
	if _var == C_NULL
		throw(UndefVarError("No variable named '$name' in the current IDL scope."))
	end
	get_var(_var)
end

function get_var(_var::Ptr{IDL_VARIABLE})
	var_f, var_t = varinfo(_var)

	if (var_f & IDL_V_NULL) != 0
		return nothing
	end

	if (var_f & IDL_V_FILE) != 0
		error("File Variables not yet implemented")
	end

	if (var_f & IDL_V_STRUCT) != 0
		# IDL Structures are really only Arrays of structures with only one element.
		# IDL_V_STRUCT implies IDL_V_ARR so it must be before
		# to distinguish between struct_array and array only.
		return _get_idl_struct_array(_var)
	end

	if (var_f & IDL_V_ARR) != 0
		_arr = unsafe_load(_var.value.arr)
		var_t = unsafe_load(_var.type)
		array = IDLArray(_arr, var_t)
		return PermutedDimsArray(array, dimsperm(ndims(array)))
	end

	return get_scalarvar(_var)
end



struct StructTag
	name::String
	offset::IDL_MEMINT
	eltype::IDL_MEMINT
	arrinfo::Union{Nothing, IDL_ARRAY}
	structinfo::Union{Nothing, IDL_SREF}

	StructTag(sref::IDL_SREF, i::Integer) = begin
		@assert i > 0 "the index i is 1 based."

		__tagvar = Ref{Ptr{IDL_VARIABLE}}()
		offset = IDL_StructTagInfoByIndex(sref.sdef, i-1, IDL_MSG_RET, __tagvar)
		if offset == -1
			throw(ArgumentError("The structure does not have an $i-th tag."))
		end

		tname = tagname(sref, i)
		tagvar = unsafe_load(__tagvar[])
		tageltype = tagvar.type

		tag_array_info = nothing
		if tagvar.flags & IDL_V_ARR != 0
			tag_arr = unsafe_load(tagvar.value.arr)
			tag_array_info = tag_arr
		end

		if tageltype == IDL_TYP_STRUCT
			tag_struct_info = tagvar.value.s
		end

		new(tname, offset, tageltype, tag_array_info, tag_struct_info)
	end
end


isarray(tag::StructTag) = !isnothing(tag.arrinfo)
isstruct(tag::StructTag) = !isnothing(tag.structinfo)
isscalar(tag::StructTag) = !isarray(tag) && !isstruct(tag)
Base.eltype(tag::StructTag) = jl_type(tag.eltype)

name(sref::IDL_SREF) = begin
	__struct_name = Ref{Ptr{Cchar}}()
	IDL_StructTagNameByIndex(sref.sdef, C_NULL, IDL_MSG_RET,  __struct_name)
	return unsafe_string(__struct_name[])
end

ntags(sref::IDL_SREF) = IDL_StructNumTags(sref.sdef)
tagname(sref::IDL_SREF, i::Integer) = IDL_StructTagNameByIndex(sref.sdef, i-1, 0, C_NULL) |> unsafe_string
tagnames(sref::IDL_SREF) = ntuple(i -> Symbol(tagname(sref, i)), ntags(sref))


struct IDLStruct
	name::String
	tags::Vector{StructTag}
	sdef::IDL_SREF
	data::Ptr{Cuchar}

	function IDLStruct(sref::IDL_SREF, data::Ptr{Cuchar})
	end
end

function _get_idl_struct(sref::IDL_SREF, _parentdata = C_NULL)

	struct_name = name(sref)
	if struct_name != "<Anonymous>" # this string is hardcoded on the IDL side.
		struct_nt = (; __name__ = struct_name) # dunder keys to avoid conflicts?
	else
		struct_nt = NamedTuple()
	end
	# this workaround is due to the fact that IDL structures store their data inlined
	# in the same array also for nested structures.
	# We use parentdata as an offset for the inner structure tag's offsets
	_data = _parentdata == C_NULL ? unsafe_load(sref.arr).data : _parentdata

	for i in 1:ntags(sref)
		tag = StructTag(sref, i)
		_tagdata = _data + tag.offset

		if isstruct(tag)

			# The data of the innerstructures is inlined in the same array as the main struct!
			# we call recursively into the sub structure, passing the
			# offset to the begin of the inner structure.
			struct_nt = (; struct_nt..., Symbol(tag.name) => _get_idl_struct(tag.structinfo, _tagdata))

		elseif isarray(tag)

			array = IDLArray(tag.arrinfo, tag.eltype, _tagdata)
			struct_nt = (; struct_nt..., Symbol(tag.name) => PermutedDimsArray(array, dimsperm(ndims(array))))

		else

			_value = Ptr{jl_type(tag.eltype)}(_tagdata)
			tagvalue = unsafe_load(_value)
			struct_nt = (; struct_nt..., Symbol(tag.name) => tagvalue)

		end
	end

	struct_nt
end

function _get_idl_struct_array(_var::Ptr{IDL_VARIABLE})
	# Array of structs in IDL are a mix between SoA and AoS...
	# The memory layout is like an AoS with all values inlined in the same array
	# in order, but the first struct defines the type of struct all other structs
	# will have to be consistent with.
	arr = _var.value.arr |> unsafe_load |> unsafe_load
	sref = _var.value.s |> unsafe_load

	# In IDL there is no real distinction between a struct
	# and an array of structures with only one element.
	# So we split here the logic.
	N = arr.n_elts
	struct_nt = _get_idl_struct(sref)
	if N == 1
		return struct_nt
	else
		# array of structs in IDL can only be uniform with the same struct.
		# So we can construct things
		r = typeof(struct_nt)[]
		elsize = arr.elt_len # size of the struct
		arrlen = arr.arr_len

		_data = arr.data
		for i in 0:N-1
			_struct_offset = _data + (elsize * i)
			push!(r, _get_idl_struct(sref, _struct_offset))
		end

		return r
	end
end

swaprowcol(dims, n) = begin
	nc, nr, r... = dims
	(nr, nc, r...)[1:n]
end

dimsperm(n) = ntuple(n) do i
	n == 1 && return 1
	i == 1 && return 2
	i == 2 && return 1
	return i
end

struct IDLArray{T, N} <: AbstractArray{T, N}
	meta::IDL_ARRAY
	dataoverride::Ptr{Cuchar}

	function IDLArray(idl_array::IDL_ARRAY, type::Integer, offset=C_NULL)
		flags = idl_array.flags
		ndims = idl_array.n_dim % Int

		if flags & IDL_A_FILE != 0
			throw(ArgumentError("memory mapped arrays are not supported"))
		end

		new{jl_type(type), ndims}(idl_array, offset)
	end
end
IDLArray(_arr::Ptr{IDL_ARRAY}, args...) = IDLArray(unsafe_load(_arr), args...)

dataptr(X::IDLArray{T, N}) where {T,N} =
	X.dataoverride == C_NULL ? Ptr{T}(X.meta.data) : Ptr{T}(X.dataoverride)

Base.IndexStyle(::IDLArray) = IndexLinear()

Base.size(X::IDLArray{T, N}) where {T,N} = X.meta.dim[1:N]

Base.eltype(::IDLArray{T, N}) where {T,N} = T

Base.getindex(X::IDLArray{T, N}, i) where {T,N} =
	unsafe_load(dataptr(X), i)

Base.setindex!(X::IDLArray{T, N}, v, i) where {T,N} =
	unsafe_store!(dataptr(X), v, i)

Base.getindex(X::IDLArray{IDL_STRING}, i::Integer) =
	IDL_STRING_STR(unsafe_load(dataptr(X), i))

Base.setindex!(X::IDLArray{IDL_STRING}, s::AbstractString, i::Integer) =
	IDL_StrStore(dataptr(X) + (sizeof(IDL_STRING) * (Int(i)-1)), s)


function get_scalarvar(_var::Ptr{IDL_VARIABLE})
	var_t = unsafe_load(_var.type)
	var_f = unsafe_load(_var.flags)

	(var_f & IDL_V_NOT_SCALAR) != 0 &&
		error("the variable is not scalar!")

	var_t == IDL_TYP_UNDEF &&
		return nothing

	(var_t == IDL_TYP_PTR || var_t == IDL_TYP_OBJREF) &&
		error("Getting variables of type IDL_TYP_PTR or IDL_TYP_OBJREF is not supported.")

	var_t == IDL_TYP_STRING &&
		return unsafe_string(IDL_VarGetString(_var))

	_n 		= Ref{IDL_MEMINT}()
	__data 	= Ref{Ptr{Cchar}}()
	IDL_VarGetData(_var, _n, __data, IDL_TRUE)

	if (var_f & IDL_V_BOOLEAN) != 0
		return convert(Ptr{Bool}, __data[]) |> unsafe_load
	else
		return convert(Ptr{jl_type(var_t)}, __data[]) |> unsafe_load
	end
end



###=== JULIA -> IDL ===###


function put_var end

# References:
# https://github.com/tk3369/julia-notebooks/blob/master/ccall%20-%20using%20cconvert%20and%20unsafe_convert.ipynb
# https://discourse.julialang.org/t/how-to-keep-a-reference-for-c-structure-to-avoid-gc/9310/25
# https://discourse.julialang.org/t/memory-management-and-packagecompiler-libraries/72980/7
# https://discourse.julialang.org/t/cconvert-and-unsafe-convert-with-immutable-struct-containing-a-pointer/124479/5

# Structs in IDL can be named or anonymous.
# named structs are simply user defined structs. That must be isbitstype.
# That means all field must contain isbits types (Pointers count as isbits)
#
# Anonymous structs are named tuples with the same restrictions as above
# namely, all fields must be isbitstypes.

abstract type GENERIC_JL_STRUCT end

# Intermediate representation that holds the data on the julia side.
struct JL_TAG_DEF
	name::String
	dims::SVector{9, Int} # 1st element is the number of dimensions (IDL convention)
	type::Union{Int, GENERIC_JL_STRUCT}
end

# Constructor to the TAG struct used by IDL
function IDL_STRUCT_TAG_DEF(tag::JL_TAG_DEF)

	_name = Base.unsafe_convert(Ptr{Cchar}, tag.name)
	_dims = isnothing(tag.dims) ? C_NULL : Base.unsafe_convert(Ptr{Int}, tag.dims)

	_opaquetype = tag.type isa Int 	? Ptr{Cvoid}(tag.type) :
		tag.type isa JL_STRUCT_DEF  ? begin

			_innertagdef = IDL_MakeStruct(C_NULL, tag.type)
			Ptr{Cvoid}(_innertagdef) # innertagdef lives in IDL memory.

		end : throw(ArgumentError("Invalid parsed tag type"))

	IDL_STRUCT_TAG_DEF(_name, _dims, _opaquetype, 0x00)
end

struct JL_STRUCT_DEF <: GENERIC_JL_STRUCT
	dataref::Ref{<:NamedTuple}
	ndims::Int
	dims::SVector{8, Int}
	tags::Vector{JL_TAG_DEF}
	idltags::Vector{IDL_STRUCT_TAG_DEF}

	function JL_STRUCT_DEF(jlntup::Union{<:NamedTuple, <:DataType})

		tags = parsestruct(jlntup)

		# the tag array passed to IDL needs to be null terminated
		idltags = IDL_STRUCT_TAG_DEF.(tags)
		push!(idltags, IDL_STRUCT_TAG_DEF(C_NULL, C_NULL, C_NULL, 0x00))

		new(Ref(jlntup), 1, SVector{8}(1,0,0,0,0,0,0,0), tags, idltags)
	end

	function JL_STRUCT_DEF(@nospecialize(jlstructarr::AbstractArray{Union{T, S}, N})) where {T<:NamedTuple,S<:DataType, N}
		N > 8 && throw(ArgumentError("IDL supports at most 8-dimensional arrays"))

		tags = parsestruct(first(jlstructarr)) # all structs are the same.

		# the tag array passed to IDL needs to be null terminated
		idltags = IDL_STRUCT_TAG_DEF.(tags)
		push!(idltags, IDL_STRUCT_TAG_DEF(C_NULL, C_NULL, C_NULL, 0x00))

		new(Ref(jlstructarr), N , SVector{8}(size(jlstructarr)..., zeros(Int, 8-N)...), tags, idltags)
	end
end

JL_TAG_DEF(name, x) = throw(ArgumentError("""
	The struct contains a type of data that is not supported.
	All fields must be isbits, in particular:
	Strings must be converted into IDL_STRINGs and Arrays must be
	converted into either NTuples or Static Arrays.
"""))

function JL_TAG_DEF(name, ::T) where T <: JL_SCALAR
	JL_TAG_DEF(name, SVector{9}(0,0,0,0,0,0,0,0,0), idl_type(T))
end

function JL_TAG_DEF(name, value::AbstractArray{T, N}) where {T<:JL_SCALAR, N}
	N > 8 && throw(ArgumentError("IDL supports at most 8-dimensional arrays"))
	JL_TAG_DEF(name, SVector{9}(N, size(value)..., zeros(Int, 8-N)...), idl_type(T))
end

function JL_TAG_DEF(name, value::NTuple{T, N}) where {T<:JL_SCALAR, N}
	N > 8 && throw(ArgumentError("IDL supports at most 8-dimensional arrays"))
	JL_TAG_DEF(name, SVector{9}(N, size(value)..., zeros(Int, 8-N)...), idl_type(T))
end

function JL_TAG_DEF(name, value::Union{<:NamedTuple, <:DataType})
	innersdef = JL_STRUCT_DEF(value)
	JL_TAG_DEF(name, SVector{9}(0,0,0,0,0,0,0,0,0), innersdef)
end

function parsestruct(nt::NamedTuple)
	names = uppercase.(String.(keys(nt))) # IDL requires uppercase names for tags...

	tags = Vector{JL_TAG_DEF}(undef, length(nt))
	for (i, (name, value)) in enumerate(zip(names, nt))
		isbits(value) || throw(ArgumentError("IDL Structs can only contain isbits types"))

		tags[i] = JL_TAG_DEF(name, value)
	end

	return tags
end

function parsestruct(st::T) where T <: DataType
	isstructtype(st) || throw(ArgumentError("Passed struct needs to be a composite data type defined with the `struct` keyword"))
	isbitstype(T) || throw(ArgumentError("Passed struts must be isbits due to how IDL interprets the data."))

	names = uppercase.(String.(fieldnames(T)))
	tags = Vector{JL_TAG_DEF}(undef, length(names))
	for (i, field) in enumerate(names)
		tags[i] = JL_TAG_DEF(field, getfield(st, i))
	end

	return tags
end


function put_var(jlntup::T, name::AbstractString) where T <: NamedTuple
	# creating a struct in IDL is done using a function call,
	# where you provide an array of "Tags" that specifies the
	# structure definition and then the data separately.
	# The tag array must be null terminated with a 0 valued structure.

	root = Ref{JL_STRUCT_DEF}()
	root[] = JL_STRUCT_DEF(jlntup)

	_sdef = IDL_MakeStruct(root[].name, root[].idltags.ref)
	_root = pointer_from_objref(root)
	_root_data = preserve_ref(pointer(root[].dataref), root)
	_root_dims = _root + fieldoffset(typeof(root), 1) + fieldoffset(JL_STRUCT_DEF, 3)

	_var = IDL_ImportNamedArray(name,
		root[].ndims,
		_root_dims,
		IDL_TYP_STRUCT,
		Ptr{Cuchar}(_root_data),
		FREE_JLARR[],
		_sdef
	)

	if _var == C_NULL
		free_jl_array_ref(_root_data)
		throw(SystemError("IDL Error: Failed to create structure"))
	end

end

struct JL_ARRAY_ROOT
	name::String
	ndims::Int
	dims::NTuple{8, Int}
	dataref::Ref
end

function put_var(jlarr::AbstractArray{T, N}, name::AbstractString) where {T <: JL_SCALAR, N}
	idl_var_t = idl_type(T)

	N > 8 && throw(ArgumentError("IDL Arrays can have at most 8 dimensions."))

	if T <: AbstractString
		jlarr = convert.(IDL_STRING, jlarr)
	end

	root = Ref{JL_ARRAY_ROOT}()
	root[] = JL_ARRAY_ROOT(name, N, (size(jlarr)..., zeros(8-N)...), jlarr.ref)

	_root = pointer_from_objref(root)
	_root_data = preserve_ref(pointer(jlarr), root)

	# We need to get the offset for the element of the refvalue as well, to
	# account for possible alignment shenanigans
	# see: https://stackoverflow.com/questions/54889057/how-to-get-a-ptr-to-an-element-of-an-ntuple
	_root_dims = _root + fieldoffset(typeof(root), 1) + fieldoffset(JL_ARRAY_ROOT, 3)

	_var = IDL_ImportNamedArray(
		root[].name,
		root[].ndims,
		_root_dims,
		idl_var_t,
		_root_data,
		FREE_JLARR[],
		C_NULL
	)

	if _var == C_NULL
		free_jl_array_ref(_root_data)
		error("IDL Error: Failed to import array")
	end

	return _var
end

function put_var(jlvar::T, name::AbstractString) where T <: JL_SCALAR
	# get or create new variable with defined name
	_idl_var = IDL_GetVarAddr1(name, IDL_TRUE)

	all_t = Ref{IDL_ALLTYPES}()

	GC.@preserve all_t begin

		_all_t = Base.unsafe_convert(Ptr{IDL_ALLTYPES}, all_t)

		if T <: AbstractString

			GC.@preserve jlvar begin
				IDL_StrStore(_all_t.str, pointer(jlvar))
			end

		else

			all_t_sym = T |> idl_type |> idl_alltypes_symbol
			setproperty!(_all_t, all_t_sym, jlvar)

		end

	end

	idl_var_t = idl_type(T)
	IDL_StoreScalar(_idl_var, idl_var_t, all_t)

	return _idl_var
end



# utilities


name(_idlvar::IDL_VPTR) = IDL_VarName(_idlvar) |> unsafe_string |> Symbol
# reset_session() = idl".reset_session"
execute(str::AbstractString) = IDL.IDL_ExecuteStr(str)