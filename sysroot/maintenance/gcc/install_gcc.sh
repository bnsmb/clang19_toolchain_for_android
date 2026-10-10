#h#
#h# install_gcc.sh - shell script to install the gcc toolchain from https://github.com/AmanoTeam/android-gcc-cross on Android
#h#
#h# Usage:  ./install_gcc.sh
#h# 
#h# The target directory for the installation is defined in the variable GCC_INSTALL_DIR
#h# The target directory for the symbolic links is defined in the variable TOOLCHAIN_LINK_DIRECTORY
#h#
#h# To change the target directories, modify the values for the variable in the script
#
# History
#  08.10.2026 v1.0.0 /bs
#    initial release
#
# Note:
#
# set the environment variable CMD_PREFIX to "echo" before starting this script to run it in dry-run ode
#

if [ "$1"x = "-h"x -o "$1"x = "--help"x ] ; then
  grep "^#h#" $0 | cut -c4- 
  echo "
The current value for these variables is

$(  grep -E "^GCC_INSTALL_DIR=|^TOOLCHAIN_LINK_DIRECTORY=" $0 )

"
  exit 0
fi

echo
echo "*** Installing the GCC ..."
echo

GCC_INSTALL_SCRIPT="/data/local/tmp/gcc-install.sh"

GCC_INSTALL_DIR="/system/lib/android-gcc-cross"

TOOLCHAIN_LINK_DIRECTORY="/system//bin/gcc-toolchain/"

WRAPPER_SCRIPTS="gcc g++ cc c++"

BASH="$( which bash )"
if [ "${BASH}"x = ""x ] ; then
  echo "ERROR: bash binary not found in the PATH"
  exit 1 
fi

XZ="$( which xz )"
if [ "${XZ}"x = ""x ] ; then
  echo "ERROR: xz binary not found in the PATH"
  exit 3
fi

CURL="$( which curl )"
if [ "${CURL}"x = ""x ] ; then
  echo "ERROR: curl binary not found in the PATH"
  exit 3
fi


echo "*** Downloading the intstall script for the GCC toolchain ..."

${CMD_PREFIX} ${CURL} https://cdn.jsdelivr.net/gh/AmanoTeam/android-gcc-cross@master/tools/termux-install.sh -o "${GCC_INSTALL_SCRIPT}"

if [ ! -r "${GCC_INSTALL_SCRIPT}" ] ; then
  echo "ERROR: Downloading the install script to \"${GCC_INSTALL_SCRIPT}\" failed"
  exit 4
fi

echo "*** Modifying the install script  \"${GCC_INSTALL_SCRIPT}\" ..."

${CMD_PREFIX} sed -i -e "s/--symbolic/-s/g" -e "s/--force/-f/g" -e "s/--recursive/-r/g" "${GCC_INSTALL_SCRIPT}"
${CMD_PREFIX} sed -i -e "s#/data/data/com.termux/files/usr/bin/bash#${BASH}#g"  "${GCC_INSTALL_SCRIPT}"
${CMD_PREFIX} sed -i -e "s#/data/data/com.termux/files/usr/lib/android-gcc-cross#${GCC_INSTALL_DIR}#g" "${GCC_INSTALL_SCRIPT}"

# do not delete the tar file with the gcc toolchain after unpacking it
#
${CMD_PREFIX} sed -i -e 's|unlink "${pino_tarball}"|# unlink "${pino_tarball}"|g' "${GCC_INSTALL_SCRIPT}"

# do not download the tar file with the gcc toolchain if the file already exists
#
${CMD_PREFIX} sed -i -e 's#^curl # /system/bin/test -r  "${pino_tarball}" \|\| curl #'  "${GCC_INSTALL_SCRIPT}"

# create the symbolic links in /system/bin
#
export PREFIX=/system/

# use a writable home directory for the installation
# 
export HOME=/data/local/tmp/gcc
${CMD_PREFIX} mkdir -p "${HOME}"

echo "*** Executing the install script  \"${GCC_INSTALL_SCRIPT}\" ..."

${CMD_PREFIX} chmod 755 "${GCC_INSTALL_SCRIPT}"
( export LD_LIBRARY_PATH=/system/lib64 ; ${CMD_PREFIX} cd / && ${CMD_PREFIX} "${GCC_INSTALL_SCRIPT}" )

echo 

echo "*** Post processing the installation ...."

if [ ! -d "${TOOLCHAIN_LINK_DIRECTORY}" ] ; then
  echo "ERROR: Something went wrong installing the GCC toolchain - the directory \"${TOOLCHAIN_LINK_DIRECTORY}\" does not exist"
  exit 10
fi

cd "${TOOLCHAIN_LINK_DIRECTORY}" 

chmod 755 ${WRAPPER_SCRIPTS}
LINK_SUBDIR="${PWD##*/}"
cd ..
echo "*** Creating the symbolic links for the scripts \"${WRAPPER_SCRIPTS}\" in ${PWD} ..."
for CUR_SCRIPT in ${WRAPPER_SCRIPTS} ; do
  ln -s "${LINK_SUBDIR}/${CUR_SCRIPT}" .
done

echo "*** Correct the owner and SELinux contexts for the files in \"${GCC_INSTALL_DIR}\"..."

chown -R root:root "${GCC_INSTALL_DIR}" 
chcon -R u:object_r:system_file:s0 "${GCC_INSTALL_DIR}" 

echo "*** Testing the installation ..."

gcc  --version
THISRC=$?

case ${THISRC} in
  0 )
    echo "*** The installation ssems to be okay"
    ;;

  * )
   echo "ERROR: Unknown error executing gcc -- the RC is ${THISRC}"
   exit 100
   ;;
esac

