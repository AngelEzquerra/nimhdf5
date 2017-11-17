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
## 
##  This is the main public HDF5 include file.  Put further information in
##  a particular header file and include that here, don't fill this file with
##  lots of gunk...
##


#[ NOTE: in a few files (H5Tpublic, H5Epublic and H5Ppublic) we need to define 
   several variables (regarding type ids), which can only be set after the HDF5
   library has been 'opened' (= initialized). Thus we include H5initialize 
   in these libraries, which (at the moment) simply calls the H5open() function
   which does exactly that. Then we can use the variables, like e.g.
   H5T_NATIVE_INTEGER 
   in the Nim progams as function arguments without getting any weird errors.
]#

include
  nim-hdf5/H5public, nim-hdf5/H5Apublic,        ##  Attributes
  nim-hdf5/H5ACpublic,                 ##  Metadata cache
  nim-hdf5/H5Dpublic,                  ##  Datasets
  nim-hdf5/H5Epublic,                  ##  Errors
  nim-hdf5/H5Fpublic,                  ##  Files
  nim-hdf5/H5FDpublic,                 ##  File drivers
  nim-hdf5/H5Gpublic,                  ##  Groups
  nim-hdf5/H5Ipublic,                  ##  ID management
  nim-hdf5/H5Lpublic,                  ##  Links
  nim-hdf5/H5MMpublic,                 ##  Memory management
  nim-hdf5/H5Opublic,                  ##  Object headers
  nim-hdf5/H5Ppublic,                  ##  Property lists
  nim-hdf5/H5PLpublic,                 ##  Plugins
  nim-hdf5/H5Rpublic,                  ##  References
  nim-hdf5/H5Spublic,                  ##  Dataspaces
  nim-hdf5/H5Tpublic,                  ##  Datatypes
  nim-hdf5/H5Zpublic

##  Data filters
##  Predefined file drivers

include
  nim-hdf5/H5FDcore,                   ##  Files stored entirely in memory
  nim-hdf5/H5FDdirect,                 ##  Linux direct I/O
  nim-hdf5/H5FDfamily,                 ##  File families
  nim-hdf5/H5FDlog,                    ##  sec2 driver with I/O logging (for debugging)
  nim-hdf5/H5FDmpi,                    ##  MPI-based file drivers
  nim-hdf5/H5FDmulti,                  ##  Usage-partitioned file family
  nim-hdf5/H5FDsec2,                   ##  POSIX unbuffered file I/O
  nim-hdf5/H5FDstdio

when defined(H5_HAVE_WINDOWS): ##  Standard C buffered I/O
  import
    H5FDwindows

  ##  Windows buffered I/O
