#[
This file contains the procedures related to attributes.

The attribute types are defined in the datatypes.nim file.
]#

import typeinfo
import tables
import strutils, sequtils

import hdf5_wrapper, h5util, H5nimtypes, datatypes, dataspaces, util

proc `$`*(h5attr: H5Attributes): string =
  result = $(h5attr[])

# forward declare procs, which we need to read the attributes from file
proc read_all_attributes*(h5attr: H5Attributes)

proc openAttrByIdx(h5attr: H5Attributes, idx: int): AttributeID =
  ## proc to open an attribute by its id in the H5 file and returns
  ## attribute id if succesful
  ## need to hand H5Aopen_by_idx the location relative to the location_id,
  ## if I understand correctly
  let loc = "."
  # we read by creation order, increasing from 0
  result = H5Aopen_by_idx(h5attr.parent_id.to_hid_t,
                          loc.cstring,
                          H5_INDEX_CRT_ORDER,
                          H5_ITER_INC,
                          hsize_t(idx),
                          H5P_DEFAULT,
                          H5P_DEFAULT)
    .toAttributeID

proc openAttribute(h5attr: H5Attributes, key: string): AttributeID =
  ## proc to open an attribute by its name.
  ## NOTE: This assumes the caller already checked the attribute exists!
  # we read by creation order, increasing from 0
  result = H5Aopen(h5attr.parent_id.to_hid_t, key.cstring, H5P_DEFAULT)
    .toAttributeID

proc getAttrName*[T: SomeInteger](attr_id: AttributeID, buf_space: T = 200): string =
  ## proc to get the attribute name of the attribute with the given id
  ## reserves space for the name to be written to
  withDebug:
    debugEcho "Call to getAttrName! with size $#" % $buf_space
  var name = newString(buf_space)
  # read the name
  let length = H5Aget_name(attr_id.id, len(name).csize_t, name.cstring)
  # H5Aget_name returns the length of the name. In case the name
  # is longer than the given buffer, we call this function again with
  # a buffer with the correct length
  if length <= name.len.csize_t:
    result = name.strip
    # now set the length of the resulting string to the size
    # it actually occupies
    result.setLen(length)
  else:
    result = getAttrName(attr_id, length)

proc setAttrAnyKind[T](attr: H5Attr, dtype: typedesc[T]) =
  ## proc which sets the AnyKind fields of a H5Attr
  when dtype is void:
    # use heuristics
    let npoints = getNumberOfPoints(attr.attr_dspace_id)
    if npoints > 1:
      attr.dtypeAnyKind = dkSequence
      # set the base type based on what's contained in the sequence
      attr.dtypeBaseKind = h5ToNimType(attr.dtype_c)
    else:
      attr.dtypeAnyKind = h5ToNimType(attr.dtype_c)
  elif dtype is seq:
    attr.dtypeAnyKind = dkSequence
    attr.dtypeBaseKind = h5ToNimType(attr.dtype_c)
  else:
    attr.dtypeAnyKind = h5ToNimType(attr.dtype_c)

proc getAttrDataspaceID(attr_id: Attribute_ID): DataspaceID =
  ## returns a valid dataspace for the given attribute
  result = H5Aget_space(attr_id.id).toDataspaceID()

proc getAttributeType(attr_id: AttributeID): DatatypeID =
  result = H5Aget_type(attr_id.id).toDatatypeID()

proc readAttributeInfo(h5attr: H5Attributes,
                       attr: H5Attr,
                       name: string) =
  withDebug:
    debugEcho "Found? ", attr.attr_id, " with name ", name
  # get dtypes and dataspace id
  attr.dtype_c = getAttributeType(attr.attr_id)

  # TODO: remove debug
  withDebug:
    debugEcho "attr ", name, " is vlen string ", H5Tis_variable_str(attr.dtype_c.id)
  #attr.dtype_c = H5Tget_native_type(attr.dtype_c, H5T_DIR_ASCEND)
  #echo "Encoding is native ", H5Tget_cset(attr.dtype_c)
  attr.attr_dspace_id = getAttrDataspaceID(attr.attr_id)
  # now set the attribute any kind fields (checks whether attr is a sequence)
  attr.setAttrAnyKind(void)
  # add to this attribute object
  h5attr.attr_tab[name] = attr

