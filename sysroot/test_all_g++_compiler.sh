#!/system/bin/sh


# fix 17.07.2026 /bs:
#
LD_LIBRARY_PATH=/data/local/tmp/sysroot/usr/lib/android-gcc-cross/lib/:$LD_LIBRARY_PATH


TOOLCHAIN_DIR="${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain"

API_LIST=$( ls  ${TOOLCHAIN_DIR}/aarch64-unknown-linux-android*-g++ | sed "s/.*-android//g" | cut -f1 -d "-" | tr "\n" " "  )

if [ ! -r helloworld_in_c++.cpp ] ; then
  echo "ERROR: The source file \"helloworld_in_c++.cpp\" does not exist in the current directory"
  exit 5
fi

for i in ${API_LIST} ;  do
  echo
  echo "*** Testing ${TOOLCHAIN_DIR}/aarch64-unknown-linux-android${i}-g++ ..."

  ${TOOLCHAIN_DIR}/aarch64-unknown-linux-android${i}-g++  -o helloworld_in_c++_with_g++_$i ./helloworld_in_c++.cpp && \
     file ./helloworld_in_c++_with_g++_$i && \
     ./helloworld_in_c++_with_g++_$i 
done
