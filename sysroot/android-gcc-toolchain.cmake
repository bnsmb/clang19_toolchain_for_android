# Toolchain-Datei für AmanoTeam android-gcc-cross
# Ziel: aarch64, API-Level aus Umgebungsvariable API (Fallback: 24)

# --- API-Level bestimmen ---
if(DEFINED ENV{API} AND NOT "$ENV{API}" STREQUAL "")
    set(ANDROID_API_LEVEL "$ENV{API}")
else()
    set(ANDROID_API_LEVEL "24")
endif()

message(STATUS "android-gcc-toolchain: API-Level = ${ANDROID_API_LEVEL}")

# --- Toolchain-Wurzel ---
set(TOOLCHAIN_ROOT "/data/local/tmp/sysroot/usr/lib/android-gcc-cross")

# API-spezifischer Triple, z. B. aarch64-unknown-linux-android24
set(TOOLCHAIN_TRIPLE "aarch64-unknown-linux-android${ANDROID_API_LEVEL}")

# Sysroot-Pfad (für --sysroot und -I)
set(TOOLCHAIN_SYSROOT "${TOOLCHAIN_ROOT}/${TOOLCHAIN_TRIPLE}")

# --- System ---
set(CMAKE_SYSTEM_NAME      Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# CMAKE_SYSROOT bewusst NICHT setzen: triggert die Android-Erkennung von
# CMake. Stattdessen --sysroot als Compiler-Flag.

# --- Compiler und Binutils (API-spezifische Wrapper) ---
set(CMAKE_C_COMPILER   "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_TRIPLE}-gcc")
set(CMAKE_CXX_COMPILER "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_TRIPLE}-g++")
set(CMAKE_ASM_COMPILER "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_TRIPLE}-gcc")
set(CMAKE_AR           "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_TRIPLE}-ar")
set(CMAKE_RANLIB       "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_TRIPLE}-ranlib")
set(CMAKE_STRIP        "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_TRIPLE}-strip")
set(CMAKE_LINKER       "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_TRIPLE}-ld")
set(CMAKE_NM           "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_TRIPLE}-nm")
set(CMAKE_OBJCOPY      "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_TRIPLE}-objcopy")
set(CMAKE_OBJDUMP      "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_TRIPLE}-objdump")

# --- Suchmodus ---
# Programme im Host suchen, Libs/Includes nur im Toolchain-Sysroot und in
# den zusätzlichen Abhängigkeiten.
# Wichtig: NICHT /data/local/tmp/sysroot/usr eintragen, sonst wird die dort
# liegende Clang-api-level.h gefunden.
set(CMAKE_FIND_ROOT_PATH
    "${TOOLCHAIN_ROOT}"
    "/data/local/tmp/develop/sysroot/usr")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# --- Compiler-Flags ---
# --sysroot setzt das Sysroot für Header und Libs. -I stellt den
# Toolchain-Include voran, damit die richtige api-level.h gefunden wird.
set(CMAKE_C_FLAGS_INIT
    "-I${TOOLCHAIN_ROOT}/include --sysroot=${TOOLCHAIN_ROOT}")
set(CMAKE_CXX_FLAGS_INIT
    "-I${TOOLCHAIN_ROOT}/include --sysroot=${TOOLCHAIN_ROOT}")

# --- C++-Standard ---
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# --- Laufzeit-Linker-Pfad für während des Builds aufgerufene Tools ---
# (as/ld brauchen ggf. libz.so aus dem Toolchain-lib-Verzeichnis)
set(ENV{LD_LIBRARY_PATH} "${TOOLCHAIN_ROOT}/lib:$ENV{LD_LIBRARY_PATH}")

