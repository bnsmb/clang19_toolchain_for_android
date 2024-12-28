#!/system/bin/sh
# 
# Script to configure the clang toolchain environment
# 
# Usage: create_clang_env.sh
#
# History
#   25.12.2024 1.0.0 /bs
#     initial release
#   28.12.2024 1.1.0 /bs
#     added code to unpack compressed files in the tar archive
#     some files are now compressed to get around the size limitation for files in github.com
#

CUR_ID="$( id -un )"

#
# define some constants
#
__TRUE=0
__FALSE=1


# ---------------------------------------------------------------------
# the variable TMPDIR is used by the /sytem/bin/sh to get the default directory for temporary files
#
export TMPDIR="${TMPDIR:=/data/local/tmp}"

# ---------------------------------------------------------------------

#
# variables for the script control flow and the script return code
#
THISRC=${__TRUE}
CONT=${__TRUE}

NDK="r27b"

SYSROOT_DIR="/data/local/tmp/sysroot"


BASE_HOME_DIR="${SYSROOT_DIR}/home"

HOME="${BASE_HOME_DIR}/${SSH_USER}"

TMP="${SYSROOT_DIR}/var/tmp"

PATH="$PATH:${SYSROOT_DIR}/usr/bin"

export PATH HOME TMP

# LD_LIBRARY_PATH is not necessary
# export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${SYSROOT_DIR}/usr/lib"


# ----------------------------------------------------------------------
#
# functions
#

# ----------------------------------------------------------------------
# LogMsgchmod
#
# function: write a message to STDOUT
#
# usage: LogMsg [message]
#
function LogMsg {
  typeset THISMSG="$*"

  echo "${THISMSG}"
}


# ----------------------------------------------------------------------
# LogError
#
# function: write a message prefixed with "ERROR:" to STDERR
#
# usage: LogError [message]
#
function LogError {
  typeset THISMSG="$*"

  LogMsg "ERROR: ${THISMSG}" >&2
}


# ----------------------------------------------------------------------
# LogWarning
#
# function: write a message prefixed with "WARNING:" to STDERR
#
# usage: LogWarning [message]
#
function LogWarning {
  typeset THISMSG="$*"

  LogMsg "WWARNING: ${THISMSG}" >&2
}

