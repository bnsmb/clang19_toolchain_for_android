#!/system/bin/sh

TOOLCHAIN_DIR="${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain"

API_LIST=$( ls  ${TOOLCHAIN_DIR}/aarch64-unknown-linux-android*-g++ | sed "s/.*-android//g" | cut -f1 -d "-" | tr "\n" " "  )


for i in ${API_LIST} ;  do
  echo
  echo "*** Testing ${TOOLCHAIN_DIR}/aarch64-unknown-linux-android${i}-g++ ..."

  ${TOOLCHAIN_DIR}/aarch64-unknown-linux-android${i}-g++  -o helloworld_in_c++_with_g++_$i ./helloworld_in_c++.cpp && \
     file ./helloworld_in_c++_with_g++_$i && \
     ./helloworld_in_c++_with_g++_$i 
done
