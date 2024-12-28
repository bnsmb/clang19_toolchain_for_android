#
# simple script to create a tar archive with the contents of /data/local/tmp/sysroot
#
# If called with the parameter "release" the script removes all tempoary files and config files before creating the tar archive
#
# For more details, see the source code below
#

CLANG_VERSION=19

# BASE_DIR="/data/local/tmp/"
# SYSROOT_DIR="${BASE_DIR}/sysroot"

SYSROOT_DIR="${0%/*}"
BASE_DIR="$( cd "${SYSROOT_DIR}/.." ; pwd )"

if [ $# -eq 1 -a -d $1 ] ; then

  TARGET_DIR="$1"
  shift

elif [ "${TARGET_DIR}"x = ""x ] ; then
  TARGET_DIR="${BASE_DIR}"
fi

TAR_FILE_HIST_LINE="$( grep "/bs" ${SYSROOT_DIR}/README |  tail -1  )"

TAR_FILE_VERSION="$( echo "${TAR_FILE_HIST_LINE}" | awk '{ print $2 }' )"
TAR_FILE_TIMESTAMP="$( echo "${TAR_FILE_HIST_LINE}" | awk '{ print $1 }' )"


if [ "$1"x = "release"x ] ; then
  POSTFIX="_release_${TAR_FILE_TIMESTAMP}_"
  
  ${SYSROOT_DIR}/clean_env.sh -x

elif [ $# -ne 0 ] ; then
  POSTFIX="_$( date +%Y-%m-%d )_$( echo $* | tr " " "_" )_"
else
  POSTFIX="_$( date +%Y-%m-%d_%s )"
fi

TAR_FILE_NAME="clang${CLANG_VERSION}_toolchain-${TAR_FILE_VERSION}${POSTFIX}.tar.gz"

TAR_FILE="${TARGET_DIR}/${TAR_FILE_NAME}" ;

echo "Creating the tar file \"${TAR_FILE}\" ..."


cd ${BASE_DIR} && ${PREFIX} tar -cf ${TAR_FILE} sysroot ; ls -l ${TAR_FILE}  


