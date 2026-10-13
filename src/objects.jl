#============================================================#
#
#	IDL Objects
#
#	IDL objects (HASH, LIST, DICTIONARY, IDL_Container, user
#	classes) live in heap variables and are reached through
#	variables of type OBJREF.
#
#	Calls go through IDL source text rather than through the
#	documented C entry point for method calls,
#	IDL_ObjCallMethodByString: that one raises its errors with no
#	error frame established outside the interpreter, which aborts
#	the process (IDL 8.9 on Windows), while a statement run by
#	IDL_ExecuteStr recovers, reports the error and leaves the
#	result undefined. `idlvalue` turns that into a Julia error.
#
#============================================================#

#------------------------------------------------------------
#
#	Names for variables that hold a statement's result
#
#------------------------------------------------------------

# A statement hands its result over by name. Names are pooled: a
# wrapper that keeps such a variable alive (an object, a struct view)
# holds the owner, which drops the IDL variable and returns the name
# when the Julia value is collected.
mutable struct IDLNameOwner
	name::String
	live::Bool

	function IDLNameOwner()
		this = new(fresh_result_name(), true)
		finalizer(this) do o
			release!(o)
		end
		return this
	end
end

const FREE_RESULT_NAMES = String[]
const RESULT_NAME_COUNT = Ref(0)

function fresh_result_name()
	while true
		name = if isempty(FREE_RESULT_NAMES)
			RESULT_NAME_COUNT[] += 1
			"JL_RESULT_$(RESULT_NAME_COUNT[])"
		else
			pop!(FREE_RESULT_NAMES)
		end
		v__ = IDL_GetVarAddr(name)
		v__ == C_NULL && return name
		vartype(v__) == IDL_TYP_UNDEF && (varflags(v__) & IDL_V_NULL) == 0 && return name
	end
end

# Drop the value the name holds and give the name back to the pool. The
# name stays in IDL's symbol table as an undefined variable.
function release!(o::IDLNameOwner)
	o.live || return nothing
	o.live = false
	v__ = IDL_GetVarAddr(o.name)
	v__ == C_NULL || IDL_Delvar(v__)
	push!(FREE_RESULT_NAMES, o.name)
	return nothing
end

#------------------------------------------------------------
#
#	The wrapper
#
#------------------------------------------------------------

"""
    IDLObject(v::AbstractIDLVariable)
    IDLObject(class, args...)
    jlobject(v)
    jlobject(:v)

A view of an IDL object, or a new object built by calling the IDL function
`class` with `args`: `IDLObject(:HASH, "a", 1)` runs `HASH('a', 1)`.

Method names are looked up on the object, so `o.count()` runs `o->COUNT()`,
and `o["a"]` / `o["a"] = 1` run the brackets overloads `o['a']` /
`o['a'] = 1`. IDL resolves a parenthesised name as a function method, so
IDL procedure methods (such as `LIST::Add`) have to be run as statements
with [`idlrun`](@ref) instead.

Arguments are passed as IDL literals: scalars, strings, arrays, `NamedTuple`s
(structures), `nothing` (`!NULL`) and other `IDLObject`s (by reference).

`jlobject` views an existing IDL variable, so reassigning that variable in
IDL leaves the wrapper without an object and using it then throws.
"""
struct IDLObject <: AbstractIDLVariable
	v_::Variable
	owner_::Union{Nothing,IDLNameOwner}
end

function IDLObject(class::Union{Symbol, AbstractString}, args...)
	obj = idlvalue("$(uppercase(string(class)))($(_idl_args(args...)))")
	obj isa IDLObject ||
		throw(ArgumentError("IDL function $(class)() returned a $(typeof(obj)), not an object."))
	return obj
end

varptr__(o::IDLObject) = varptr__(o.v_)
idltype(::Type{IDLObject}) = T_OBJREF
isvalid(o::IDLObject) = vartype(o) == T_OBJREF

function Base.show(io::IO, o::IDLObject)
	print(io, "IDLObject('", name(o), "')")
	isvalid(o) || print(io, " (no longer an object)")
end

