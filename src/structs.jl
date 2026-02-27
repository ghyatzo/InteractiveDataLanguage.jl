@comment begin

	idlrun("arrstruct = [{A:2LL, B:3LL, C:FLTARR(3)}, {A:4LL, B:5LL, C:FLTARR(3)}]")

	@info InteractiveDataLanguage.IDL_GetVarAddr("arrstruct")

	idlrun("arrstruct[1].A = 7LL")

	@info InteractiveDataLanguage.IDL_GetVarAddr("arrstruct")

	arrstruct = idlvar(:arrstruct)
	varrstr = unsafe_load(arrstruct.ptr)
	varrstr_data = varrstr.value.s.arr |> unsafe_load

	data__ = varrstr_data.data

	T = @NamedTuple{A::Int, B::Int, C::NTuple{Float32, 3}}
	unsafe_wrap(Array, Ptr{T}(data__), (2,))
end

# using Accessors
# using Accessors: IndexLens, PropertyLens, ComposedOptic

# struct UnsafeStoreLens!{L}
#     inner::L
# end

# (l::UnsafeStoreLens!)(obj) = l.inner(obj)
# function Accessors.set(obj, l::UnsafeStoreLens!{<: ComposedOptic}, val)
# 	# We override the way we compose optics by rewrapping
#     o_inner = l.inner.inner(obj)
#     set(o_inner, UnsafeStoreLens!(l.inner.outer), val)
# end
# function Accessors.set(o, l::Lens!{PropertyLens{prop}}, val) where {prop}
#     setproperty!(o, prop, val)
#     o
# end
# function Accessors.set(o, l::Lens!{<:IndexLens}, val)
#     o[l.pure.indices...] = val
#     o
# end

_extract_tag_info(sdef, i::Int) = begin
	_tagvar = Ref{Ptr{IDL_VARIABLE}}()
	offset = IDL_StructTagInfoByIndex(sdef, i - 1, IDL_MSG_RET, _tagvar)
	if offset == -1
		throw(ArgumentError("The structure does not have an $i-th tag."))
	end

	return _tagvar[], offset
end

function parse_tags(sdef)

	n = IDL_StructNumTags(sdef) % Int
	names = ntuple(n) do i
		tagname__ = IDL_StructTagNameByIndex(sdef, i-1, IDL_MSG_RET, C_NULL)
		Symbol(unsafe_string(tagname__))
	end

	tagvar = Ref{Ptr{IDL_VARIABLE}}()
	types = ntuple(n) do i
		offset = IDL_StructTagInfoByIndex(sdef, i-1, IDL_MSG_RET, tagvar)
		local tagvar = Variable(tagvar[])

		elt = eltype(tagvar)

		# If struct is also array, so we don't need to check for simple array.
		# if we check for isstruct first.
		if isstruct(tagvar)
			return parse_tags(sdef(tagvar))
		elseif isarray(tagvar)
			N = arr_ndims(array__(tagvar))
			dims =
		else

		end


	end



end

struct Structure{T, V <: AbstractIDLVariable}
	name::String
	sdef::T
	v::V

	function Structure(v::V) where V <: AbstractIDLVariable
		structdef = sdef(v)



	end
end