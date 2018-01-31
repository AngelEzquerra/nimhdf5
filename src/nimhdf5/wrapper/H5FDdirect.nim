##  * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
##  Copyright by The HDF Group.                                               *
##  Copyright by the Board of Trustees of the University of Illinois.         *
##  All rights reserved.                                                      *
##                                                                            *
##  This file is part of HDF5.  The full HDF5 copyright notice, including     *
##  terms governing use, modification, and redistribution, is contained in    *
##  the COPYING file, which can be found at the root of the source code       *
##  distribution tree, or in https://support.hdfgroup.org/ftp/HDF5/releases.  *
##  If you do not have access to either file, you may request a copy from     *
##  help@hdfgroup.org.                                                        *
##  * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

{.deadCodeElim: on.}
when not declared(libname):
  when defined(Windows):
    const
      libname* = "hdf5.dll"
  elif defined(MacOSX):
    const
      libname* = "libhdf5.dylib"
  else:
    const
      libname* = "libhdf5.so"
## 
##  Programmer:  Raymond Lu <slu@hdfgroup.uiuc.edu>
##               Wednesday, 20 September 2006
## 
##  Purpose:	The public header file for the direct driver.
## 

when defined(H5_HAVE_DIRECT):
  const
    H5FD_DIRECT* = (H5FD_direct_init())
else:
  const
    H5FD_DIRECT* = (- 1)
when defined(H5_HAVE_DIRECT):
  ##  Default values for memory boundary, file block size, and maximal copy buffer size.
  ##  Application can set these values through the function H5Pset_fapl_direct.
  const
    MBOUNDARY_DEF* = 4096
    FBSIZE_DEF* = 4096
    CBSIZE_DEF* = 16 * 1024 * 1024
  proc H5FD_direct_init*(): hid_t {.cdecl, importc: "H5FD_direct_init",
                                 dynlib: libname.}
  proc H5Pset_fapl_direct*(fapl_id: hid_t; alignment: csize; block_size: csize;
                          cbuf_size: csize): herr_t {.cdecl,
      importc: "H5Pset_fapl_direct", dynlib: libname.}
  proc H5Pget_fapl_direct*(fapl_id: hid_t; boundary: ptr csize; ## out
                          block_size: ptr csize; ## out
                          cbuf_size: ptr csize): herr_t {.cdecl,
      importc: "H5Pget_fapl_direct", dynlib: libname.}
    ## out
