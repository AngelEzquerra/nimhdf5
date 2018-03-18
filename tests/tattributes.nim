
import nimhdf5
import ospaths
import os

const
  File = "tests/attrs.h5"
  GrpName = "group1"
  TimeStr = "21:19"     
  Counter = 128       
  SeqAttr = @[1, 2, 3, 4]

proc write_attrs(grp: var H5Group) =
  
  # # now write some attributes
  grp.attrs["Time"] = TimeStr
  grp.attrs["Counter"] = Counter
  grp.attrs["Seq"] = SeqAttr
  
proc assert_attrs(grp: var H5Group) =

  assert(grp.attrs["Time", string] == TimeStr)
  assert(grp.attrs["Counter", int] == Counter)
  assert(grp.attrs["Seq", seq[int]] == SeqAttr)
  assert(grp.attrs.parent_name == formatName(GrpName))
  assert(grp.attrs.parent_type == "H5Group")
  assert(grp.attrs.num_attrs == 3)

proc assert_delete(grp: var H5Group) =

  assert(grp.deleteAttribute("Time"))
  assert(grp.attrs.num_attrs == 2)
  assert(grp.deleteAttribute("Counter"))
  assert(grp.attrs.num_attrs == 1)
  assert(grp.deleteAttribute("Seq"))
  assert(grp.attrs.num_attrs == 0)  

when isMainModule:

  var
    h5f = H5file(File, "rw")
    grp = h5f.create_group(GrpName)
    err: herr_t

  grp.write_attrs
  grp.assert_attrs

  err = h5f.close()
  assert(err >= 0)

  # open again, again with write access to delete attributes again
  h5f = H5File(File, "rw")
  grp = h5f[GrpName.grp_str]
  # and check again
  grp.assert_attrs

  # delete an attribute
  grp.assert_delete

  err = h5f.close()
  assert(err >= 0)
  
  # clean up after ourselves  
  removeFile(File)