proc readAttributeInfo(h5attr: H5Attributes, key: string) =
  ## reads all information about the attribute `key` from the H5 file
  ## NOTE: this does ``not`` read the value of that attribute!
  var attr = newH5Attr()
  attr.attr_id = openAttribute(h5attr, key)
  attr.opened = true
  readAttributeInfo(h5attr, attr, key)

proc read_all_attributes*(h5attr: H5Attributes) =
  ## proc to read all attributes of the parent from file and store the names
  ## and attribute ids in `h5attr`.
  ## NOTE: If possible try to avoid using this proc! However, if you must, make
  ## sure to close all attributes after usage, otherwise memory leaks might happen.
  # first get how many objects there are
  h5attr.num_attrs = h5attr.getNumAttrs
  for i in 0 ..< h5attr.num_attrs:
    var attr = newH5Attr()
    attr.attr_id = openAttrByIdx(h5attr, i)
    attr.opened = true
    let name = getAttrName(attr.attr_id)
    readAttributeInfo(h5attr, attr, name)

proc existsAttribute*(parent: ParentID, name: string): bool =
  ## simply check if the given attribute name corresponds to an attribute
  ## of the given object
  ## throws:
  ##   HDF5LibraryError = in case a call to the H5 library fails
  let exists = H5Aexists(parent.to_hid_t, name)
  if exists > 0:
    result = true
  elif exists == 0:
    result = false
  else:
    raise newException(HDF5LibraryError, "HDF5 library called returned bad value in `existsAttribute` function")

template existsAttribute*[T: (H5File | H5Group | H5DataSet)](h5o: T, name: string): bool =
  ## proc to check whether a given
  ## simply check if the given attribute name corresponds to an attribute
  ## of the given object
  existsAttribute(h5o.getH5Id, name)

proc deleteAttribute*(h5id: ParentID, name: string): bool =
  ## deletes the given attribute `name` on the object defined by
  ## the H5 id `h5id`
  ## throws:
  ##   HDF5LibraryError = may be raised by the call to `existsAttribute`
  ##     if a call to the H5 library fails
  withDebug:
    debugEcho "Deleting attribute $# on id $#" % [name, $h5id]
  if existsAttribute(h5id, name) == true:
    let success = H5Adelete(h5id.to_hid_t, name)
    result = if success >= 0: true else: false
  else:
    result = true

proc deleteAttribute*[T: (H5File | H5Group | H5DataSet)](h5o: T, name: string): bool =
  result = deleteAttribute(getH5Id(h5o), name)
  # if successful also lower the number of attributes
  h5o.attrs.num_attrs = h5o.attrs.getNumAttrs

proc createAttribute(pid: ParentID, name: string, dtype: DatatypeID,
                     dspace: DataspaceID): AttributeID =
  ## Creates an attribute `name` under `pid` with default properties.
  result = H5Acreate2(pid.to_hid_t, name.cstring, dtype.id,
                      dspace.id, H5P_DEFAULT, H5P_DEFAULT).toAttributeID

proc writeAttribute(attr_id: AttributeID, dtype: DatatypeID, data: pointer) =
  ## Writes the given daat to the attribute.
  ##
  ## Note: This proc is inherently unsafe. The callee needs to make sure the
  ## data and dataspaces are prepared correctly.
  let err = H5Awrite(attr_id.id, dtype.id, data)
  if err < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
      "calling `H5Awrite` in `writeAttribute`.")

