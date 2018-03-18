# Package

version       = "0.2.6"
author        = "Sebastian Schmidt"
description   = "A wrapper for the HDF5 data format C library"
license       = "MIT"
srcDir        = "src"
skipDirs      = @["examples, c_headers"]
skipExt       = @["nim~"]

# Dependencies

requires "nim >= 0.17.2"
requires "arraymancer >= 0.2.0"

task test, "Runs all tests":
  exec "nim c -r tests/tbasic.nim"
  exec "nim c -r tests/tdset.nim"
  exec "nim c -r tests/tattributes.nim"
  exec "nim c -r tests/tvlen_array.nim"
  exec "nim c -r tests/tresize.nim"
  exec "nim c -r tests/tnested.nim"
