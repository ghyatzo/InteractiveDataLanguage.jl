execute(string::AbstractString) = begin
	# remove comments and coalesce line breaks
	string = replace(replace(string, r";.*" => ""), r"\$\s*\n" => "")
	iostring = IOBuffer(string)
	for line in eachline(iostring)
		execute(line)
	end
end
help() = execute("help")
help(s::AbstractString) = execute("help, "*s)
idlhelp(s::AbstractString) = execute("?"*s)
reset() = execute(".reset_session")
full_reset() = execute(".full_reset_session")
dotrun(filename::AbstractString) = execute(".run $filename")



# three directions of interaction
# * getting and IDL variable into julia:
#	- get just the value of the IDL variable
#	- get a reference to it
# * storing a julia variable into IDL: IDL References julia memory
# * create an IDL variable from julia: Julia initializes IDL memory



##	- Create IDL variables from julia
##		- Scalars (DONE)
##		- Structures
##		- arrays


##	- Transform a JULIA variable into an IDL one
##		- Scalars (DONE)
##		- Structures
## 		- copy array
##		- no copy arrays


##	- Transform an IDL variable into a JL one
##  	- Scalars (DONE with convert)
##  	- Structures
##  	- Copy array (TODO with a subtype of abstractarray)
##		- no copy array (DONE with ArrayView)



## PROTOTYPE FOR THE API

# ## Scalars
# # get the variable
# IDL.get(:A)
# # put the value in the variable
# IDL.put(:A, 2)
# IDL.put(idlvar, 10)


# ## Arrays
# # Get the array held by the variable :A
# IDL.array(:A)
# # Get a view of the array held by the variable :A
# IDL.arrayview(:A)

# # create an array with julia data
# IDL.array(:A, [1, 2, 3])



# ## Get the variable as a struct:
# IDL.struct(:A)



###=== IDL -> JULIA ===###

function getvar end

function getvar(name::AbstractString)
	_var = IDL_GetVarAddr(name)
	if _var == C_NULL
		throw(UndefVarError("No variable named '$name' in the current IDL scope."))
	end

	var = makevar(_var)
	isstruct(var) && return begin
		# IDL_V_STRUCT implies IDL_V_ARR
		# IDL Structures are really only Arrays of structures with only one element.
		sref = unsafe_load(_var.value.s)
		arr = unsafe_load(unsafe_load(_var.value.arr))

		s = IDLStruct(sref)
	 	# Array of structs in IDL are a mix between SoA and AoS...
	 	# The memory layout is like an AoS with all values inlined in the same array
	 	# in order, but the first struct defines the type of struct all other structs
	 	# will have to be consistent with.
		return _maybe_struct_array(s, arr)
	end

	isarray(var) && return IDLArray(var)

end

function _maybe_struct_array(s::IDLStruct{N, L, T, n}, arr::IDL_ARRAY) where {N, L, T, n}

# 	# In IDL there is no real distinction between a struct
# 	# and an array of structures with only one element.
# 	# So we split here the logic.
	arr.n_elts == 1 && return s

	elsize = arr.elt_len
	array = IDLStruct{N, L, T, n}[s]
	for i in 2:arr.n_elts
		offset = elsize * (i-1)
		push!(array, IDLStruct(s, s.ptr + offset))
	end
	return reshape(array, arr.dim[1:Int(arr.n_dim)])
end



###=== JULIA -> IDL ===###


function putvar end

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
	JL_TAG_DEF(name, SVector{9}(0,0,0,0,0,0,0,0,0), idltype(T))
end

function JL_TAG_DEF(name, value::AbstractArray{T, N}) where {T<:JL_SCALAR, N}
	N > 8 && throw(ArgumentError("IDL supports at most 8-dimensional arrays"))
	JL_TAG_DEF(name, SVector{9}(N, size(value)..., zeros(Int, 8-N)...), idltype(T))
end

function JL_TAG_DEF(name, value::NTuple{T, N}) where {T<:JL_SCALAR, N}
	N > 8 && throw(ArgumentError("IDL supports at most 8-dimensional arrays"))
	JL_TAG_DEF(name, SVector{9}(N, size(value)..., zeros(Int, 8-N)...), idltype(T))
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


function putvar(jlntup::T, name::AbstractString) where T <: NamedTuple
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

function putvar(jlarr::AbstractArray{T, N}, name::AbstractString) where {T <: Union{JL_SCALAR, IDL_STRING}, N}
	idl_var_t = idltype(T)

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