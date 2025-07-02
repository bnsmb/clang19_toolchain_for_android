


SOURCE_DIR="/data/local/tmp"
cd "${SOURCE_DIR}"
if [ $? -eq 0 ] ; then
  TAR_FILE_VERSION="$( grep /bs sysroot/sshd_README  | awk '{ print $2}' | tail -1 )"

  TAR_FILE_NAME="openssh_10.0p2_v${TAR_FILE_VERSION}.tar.gz"
  TAR_FILE="/data/develop/android/${TAR_FILE_NAME}"

  echo "Creating the tar file \"${TAR_FILE}\" ..."

  tar -czf "${TAR_FILE}" ./sysroot

  echo
  ls -l "${TAR_FILE}"
fi

