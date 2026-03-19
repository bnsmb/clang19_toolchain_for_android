mkdir -p /data/local/tmp/develop/cmake_test
cd /data/local/tmp/develop/cmake_test

rm -rf *

cd /data/local/tmp/develop/cmake_test

cat > config_full.json << 'EOF'
{
  "name": "cmake-json-advanced",
  "version": 2,
  "enabled": true,
  "threshold": 0.75,
  "features": [
    "android",
    "clang",
    "json"
  ],
  "meta": {
    "author": "Bernd",
    "tags": ["test", "cmake", "json"]
  }
}
EOF


cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 4.3)
project(cmake_json_advanced LANGUAGES C)

file(READ "${CMAKE_SOURCE_DIR}/config_full.json" JSON_CONTENT)

# Grundlegende GETs
string(JSON J_NAME      GET    "${JSON_CONTENT}" name)
string(JSON J_VERSION   GET    "${JSON_CONTENT}" version)
string(JSON J_ENABLED   GET    "${JSON_CONTENT}" enabled)
string(JSON J_THRESHOLD GET    "${JSON_CONTENT}" threshold)

message(STATUS "name      = ${J_NAME}")
message(STATUS "version   = ${J_VERSION}")
message(STATUS "enabled   = ${J_ENABLED}")
message(STATUS "threshold = ${J_THRESHOLD}")

# TYPE und LENGTH
string(JSON TYPE_NAME      TYPE   "${JSON_CONTENT}" name)
string(JSON TYPE_FEATURES  TYPE   "${JSON_CONTENT}" features)
string(JSON TYPE_META      TYPE   "${JSON_CONTENT}" meta)
string(JSON LEN_FEATURES   LENGTH "${JSON_CONTENT}" features)
string(JSON LEN_META_TAGS  LENGTH "${JSON_CONTENT}" meta tags)

message(STATUS "TYPE(name)     = ${TYPE_NAME}")
message(STATUS "TYPE(features) = ${TYPE_FEATURES}, length = ${LEN_FEATURES}")
message(STATUS "TYPE(meta)     = ${TYPE_META}, meta.tags length = ${LEN_META_TAGS}")

# Array-Iteration
math(EXPR FEATURES_LAST_IDX "${LEN_FEATURES} - 1")
foreach(i RANGE ${FEATURES_LAST_IDX})
  string(JSON FEATURE_i GET "${JSON_CONTENT}" features ${i})
  message(STATUS "features[${i}] = ${FEATURE_i}")
endforeach()

math(EXPR TAGS_LAST_IDX "${LEN_META_TAGS} - 1")
foreach(i RANGE ${TAGS_LAST_IDX})
  string(JSON TAG_i GET "${JSON_CONTENT}" meta tags ${i})
  message(STATUS "meta.tags[${i}] = ${TAG_i}")
endforeach()

# SET: neues Feld hinzufügen und Array erweitern
set(J_MOD "${JSON_CONTENT}")

# neues Feld meta.revision setzen
string(JSON J_MOD SET "${J_MOD}" meta revision 1)
# features-Array um "advanced" erweitern (Index >= length)
string(JSON J_MOD SET "${J_MOD}" features 100 "\"advanced\"")

message(STATUS "Modified JSON:")
message(STATUS "${J_MOD}")

# EQUAL: Vergleich Original vs. modifiziert
string(JSON J_EQ EQUAL "${JSON_CONTENT}" "${J_MOD}")
message(STATUS "Original == Modified ? ${J_EQ}")

# Fehlerbehandlung
string(JSON DUMMY_GET ERROR_VARIABLE J_ERR GET "${JSON_CONTENT}" does_not_exist)
if(J_ERR)
  message(STATUS "Expected error (missing key): ${J_ERR}")
endif()

# Member-Namen des meta-Objekts ausgeben
string(JSON META_LEN LENGTH "${JSON_CONTENT}" meta)
math(EXPR META_LAST_IDX "${META_LEN} - 1")
foreach(i RANGE ${META_LAST_IDX})
  string(JSON META_KEY MEMBER "${JSON_CONTENT}" meta ${i})
  message(STATUS "meta member[${i}] = ${META_KEY}")
endforeach()

# REMOVE: revision aus dem modifizierten JSON wieder entfernen
string(JSON J_MOD2 REMOVE "${J_MOD}" meta revision)
message(STATUS "After REMOVE(meta.revision):")
message(STATUS "${J_MOD2}")

# STRING_ENCODE: einen beliebigen String sicher als JSON-String erzeugen
string(JSON QUOTED STRING_ENCODE "Bernd \"CMake\" \\ test")
message(STATUS "STRING_ENCODE = ${QUOTED}")


# Dummy-Target
add_executable(dummy main.c)
EOF


cat > main.c << 'EOF'
#include <stdio.h>
int main(void) {
    printf("cmake json advanced test\n");
    return 0;
}
EOF

cd /data/local/tmp/develop/cmake_test
rm -rf build
mkdir build
cd build

cmake ..
cmake --build .


echo
echo "Check the result:"
echo "----------------"
set -x
/data/local/tmp/develop/cmake_test/build/dummy
echo 
ls -l /data/local/tmp/develop/cmake_test/build/dummy
echo
file /data/local/tmp/develop/cmake_test/build/dummy
echo
ldd /data/local/tmp/develop/cmake_test/build/dummy
echo
set +x


