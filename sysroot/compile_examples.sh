if [ "${CLANG_SYSROOT}"x = ""x ] ; then
  echo "Please init the clang19 toolchain before executing this script using the command: \"source /data/local/tmp/sysroot/bin/init_clang19_env\" "
  exit 100
fi


SOURCEDIR="./examples"

OUTDIR="$PWD/out"
mkdir -p "${OUTDIR}"
if [ $? -ne 0 ] ; then
  echo "ERROR: Can not create the directory \"${OUTDIR}\" "
  exit 7
fi

if [ ! -d "${SOURCEDIR}" ] ; then
 echo "ERROR: The directory \"${SOURCEDIR}\" does not exist"
 exit 9
fi


echo 
echo "*** Testing the compiler \"clang\" ...."
echo
cd ${CLANG_SYSROOT}
clang ${CFLAGS} ${LDFLAGS} -D__ANDROID_API__=$API -o ${OUTDIR}/helloworld_in_c ${SOURCEDIR}/helloworld_in_c.c  && ${OUTDIR}/helloworld_in_c


echo
echo "*** Testing the compiler \"clang++\" ..."
echo
cd ${CLANG_SYSROOT}
clang++ ${CPPFLAGS} ${LDFLAGS} -D__ANDROID_API__=$API -o ${OUTDIR}/helloworld_in_c++ ${SOURCEDIR}/helloworld_in_c++.cpp && ${OUTDIR}/helloworld_in_c++

echo
echo "*** Testing the assembler from clang ..."
echo
cd ${CLANG_SYSROOT}
clang -nostdlib -static -Wl,--entry=_start -o ${OUTDIR}/helloworld_in_assembler ${SOURCEDIR}/helloworld_in_assembler.s && ${OUTDIR}/helloworld_in_assembler

echo
echo "*** Testing the assembler from the binutils ..."
echo
cd ${CLANG_SYSROOT}
${CLANG_SYSROOT}/usr/bin/as -o ${OUTDIR}/helloworld_in_assembler_for_as.o ${SOURCEDIR}/helloworld_in_assembler_for_as.s && \
  ${CLANG_SYSROOT}//usr/bin/ld -o ${OUTDIR}/helloworld_in_assembler_for_as ${OUTDIR}/helloworld_in_assembler_for_as.o && \
  ${OUTDIR}/helloworld_in_assembler_for_as

if [ -x ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/gcc ] ; then
  echo
  echo "*** Testing the compiler \"gcc\" ..."
  echo
  ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/gcc -o ${OUTDIR}/helloworld_in_c_with_gcc ${SOURCEDIR}/helloworld_in_c.c  && ${OUTDIR}/helloworld_in_c_with_gcc
fi

if [ -x ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/g++ ] ; then
  echo
  echo "*** Testing the compiler \"g++\" ..."
  echo
  ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/g++   -o ${OUTDIR}/helloworld_in_c++_with_g++  ${SOURCEDIR}/helloworld_in_c++.cpp && ${OUTDIR}/helloworld_in_c++_with_g++
fi


echo
echo "*** Note: The object files and binaries are in the directory \"${OUTDIR}\" "
echo

