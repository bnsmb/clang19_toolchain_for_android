if [ "${CLANG_SYSROOT}"x = ""x ] ; then
  echo "Please init the clang19 toolchain before executing this script using the command: \"source /data/local/tmp/sysroot/bin/init_clang19_env\" "
  exit 100
fi


echo 
echo "*** Testing the compiler \"clang\" ...."
echo
cd ${CLANG_SYSROOT}
clang ${CFLAGS} ${LDFLAGS} -o helloworld_in_c helloworld_in_c.c  && ./helloworld_in_c


echo
echo "*** Testing the compiler \"clang++\" ..."
echo
cd ${CLANG_SYSROOT}
clang++ ${CPPFLAGS} ${LDFLAGS}  -o helloworld_in_c++ ./helloworld_in_c++.cpp && ./helloworld_in_c++

echo
echo "*** Testing the assembler from clang ..."
echo
cd ${CLANG_SYSROOT}
clang -nostdlib -static -Wl,--entry=_start -o helloworld_in_assembler helloworld_in_assembler.s && ./helloworld_in_assembler

echo
echo "*** Testing the assembler from the binutils ..."
echo
cd ${CLANG_SYSROOT}
${CLANG_SYSROOT}/usr/bin/as -o helloworld_in_assembler_for_as.o helloworld_in_assembler_for_as.s && \
  ${CLANG_SYSROOT}//usr/bin/ld -o helloworld_in_assembler_for_as helloworld_in_assembler_for_as.o && \
  ./helloworld_in_assembler_for_as

if [ -x ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/gcc ] ; then
  echo
  echo "*** Testing the compiler \"gcc\" ..."
  echo
  ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/gcc -o helloworld_in_c_with_gcc helloworld_in_c.c  && ./helloworld_in_c_with_gcc
fi

if [ -x ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/g++ ] ; then
  echo
  echo "*** Testing the compiler \"gcc\" ..."
  echo
  ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/g++   -o helloworld_in_c++_with_gcc ./helloworld_in_c++.cpp && ./helloworld_in_c++_with_gcc
fi

echo
