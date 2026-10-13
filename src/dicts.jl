#------------------------------------------------------------
#
#	Dictionary view of a HASH object
#
#------------------------------------------------------------

"""
    jldict(v)
    jldict(:name)

A Julia `AbstractDict` view of an IDL `HASH` object, like [`jlstruct`](@ref)
and [`jlview`](@ref) for structures and arrays. The entries stay in IDL, so
both languages see each other's edits. `v` must hold a HASH or a subclass
of one (`DICTIONARY`, say); [`idldict`](@ref) creates one.

```julia
jldict(:myhash)["a"] = 1
jldict(:myhash)["a"]
```
"""
struct DictView <: AbstractDict{Any,Any}
	o::IDLObject

	function DictView(o::IDLObject)
		# HASH subclasses such as DICTIONARY answer to the hash methods too.
		if idlvalue("ISA($(name(checkobj(o))), 'HASH')") != 1
			class = idlvalue("OBJ_CLASS($(name(o)))")
			throw(ArgumentError("jldict needs a HASH object; '$(name(o))' is a $class."))
		end
		return new(o)
	end
end

jldict(v::Union{Symbol, AbstractIDLVariable}) = DictView(jlobject(v))

"""
    idldict(name::Symbol, d::AbstractDict)

Create the IDL variable `name` holding a `HASH` with the entries of `d`,
like [`idlstruct`](@ref) does for structures. Keys and values are written
as [`IDLObject`](@ref) arguments, so every type those accept works.

```julia
idldict(:myhash, Dict("a" => 1))
jldict(:myhash)["a"]
```
"""
function idldict(name::Symbol, d::AbstractDict)
	args = Any[]
	for (k, v) in d
		push!(args, k, v)
	end
	return idlvar(name, IDLObject(:HASH, args...))
end

Base.length(d::DictView) = Int(d.o.count())
Base.haskey(d::DictView, key) = Bool(d.o.haskey(key))

function Base.getindex(d::DictView, key)
	haskey(d, key) || throw(KeyError(key))
	return d.o[key]
end

Base.setindex!(d::DictView, value, key) = (d.o[key] = value; d)

# HASH::Remove is a procedure method and errors on an absent key, while
# `delete!` must not.
function Base.delete!(d::DictView, key)
	haskey(d, key) || return d
	idlstatement("$(name(checkobj(d.o)))->REMOVE, $(idl_literal(key))")
	return d
end

# Hash keys come back as the elements of a LIST, read with 0-based brackets.
function Base.keys(d::DictView)
	l = d.o.keys()
	return Any[l[i - 1] for i in 1:Int(l.count())]
end

Base.get(d::DictView, key, default) = haskey(d, key) ? d[key] : default

function Base.pop!(d::DictView, key)
	haskey(d, key) || throw(KeyError(key))
	value = d[key]
	delete!(d, key)
	return value
end

function Base.iterate(d::DictView, state=(keys(d), 1))
	keys_, i = state
	i > length(keys_) && return nothing
	key = keys_[i]
	return key => d[key], (keys_, i + 1)
end