function checkobj(o::IDLObject)
	isvalid(o) || throw(ErrorException("IDL variable '$(name(o))' no longer holds an object."))
	return o
end

function jlobject(v::AbstractIDLVariable)
	vartype(v) == T_OBJREF || throw(ArgumentError("IDL variable '$(name(v))' does not hold an object."))
	isarray(v) && throw(ArgumentError("Arrays of IDL objects are not supported."))
	isempty(name(v)) && throw(ArgumentError("An unnamed IDL object cannot be wrapped; assign it to a variable first."))
	return IDLObject(Variable(varptr__(v)), nothing)
end
jlobject(name::Symbol) = jlobject(idlvar(name))
jlobject(o::IDLObject) = o
IDLObject(v::AbstractIDLVariable) = jlobject(v)

Base.convert(::Type{IDLObject}, v::AbstractIDLVariable) = jlobject(v)

idl_literal(o::IDLObject) = name(checkobj(o))

#------------------------------------------------------------
#
#	Method and bracket forwarding
#
#------------------------------------------------------------

struct IDLMethod
	o::IDLObject
	meth::Symbol
end

Base.show(io::IO, m::IDLMethod) = print(io, "IDLMethod(", name(m.o), "->", uppercase(string(m.meth)), ")")

function (m::IDLMethod)(args...)
	o = checkobj(m.o)
	return idlvalue("$(name(o))->$(uppercase(string(m.meth)))($(_idl_args(args...)))")
end

function Base.getproperty(o::IDLObject, f::Symbol)
	(f === :v_ || f === :owner_) && return getfield(o, f)
	return IDLMethod(o, f)
end

_subs(subs) = join(map(idl_literal, subs), ", ")

function Base.getindex(o::IDLObject, subs...)
	o = checkobj(o)
	return idlvalue("$(name(o))[$(_subs(subs))]")
end

function Base.setindex!(o::IDLObject, value, subs...)
	o = checkobj(o)
	idlstatement("$(name(o))[$(_subs(subs))] = $(idl_literal(value))")
	return value
end

#------------------------------------------------------------
#
#	Running statements and taking their result
#
#------------------------------------------------------------

# Every statement that can fail runs through here: IDL reports the
# error on stderr, the output callback stores it in LAST_ERROR_MSG and
# the statement leaves no other trace behind.
function idlstatement(src::AbstractString)
	LAST_ERROR_MSG[] = nothing
	idlrun(src)

	msg = LAST_ERROR_MSG[]
	LAST_ERROR_MSG[] = nothing
	msg === nothing || throw(ErrorException(msg))

	return nothing
end

function idlvalue(src::AbstractString)
	owner = IDLNameOwner()
	LAST_ERROR_MSG[] = nothing
	idlrun("$(owner.name) = $src")

	return take_result(owner)
end

function take_result(owner::IDLNameOwner)
	v__ = IDL_GetVarAddr(owner.name)

	if v__ == C_NULL
		return fail_result(owner, "IDL statement did not return a value.")
	end

	v = Variable(v__)
	if !isvalid(v)
		# `!NULL` is a value a statement may return; a failed statement
		# leaves an undefined variable and nothing else behind.
		isnothing(v) && return (release!(owner); nothing)
		return fail_result(owner, "IDL statement did not return a value.")
	end

	if vartype(v) == T_OBJREF
		isarray(v) && return fail_result(owner, "Arrays of IDL objects are not supported.")
		return IDLObject(v, owner)
	elseif isstruct(v)
		sref_ = sdef(v)
		arr_ = unsafe_load(sref_.arr)
		Int(arr_.n_elts) == 1 ||
			return fail_result(owner, "Arrays of structures are not supported.")
		return StructView(sref_.sdef, arr_.data, owner)
	elseif vartype(v) == T_PTR
		return fail_result(owner, "IDL pointers are not supported.")
	end

	value = isarray(v) ? jlarray(v) : jlscalar(v)
	release!(owner)
	return value
end

fail_result(owner::IDLNameOwner, fallback::AbstractString) = begin
	msg = something(LAST_ERROR_MSG[], fallback)
	LAST_ERROR_MSG[] = nothing
	release!(owner)
	throw(ErrorException(msg))
end