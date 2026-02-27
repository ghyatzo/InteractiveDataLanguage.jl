const IDL_VERSION_STRING = "$IDL_MAJOR_STRING.$IDL_MINOR_STRING.$IDL_SUBMINOR_STRING"

const IDL_VERSION_STRING_NOSUBMINOR = "$IDL_MAJOR_STRING.$IDL_MINOR_STRING"

const IDL_EZ_TYP_NUMERIC = ((((((((((1 << IDL_TYP_INT) | (1 << IDL_TYP_LONG)) | (1 << IDL_TYP_FLOAT)) | (1 << IDL_TYP_DOUBLE)) | (1 << IDL_TYP_COMPLEX)) | (1 << IDL_TYP_BYTE)) | (1 << IDL_TYP_DCOMPLEX)) | (1 << IDL_TYP_UINT)) | (1 << IDL_TYP_ULONG)) | (1 << IDL_TYP_LONG64)) | (1 << IDL_TYP_ULONG64)

const IDL_RASTER_MSB_LEFT = [0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01]

const IDL_RASTER_MSB_RIGHT = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80]

# accessor to get the property from an array pointer directly
Base.getproperty(x::Ptr{IDL_ARRAY}, f::Symbol) = begin
    fieldid = findfirst(==(f), fieldnames(IDL_ARRAY))
    isnothing(fieldid) && error("IDL_ARRAY does not have the field $f")
    Ptr{fieldtype(IDL_ARRAY, f)}(x + fieldoffset(IDL_ARRAY, fieldid))
end

IDL_INIT_DATA(init_options::Int64) = IDL_INIT_DATA(convert(IDL_INIT_DATA_OPTIONS_T, init_options))
function IDL_INIT_DATA(init_options::IDL_INIT_DATA_OPTIONS_T)
    ref = Ref{IDL_INIT_DATA}()
    GC.@preserve ref begin
        x = Base.unsafe_convert(Ptr{IDL_INIT_DATA}, ref)
        x.options = init_options
        ref[]
    end
end
