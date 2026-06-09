for i in 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 ; do  
  echo 
  echo "Testing ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/aarch64-unknown-linux-android${i}-gcc ..."
  ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/aarch64-unknown-linux-android${i}-gcc -o helloworld_in_c_with_gcc_$i helloworld_in_c.c  && \
     file ./helloworld_in_c_with_gcc_$i  && \
     ./helloworld_in_c_with_gcc_$i
done
echo