# ----------------------------------------------------------------------
# die
#
# function: print a message and end the script
#
# usage: die [script_exit_code] [message]
#
# the parameter "message" is optional; the script will add a leading "ERROR: "
# to the message if the script_exit_code is not zero
#
# returns: n/a
#
function die  {
  typeset THISRC=$1
  [ $# -ne 0 ] && shift
  typeset THISMSG="$*"

  if [ "${THISMSG}"x != ""x ] ; then
    if [ ${THISRC} != 0 ] ; then
      echo "ERROR: ${THISMSG} (RC=${THISRC})" >&2
    else
      echo "${THISMSG}"
    fi
  fi

  exit ${THISRC}
}

# ----------------------------------------------------------------------
# main function
#

if [ "$1"x = "-h"x -o "$1"x = "--help"x -o $# -gt 2 ] ; then
#
# extract the usage help from the script source
#
  eval HELPTEXT=\""$( grep "^#H#" $0 | cut -c4- )"\"
  echo "
${HELPTEXT}
"
  exit 1
fi


LogMsg ""
LogMsg "Initializing the clang environment in ${SYSROOT_DIR} ..."
LogMsg ""


# ----------------------------------------------------------------------
# check if root access is enabled
#

  ROOT_ACCESS_AVAILABLE=${__FALSE}
  ROOT_PREFIX=""
  
  CUR_USER="$( id -un )"

  if [ "${CUR_USER}"x = "root"x ] ; then
    ROOT_ACCESS_AVAILABLE=${__TRUE}
  else 
    su - -c id 2>/dev/null 1>/dev/null 
    if [ $? -eq 0 ] ; then
      ROOT_ACCESS_AVAILABLE=${__TRUE}
      ROOT_PREFIX="su - -c "
    fi
  fi  

# ----------------------------------------------------------------------

CERTIFICATE_BUNDLE_FILE="${SYSROOT_DIR}/etc/security/ca-certificates.crt"

ls -l  ${SYSROOT_DIR}/etc/security/cacerts/* 2>/dev/null 1>/dev/null ; 
if [ $? -ne 0 ] ; then
  echo "Copying the certificates from  \"/system/etc/security/cacerts\" to \"${SYSROOT_DIR}/etc/security/cacerts\" ..."
  mkdir -p ${SYSROOT_DIR}/etc/security/cacerts && \
    cp /system/etc/security/cacerts/* ${SYSROOT_DIR}/etc/security/cacerts
else
  echo "The files in the directory \"${SYSROOT_DIR}/etc/security/cacerts\" already exist"
fi

if [ ! -r ${CERTIFICATE_BUNDLE_FILE} ] ; then
  LogMsg "Creating the file \"${CERTIFICATE_BUNDLE_FILE}\" ..."

  ls -l ${SYSROOT_DIR}/etc/security/cacerts*/*.0 2>/dev/null 1>/dev/null
  if  [ $? -ne 0 ] ; then
    LogWarning "No certificates found in the directories \"${SYSROOT_DIR}/etc/security/cacerts*\" -- can not create the bundle file \"${CERTIFICATE_BUNDLE_FILE}\" "
  else
    for i in  ${SYSROOT_DIR}/etc/security/cacerts*/*.0; do
      printf "."
      echo "$(sed -n "/BEGIN CERTIFICATE/,/END CERTIFICATE/p" $i)" >>"${CERTIFICATE_BUNDLE_FILE}"
    done
    printf "\n"
    LogMsg "... done:"
    ls -l "${CERTIFICATE_BUNDLE_FILE}"

  fi
else
  LogMsg "The certificate bundle file \"${CERTIFICATE_BUNDLE_FILE}\" already exists:"
  ls -l "${CERTIFICATE_BUNDLE_FILE}"
fi


which git 2>/dev/null 1>/dev/null
if [ $? -eq 0 ] ; then
  GIT_CRT_FILE="$( git config --global http.sslCAInfo )"
  if test -z "${GIT_CRT_FILE}" ; then
  
    if test -r "${CERTIFICATE_BUNDLE_FILE}"  ; then
      echo "Configuring the certificate bundle file \"${CERTIFICATE_BUNDLE_FILE}\" for git ..."
      git config --global http.sslCAInfo "${CERTIFICATE_BUNDLE_FILE}"
      GIT_CRT_FILE="$( git config --global http.sslCAInfo )"
    else
      LogWarning "The file \"${CERTIFICATE_BUNDLE_FILE}\" does not exist -- can not configure the ceritifcate bundle file for git"
    fi  
  fi
  
  GIT_CRT_FILE="$( git config --global http.sslCAInfo )"
  if ! test -z "${GIT_CRT_FILE}" ;then 
    LogMsg "The certificate bundle file for git is \"${GIT_CRT_FILE}\" "
  else
    LogMsg "There is no certificate bundle file configured for git"
  fi
fi

# ----------------------------------------------------------------------
# unpack the tar file with the files from the NDK
#

if [ !  -d "${SYSROOT_DIR}/usr/ndk/${NDK}" ] ; then
  NDK_TAR_FILE="${SYSROOT_DIR}/usr/ndk/${NDK}.tar.gz"

  if [ -r "${NDK_TAR_FILE}" ] ; then
    LogMsg "Unpacking the tar file \"${NDK_TAR_FILE}\" ..."
    cd "${SYSROOT_DIR}/usr/ndk" &&  ( ${SYSROOT_DIR}/usr/bin/gzip -cd "${NDK_TAR_FILE}" |  tar -xf- )
  fi
else
  LogMsg "The directory with the NDK \"${SYSROOT_DIR}/usr/ndk/${NDK}\" already exists"
fi

# ----------------------------------------------------------------------
# uncompress compressed executables
#
ls  ${SYSROOT_DIR}/usr/bin/*.gz 2>/dev/null 1>/dev/null
if [ $? -eq 0  ] ; then
  LogMsg "Uncompressing compressed executables in \"${SYSROOT_DIR}\" ..."

  for CUR_FILE in ${SYSROOT_DIR}/usr/bin/*.gz ; do
    LogMsg "Uncompressing the file \"${CUR_FILE}\" ..."
    ${SYSROOT_DIR}/usr/bin/gzip -d "${CUR_FILE}" 
  done
else
  LogMsg "No compressed executables found  in \"${SYSROOT_DIR}\" "
fi

# ----------------------------------------------------------------------
# additional optional configuration changes that require root access
#
if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ] ; then

  which tmux 2>/dev/null 1>/dev/null
  if [ $? -eq 0 ]  ; then
    if [ -d "${TMPDIR}" ] ; then
      CUR_SELINUX_CONTEXT="$( stat -c "%C" "${TMP}" )"
      if [[ ${CUR_SELINUX_CONTEXT} != *:shell_test_data_file:*  ]] ; then
        LogMsg ""
        LogMsg "Correcting the SELinux context for the directory \"${TMP}\" ..."
        ${ROOT_PREFIX} chcon u:object_r:shell_test_data_file:s0 "${TMP}"  
      fi
    else
      LogWarning "The directory \"${TMP}\" does not exist"
    fi
  fi

fi

if [ -x ${SYSROOT_DIR}/create_ssh_env.sh ] ; then
  LogMsg ""
  LogMsg "Executing now \"${SYSROOT_DIR}/create_ssh_env.sh\" ..."
  LogMsg ""
  ${SYSROOT_DIR}/create_ssh_env.sh
fi


LogMsg ""


