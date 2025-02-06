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

	if (var_f & IDL_V_ARR) != 0
		arr = unsafe_load(unsafe_load(_var.value.arr))
		ndims = arr.n_dim
		nelts = arr.n_elts

		if (var_f & IDL_V_STRUCT) != 0
			# IDL_V_STRUCT implies IDL_V_ARR
			# IDL Structures are really only Arrays of structures with only one element.
			sref = unsafe_load(_var.value.s)

			s = IDLStruct(sref)
			struct_t = typeof(s)

			if nelts > 1
				#var.value.s.arr == var.value.arr (C Union)
				elsize = arr.elt_len
				array = Array{struct_t, ndims}(undef, nelts)
				array[1] = s
				for i in 2:nelts
					offset = elsize * (i-1)
					array[i] = IDLStruct(s, s.ptr + offset)
				end
				return array
			else
				return s
			end
		end
		jltype = jl_type(var_t)
		array = IDLArray{jltype, ndims}(arr, C_NULL)
		return PermutedDimsArray(array, dimsperm(ndims(array)))
	end

	return get_scalarvar(_var)
end

# function _get_idl_struct_array(_var::Ptr{IDL_VARIABLE})
# 	# Array of structs in IDL are a mix between SoA and AoS...
# 	# The memory layout is like an AoS with all values inlined in the same array
# 	# in order, but the first struct defines the type of struct all other structs
# 	# will have to be consistent with.
# 	arr = _var.value.arr |> unsafe_load |> unsafe_load
# 	sref = _var.value.s |> unsafe_load

# 	# In IDL there is no real distinction between a struct
# 	# and an array of structures with only one element.
# 	# So we split here the logic.
# 	N = arr.n_elts
# 	struct_nt = IDLStruct(sref)
# 	if N == 1
# 		return struct_nt
# 	else
# 		# array of structs in IDL can only be uniform with the same struct.
# 		# So we can construct things
# 		r = typeof(struct_nt)[]
# 		elsize = arr.elt_len # size of the struct
# 		arrlen = arr.arr_len

# 		_data = arr.data
# 		for i in 0:N-1
# 			_struct_offset = _data + (elsize * i)
# 			push!(r, makestruct(sref, _struct_offset))
# 		end

# 		return r
# 	end
# end


function get_scalarvar(_var::Ptr{IDL_VARIABLE})
	var_f, var_t = varinfo(_var)

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