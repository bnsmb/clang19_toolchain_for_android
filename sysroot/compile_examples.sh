if [ "${CLANG_SYSROOT}"x = ""x ] ; then
  echo "Please init the clang19 toolchain before executing this script"
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

echo 

