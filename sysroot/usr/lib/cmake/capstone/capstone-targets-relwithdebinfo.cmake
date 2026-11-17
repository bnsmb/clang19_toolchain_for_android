#----------------------------------------------------------------
# Generated CMake target import file for configuration "RelWithDebInfo".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "capstone::capstone_static" for configuration "RelWithDebInfo"
set_property(TARGET capstone::capstone_static APPEND PROPERTY IMPORTED_CONFIGURATIONS RELWITHDEBINFO)
set_target_properties(capstone::capstone_static PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELWITHDEBINFO "C"
  IMPORTED_LOCATION_RELWITHDEBINFO "${_IMPORT_PREFIX}/lib/libcapstone.a"
  )

list(APPEND _cmake_import_check_targets capstone::capstone_static )
list(APPEND _cmake_import_check_files_for_capstone::capstone_static "${_IMPORT_PREFIX}/lib/libcapstone.a" )

# Import target "capstone::cstool" for configuration "RelWithDebInfo"
set_property(TARGET capstone::cstool APPEND PROPERTY IMPORTED_CONFIGURATIONS RELWITHDEBINFO)
set_target_properties(capstone::cstool PROPERTIES
  IMPORTED_LOCATION_RELWITHDEBINFO "${_IMPORT_PREFIX}/bin/cstool"
  )

list(APPEND _cmake_import_check_targets capstone::cstool )
list(APPEND _cmake_import_check_files_for_capstone::cstool "${_IMPORT_PREFIX}/bin/cstool" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