proc write_attribute*[T](h5attr: H5Attributes, name: string, val: T, skip_check = false) =
  ## writes the attribute `name` of value `val` to the object `h5o`
  ## NOTE: by defalt this function overwrites an attribute, if an attribute
  ## of the same name already exists!
  ## need to
  ## - create simple dataspace
  ## - create attribute
  ## - write attribute
  ## - add attribute to h5attr
  ## - later close attribute when closing parent of h5attr
  var attr_exists = false
  # the first check is done, since we may be calling this function KNOWING that
  # the attribute does not exist. This should normally not be done by a user,
  # but only in case we have previously succesfully deleted the attribute
  if skip_check == false:
    attr_exists = name in h5attr
    withDebug:
      debugEcho "Attribute $# exists $#" % [name, $attr_exists]
  if not attr_exists:
    # create a H5Attr, which we add to the table attr_tab of the given
    # h5attr object once we wrote it to file
    var attr = new H5Attr

    when T is SomeNumber or T is char:
      let
        dtype = nimToH5type(T)
        # create dataspace for single element attribute
        attr_dspace_id = simple_dataspace(1)
        # create the attribute
        attribute_id = createAttribute(h5attr.parent_id, name, dtype,
                                       attr_dspace_id)
        # mutable copy for address
      var mval = val
      # write the value
      writeAttribute(attribute_id, dtype, addr(mval))
      # write information to H5Attr tuple
      attr.attr_id = attribute_id
      attr.opened = true
      attr.dtype_c = dtype
      attr.attr_dspace_id = attr_dspace_id
      # set any kind fields (check whether is sequence)
      attr.setAttrAnyKind(T)

    elif T is seq or T is string:
      # NOTE:
      # in principle we need to differentiate between simple sequences and nested
      # sequences. However, for now only support normal seqs.
      # extension to nested seqs should be easy (using shape, handed simple_dataspace),
      # however we still need to have a good function to get the basetype of a nested
      # sequence for that
      when T is seq[string]:
        let
          dtype = nimToH5type(string)
          attr_dspace_id = string_dataspace(val, dtype)
      elif T is seq:
        # take first element of sequence to get the datatype
        let
          dtype = nimToH5type(type(val[0]))
          # create dataspace for attribute
          # 1D so call simple_dataspace with integer, instead of seq
          attr_dspace_id = simple_dataspace(len(val))
      else:
        let
          # get copy of string type
          dtype = nimToH5type(type(val))
          # and reserve dataspace for string
          attr_dspace_id = string_dataspace(val, dtype)
      # create the attribute
      let attribute_id = createAttribute(h5attr.parent_id, name, dtype, attr_dspace_id)
      # write the value
      if val.len > 0:
        # only write the value, if we have something to write
        when T is seq[string]:
          var cstringData = val.mapIt(it.cstring)
          writeAttribute(attribute_id, dtype, addr(cstringData[0]))
        else:
          writeAttribute(attribute_id, dtype, unsafeAddr(val[0]))
      # write information to H5Attr tuple
      attr.attr_id = attribute_id
      attr.opened = true
      attr.dtype_c = dtype
      attr.attr_dspace_id = attr_dspace_id
      # set any kind fields (check whether is sequence)
      attr.setAttrAnyKind(T)
    elif T is bool:
      # NOTE: in order to support booleans, we need to use HDF5 enums, since HDF5 does not support
      # a native boolean type. H5 enums not supported yet though...
      echo "Type `bool` currently not supported as attribute"
      discard
    else:
      echo "Type `$#` currently not supported as attribute" % $T
      discard

    # add H5Attr tuple to H5Attributes table
    h5attr.attr_tab[name] = attr
    h5attr.attr_tab[name].close()
  else:
    # if it does exist, we delete the attribute and call this function again, with
    # exists = true, i.e. without checking again whether element exists. Saves us
    # a call to the hdf5 library
    let success = deleteAttribute(h5attr.parent_id, name)
    if success == true:
      write_attribute(h5attr, name, val, true)
    else:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed on call in `deleteAttribute`")

  # independent of previous attribute, refresh the number of attributes
  h5attr.num_attrs = h5attr.getNumAttrs

proc `[]=`*[T](h5attr: H5Attributes, name: string, val: T) =
  ## convenience access to write_attribue
  h5attr.write_attribute(name, val)

proc readStringArrayAttribute(attr: H5Attr, npoints: hssize_t): seq[string] =
  ## proc to read an array of strings attribute from a H5 file, for an existing
  ## `H5Attr`. This proc is only used in the `read_attribute` proc
  ## for users after checking of attribute is done.
  doAssert (attr.dtypeAnyKind == dkSequence and attr.dtypeBaseKind == dkString) or
    (attr.dtypeAnyKind == dkString and npoints == 1.hssize_t),
     "`readStringArrayAttribute` called for a non string attribute. Attribute " &
     "is kind " & $attr.dtypeAnyKind & "!"
  # create a void pointer equivalent
  let nativeType = copyType(H5T_C_S1)
  discard H5Tset_size(nativeType.id, H5T_VARIABLE)
  var buf = newSeq[cstring](npoints.int)
  let err = H5Aread(attr.attr_id.id, nativeType.id, buf[0].addr)
  doAssert err >= 0
  # cast the void pointer to a ptr on a ptr of an unchecked array
  # and dereference it to get a ptr to an unchecked char array
  result = newSeq[string](npoints)
  for i, s in buf:
    result[i] = $s

