for i in 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 ; do  
  echo
  echo "*** Testing ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/aarch64-unknown-linux-android${i}-g++ ..."

  ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/aarch64-unknown-linux-android${i}-g++  -o helloworld_in_c++_with_g++_$i ./helloworld_in_c++.cpp && \
     file ./helloworld_in_c++_with_g++_$i && \
     ./helloworld_in_c++_with_g++_$i 
done
