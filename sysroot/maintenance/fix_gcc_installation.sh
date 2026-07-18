
echo
echo "$0 - fix the gcc installation for the clang19 toolchain ..."

if [ "${CLANG_SYSROOT}"x = ""x ] ; then
	if [ $( uname -m )x = "aarch64"x ] ; then
		echo "*** Running on the phone"
		CLANG_SYSROOT="/data/local/tmp/sysroot"
	else
		echo "*** Running on the PC"
		CLANG_SYSROOT="/data/develop/git_repos/clang19_toolchain_for_android/sysroot"
	fi
fi

echo "Processing the files in \"${CLANG_SYSROOT}\" (the command prefix (variable CMD_PREFIX) is \"${CMD_PREFIX}\")"
echo "Press return to continue"
read USER_INPUT

if [ ! -d "${CLANG_SYSROOT}" ] ; then
	echo "ERROR: The directory \"${CLANG_SYSROOT}\" does not exist"
	exit 10
fi


if [ ! -r  ${CLANG_SYSROOT}/maintenance/gcc_tool_wrapper ] ; then
        echo "ERROR: The script  ${CLANG_SYSROOT}/maintenance/gcc_tool_wrapper is missing"
        exit 20
fi

set -x

${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/bin/armv7*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/bin/x86_64-unknown-linux-android*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/bin/i686-unknown-linux-android*

${CMD_PREFIX} rm -rf ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/x86_64-unknown-linux-android*
${CMD_PREFIX} rm -rf ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/i686-unknown-linux-android*
${CMD_PREFIX} rm -rf ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/armv7-unknown-linux-android*

${CMD_PREFIX} rm -rf ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/lib/gcc/armv7-unknown-linux-androideabi
${CMD_PREFIX} rm -rf ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/lib/gcc/i686-unknown-linux-android
${CMD_PREFIX} rm -rf ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/lib/gcc/x86_64-unknown-linux-android

${CMD_PREFIX} rm -rf ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/lib/gcc/lib/linux/x86_64
${CMD_PREFIX} rm -rf ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/lib/gcc/lib/linux/i386
${CMD_PREFIX} rm -rf ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/lib/gcc/lib/linux/arm

${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/armv7-unknown-linux-androideabi*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/x86_64-unknown-linux-android*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/i686-unknown-linux-android*

${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/usr/local/share/android-gcc-cross/autotools/i686-*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/usr/local/share/android-gcc-cross/autotools/armv5-*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/usr/local/share/android-gcc-cross/autotools/armv7-*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/usr/local/share/android-gcc-cross/autotools/mipsel-*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/usr/local/share/android-gcc-cross/autotools/mips64el-*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/usr/local/share/android-gcc-cross/autotools/riscv64-*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/usr/local/share/android-gcc-cross/autotools/x86_64-*

${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/usr/local/share/android-gcc-cross/cmake/i686*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/usr/local/share/android-gcc-cross/cmake/armv5*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/usr/local/share/android-gcc-cross/cmake/armv7*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/usr/local/share/android-gcc-cross/cmake/mipsel*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/usr/local/share/android-gcc-cross/cmake/mips64el*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/usr/local/share/android-gcc-cross/cmake/riscv64*
${CMD_PREFIX} rm -f ${CLANG_SYSROOT}/usr/lib/android-gcc-cross/usr/local/share/android-gcc-cross/cmake/x86_64*


${CMD_PREFIX} chmod 755 ${CLANG_SYSROOT}/maintenance/gcc_tool_wrapper
${CMD_PREFIX} cp ${CLANG_SYSROOT}/maintenance/gcc_tool_wrapper ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/gcc_tool_wrapper

cd ${CLANG_SYSROOT}/usr/gcc/bin/gcc-toolchain/
if [ $? -eq 0 ] ; then
	set +x 
	for i  in $( ls | grep -v "android[0-9[0-9]" ) ; do 
		[ "$i"x = "gcc_tool_wrapper"x ] && continue

		echo "Creating a symbolic link for \"$i\" ..."
		( ${CMD_PREFIX} rm $i && ${CMD_PREFIX} ln -s ./gcc_tool_wrapper ./$i )
	done
fi