proc readStringAttribute(attr: H5Attr): string =
  ## proc to read a string attribute from a H5 file, for an existing
  ## `H5Attr`. This proc is only used in the `read_attribute` proc
  ## for users after checking of attribute is done.
  doAssert attr.dtypeAnyKind == dkString, "`readStringAttribute` called for a non " &
    "string attribute. Attribute is kind " & $attr.dtypeAnyKind & "!"
  # in case of string, need to determine size. use:
  # in case of existence, read the data and return
  if isVariableString(attr.dtype_c):
    let nativeType = copyType(H5T_C_S1)
    discard H5Tset_size(nativeType.id, H5T_VARIABLE)
    var buf: cstring
    let err = H5Aread(attr.attr_id.id, nativeType.id, buf.addr)
    doAssert err >= 0
    result = $buf
  else:
    attr.attr_dspace_id = getAttrDataspaceID(attr.attr_id)
    let nativeType = getNativeType(attr.dtype_c)
    let string_len = H5Aget_storage_size(attr.attr_id.id)
    var buf_string = newString(string_len)
    let err = H5Aread(attr.attr_id.id, nativeType.id, addr buf_string[0])
    doAssert err >= 0
    result = buf_string

proc read_attribute*[T](h5attr: H5Attributes, name: string, dtype: typedesc[T]): T =
  ## now implement reading of attributes
  ## finally still need a read_all attribute. This function only reads a single one, if
  ## it exists.
  ## check existence, since we read all attributes upon creation of H5Attributes object
  ## (attr as small, so the performance overhead should be minimal), we can just access
  ## the attribute table to check for existence
  ## inputs:
  ##   h5attr: H5Attributes = H5Attributes from which to read specific attribute
  ##   name: string = name of the attribute to be read
  ##   dtype: typedesc[T] = datatype of the attribute to be read. Needed to define return
  ##     value.
  ## throws:
  ##   KeyError: In case the key does not exist as an attribute

  # TODO: check err values!

  let attr_exists = name in h5attr
  var err: herr_t

  if attr_exists:
    # in case of existence, read the data and return
    h5attr.readAttributeInfo(name)
    let attr = h5attr.attr_tab[name]
    when T is SomeNumber or T is char:
      var at_val: T
      err = H5Aread(attr.attr_id.id, attr.dtype_c.id, addr(at_val))
      if err < 0:
        raise newException(HDF5LibraryError, "Call to `H5Aread` failed in `read_attribute`.")
      result = at_val
    elif T is seq:
      # determine number of elements in seq
      let npoints = getNumberOfPoints(attr.attr_dspace_id)
      type TT = type(result[0])
      # in case it's a string, do things differently..
      when TT is string:
        # get string attribute as single string first
        result = readStringArrayAttribute(attr, npoints)
      else:
        # read data
        # return correct type based on base kind
        result.setLen(npoints)
        err = H5Aread(attr.attr_id.id, attr.dtype_c.id, addr result[0])
        if err < 0:
          raise newException(HDF5LibraryError, "Call to `H5Aread` failed in `read_attribute`.")
    elif T is string:
      # case of single string attribute
      result = readStringAttribute attr
    # close attribute again after reading
    h5attr.attr_tab[name].close()
  else:
    raise newException(KeyError, "No attribute `$#` exists in object `$#`" % [name, h5attr.parent_name])

proc `[]`*[T](h5attr: H5Attributes, name: string, dtype: typedesc[T]): T =
  # convenience access to read_attribute
  h5attr.read_attribute(name, dtype)

proc `[]`*(h5attr: H5Attributes, name: string): DtypeKind =
  # accessing H5Attributes by string simply returns the datatype of the stored
  # attribute as an AnyKind value
  h5attr.attr_tab[name].dtypeAnyKind

