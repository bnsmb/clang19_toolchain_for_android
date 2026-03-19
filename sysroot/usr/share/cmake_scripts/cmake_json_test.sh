mkdir -p /data/local/tmp/develop/cmake_test
cd /data/local/tmp/develop/cmake_test

rm -rf *

cat > config.json << 'EOF'
{
  "name": "cmake-json-test",
  "version": "1.0",
  "features": [
    "android",
    "clang",
    "json"
  ]
}
EOF

cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 4.3)

project(cmake_json_test LANGUAGES C)

# JSON-Datei in Variable einlesen
file(READ "${CMAKE_SOURCE_DIR}/config.json" JSON_CONTENT)

# Name und Version auslesen
string(JSON PROJECT_NAME_JSON   GET "${JSON_CONTENT}" name)
string(JSON PROJECT_VERSION_JSON GET "${JSON_CONTENT}" version)

# Array-Länge bestimmen
string(JSON FEATURES_LEN LENGTH "${JSON_CONTENT}" features)
math(EXPR FEATURES_LAST_IDX "${FEATURES_LEN} - 1")

message(STATUS "JSON name    = ${PROJECT_NAME_JSON}")
message(STATUS "JSON version = ${PROJECT_VERSION_JSON}")
message(STATUS "JSON features:")

foreach(i RANGE ${FEATURES_LAST_IDX})
  string(JSON FEATURE_i GET "${JSON_CONTENT}" features ${i})
  message(STATUS "  feature[${i}] = ${FEATURE_i}")
endforeach()

# Kleines Dummy-Target, damit CMake etwas baut
add_executable(dummy main.c)
EOF

cat > main.c << 'EOF'
#include <stdio.h>
int main(void) {
    printf("cmake json test\n");
    return 0;
}
EOF

cd /data/local/tmp/develop/cmake_test
mkdir -p build
cd build

cmake ..      # benutzt dein CMake 4.3 für Android
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


