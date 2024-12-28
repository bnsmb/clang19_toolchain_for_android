#
# simple script to create a tar archive with the contents of  the directory sysroot
#
# If called with the parameter "release" the script removes all tempoary files and config files before creating the tar archive
#
# For more details, see the source code below
#
#
#

SYSROOT_DIR="${0%/*}"
BASE_DIR="$( cd "${SYSROOT_DIR}/.." ; pwd )"

if [ "$1"x = "-h"x -o "$1"x = "--help"x ] ; then
  echo "Usage: $0 [target_dir_for_the_tar_file] [tar_file_descriptions]"
  echo "The default target directory is ${BASE_DIR}"
  exit 5
fi


CLANG_VERSION=19

if [ $# -ge 1 -a -d $1 ] ; then

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


