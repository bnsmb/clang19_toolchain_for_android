# Toolchain file for AmanoTeam android-gcc-cross
# Target: aarch64, API level taken from environment variable API (fallback: 24)

# --- Determine API level ---
if(DEFINED ENV{API} AND NOT "$ENV{API}" STREQUAL "")
    set(ANDROID_API_LEVEL "$ENV{API}")
else()
    set(ANDROID_API_LEVEL "24")
endif()

message(STATUS "android-gcc-toolchain: API level = ${ANDROID_API_LEVEL}")

# --- Toolchain root ---
set(TOOLCHAIN_ROOT "/data/local/tmp/sysroot/usr/lib/android-gcc-cross")

# Compiler wrappers carry the API suffix (e.g. ...android24-gcc)
set(TOOLCHAIN_COMPILER_TRIPLE "aarch64-unknown-linux-android${ANDROID_API_LEVEL}")

# Binutils are API-independent and have no API suffix
set(TOOLCHAIN_BINUTILS_TRIPLE "aarch64-unknown-linux-android")

# Path to the API-specific sysroot (headers/libs)
set(TOOLCHAIN_SYSROOT "${TOOLCHAIN_ROOT}/${TOOLCHAIN_COMPILER_TRIPLE}")

# --- System ---
set(CMAKE_SYSTEM_NAME      Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# CMAKE_SYSROOT is deliberately NOT set: it triggers CMake's Android
# detection logic, which expects an NDK-style directory layout and would
# look for /include/android/api-level.h with a broken prefix.
# Instead, --sysroot is passed as a compiler flag below.

# --- Compilers (API-specific wrappers) ---
set(CMAKE_C_COMPILER   "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_COMPILER_TRIPLE}-gcc")
set(CMAKE_CXX_COMPILER "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_COMPILER_TRIPLE}-g++")
set(CMAKE_ASM_COMPILER "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_COMPILER_TRIPLE}-gcc")

# --- Binutils (API-independent, no API suffix in the filename) ---
# Note: the API-specific binutils wrappers do NOT exist in the AmanoTeam
# toolchain. Only the generic ones like aarch64-unknown-linux-android-ar
# are provided, because ar/ld/nm/strip/objcopy/objdump are pure host tools
# that operate on object files regardless of the target API level.
set(CMAKE_AR           "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_BINUTILS_TRIPLE}-ar")
set(CMAKE_RANLIB       "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_BINUTILS_TRIPLE}-ranlib")
set(CMAKE_STRIP        "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_BINUTILS_TRIPLE}-strip")
set(CMAKE_LINKER       "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_BINUTILS_TRIPLE}-ld")
set(CMAKE_NM           "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_BINUTILS_TRIPLE}-nm")
set(CMAKE_OBJCOPY      "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_BINUTILS_TRIPLE}-objcopy")
set(CMAKE_OBJDUMP      "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_BINUTILS_TRIPLE}-objdump")

# If you plan to use LTO (-flto), use the GCC driver wrappers instead.
# They invoke the real ar/ranlib/nm and add the required LTO plugin flags:
#
# set(CMAKE_AR     "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_BINUTILS_TRIPLE}-gcc-ar")
# set(CMAKE_RANLIB "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_BINUTILS_TRIPLE}-gcc-ranlib")
# set(CMAKE_NM     "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_BINUTILS_TRIPLE}-gcc-nm")

# --- Search mode ---
# Programs (cmake, make, ...) are searched on the host, libraries and
# headers only in the toolchain sysroot and in the additional dependencies.
#
# Important: do NOT add /data/local/tmp/sysroot/usr here, otherwise the
# Clang api-level.h located there would be picked up instead of the GCC one.
set(CMAKE_FIND_ROOT_PATH
    "${TOOLCHAIN_ROOT}"
    "/data/local/tmp/develop/sysroot/usr")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# --- Compiler flags ---
# --sysroot sets the sysroot for headers and libraries.
# -I prepends the toolchain include directory so that the correct
# api-level.h (from the GCC sysroot) is found first.
set(CMAKE_C_FLAGS_INIT
    "-I${TOOLCHAIN_ROOT}/include --sysroot=${TOOLCHAIN_ROOT}")
set(CMAKE_CXX_FLAGS_INIT
    "-I${TOOLCHAIN_ROOT}/include --sysroot=${TOOLCHAIN_ROOT}")

# --- C++ standard ---
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# --- Runtime linker path for tools invoked during the build ---
# (as/ld may need libz.so from the toolchain lib directory)
set(ENV{LD_LIBRARY_PATH} "${TOOLCHAIN_ROOT}/lib:$ENV{LD_LIBRARY_PATH}"
)
