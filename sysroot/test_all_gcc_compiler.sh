#!/system/bin/sh

TOOLCHAIN_DIR="${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain"

API_LIST=$( ls  ${TOOLCHAIN_DIR}/aarch64-unknown-linux-android*-gcc | sed "s/.*-android//g" | cut -f1 -d "-" | tr "\n" " "  )

for i in ${API_LIST} ; do
  echo 
  echo "Testing ${TOOLCHAIN_DIR}/aarch64-unknown-linux-android${i}-gcc ..."
  ${TOOLCHAIN_DIR}/aarch64-unknown-linux-android${i}-gcc -o helloworld_in_c_with_gcc_$i helloworld_in_c.c  && \
     file ./helloworld_in_c_with_gcc_$i  && \
     ./helloworld_in_c_with_gcc_$i
done
echo