proc contains*(attr: H5Attributes, key: string): bool =
  ## proc to check whether a given attribute with name `key` exists in the attribute
  ## field of a group or dataset
  result = attr.parent_id.existsAttribute(key)

template withAttr*(h5attr: H5Attributes, name: string, actions: untyped) =
  ## convenience template to read and work with an attribute from the file and perform actions
  ## with that attribute, without having to manually check the data type of the attribute

  # TODO: NOTE this is a very ugly solution, when we could just use H5Ocopy in the calling
  # proc....
  case h5attr.attr_tab[name].dtypeAnyKind
  of dkBool:
    let attr {.inject.} = h5attr[name, bool]
    actions
  of dkChar:
    let attr {.inject.} = h5attr[name, char]
    actions
  of dkString:
    let attr {.inject.} = h5attr[name, string]
    actions
  of dkFloat32:
    let attr {.inject.} = h5attr[name, float32]
    actions
  of dkFloat64:
    let attr {.inject.} = h5attr[name, float64]
    actions
  of dkInt8:
    let attr {.inject.} = h5attr[name, int8]
    actions
  of dkInt16:
    let attr {.inject.} = h5attr[name, int16]
    actions
  of dkInt32:
    let attr {.inject.} = h5attr[name, int32]
    actions
  of dkInt64:
    let attr {.inject.} = h5attr[name, int64]
    actions
  of dkUint8:
    let attr {.inject.} = h5attr[name, uint8]
    actions
  of dkUint16:
    let attr {.inject.} = h5attr[name, uint16]
    actions
  of dkUint32:
    let attr {.inject.} = h5attr[name, uint32]
    actions
  of dkUint64:
    let attr {.inject.} = h5attr[name, uint64]
    actions
  of dkSequence:
    # need to perform same game again...
    case h5attr.attr_tab[name].dtypeBaseKind
    of dkString:
      let attr {.inject.} = h5attr[name, seq[string]]
      actions
    of dkFloat32:
      let attr {.inject.} = h5attr[name, seq[float32]]
      actions
    of dkFloat64:
      let attr {.inject.} = h5attr[name, seq[float64]]
      actions
    of dkInt8:
      let attr {.inject.} = h5attr[name, seq[int8]]
      actions
    of dkInt16:
      let attr {.inject.} = h5attr[name, seq[int16]]
      actions
    of dkInt32:
      let attr {.inject.} = h5attr[name, seq[int32]]
      actions
    of dkInt64:
      let attr {.inject.} = h5attr[name, seq[int64]]
      actions
    of dkUint8:
      let attr {.inject.} = h5attr[name, seq[uint8]]
      actions
    of dkUint16:
      let attr {.inject.} = h5attr[name, seq[uint16]]
      actions
    of dkUint32:
      let attr {.inject.} = h5attr[name, seq[uint32]]
      actions
    of dkUint64:
      let attr {.inject.} = h5attr[name, seq[uint64]]
      actions
    else:
      echo "Seq type of ", h5attr.attr_tab[name].dtypeBaseKind, " not supported"
  else:
    echo "Attribute of dtype ", h5attr.attr_tab[name].dtypeAnyKind, " not supported"
    discard

proc copy_attributes*[T: H5Group | H5DataSet](h5o: T, attrs: H5Attributes) =
  ## copies the attributes contained in `attrs` given to the function to the `h5o` attributes
  ## this can be used to copy attributes also between different files
  # simply walk over all key value pairs in the given attributes and
  # write them as new attributes to `h5o`
  attrs.read_all_attributes()
  for key, value in pairs(attrs.attr_tab):
    # TODO: fix it using H5Ocopy instead!
    # IMPORTANT!!!!
    # let ocpypl_id = H5Pcreate(H5P_OBJECT_COPY)
    # let lcpl_id = H5Pcreate(H5P_LINK_CREATE)
    # H5Ocopy(value.attr_id, key, h5o.attrs.parent_id, key, ocpypl_id, lcpl_id)
    attrs.withAttr(key):
      # use injected read attribute value to write it
      h5o.attrs[key] = attr
    # close attr again to avoid memory leaking
    value.close()
