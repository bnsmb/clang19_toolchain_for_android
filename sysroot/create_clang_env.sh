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
#   30.03.2025 1.2.0 /bs
#     added support for multiple NDKs
#   01.04.2025 1.3.0 /bs
#     in the previous versions of this script the environment variable HOME was not set correctly and therefore some configuration files were created in the wrong directories -- fixed
#     added to code to check the user executing the script
#   19.09.2025 1.3.1 /bs
#     The script now also processes NDK tar files if the file names in the tar file begin with “./”
#   03.10.2025 1.3.2 /bs
#     The script now changes the owner for the directory /data/local/tmp/sysroot/var/empty to "root" if root access is enabled
#       (That directory is only used by the sshd if started as user root)
#   29.10.2025 1.3.3 /bs
#     create the directory /data/local/tmp/sysroot/tmp if it's missing
#


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

NDK="${NDK:=r27d}"

SYSROOT_DIR="/data/local/tmp/sysroot"

CLANG_INIT_SCRIPT="${SYSROOT_DIR}/bin/init_clang19_env"

CUR_USER="$( id -un )"

BASE_HOME_DIR="${SYSROOT_DIR}/home"

HOME="${BASE_HOME_DIR}/${CUR_USER}"

TMP="${SYSROOT_DIR}/var/tmp"

PATH="$PATH:${SYSROOT_DIR}/usr/bin"

export PATH HOME TMP

# LD_LIBRARY_PATH is not necessary
# export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${SYSROOT_DIR}/usr/lib"


if [[ " $* " == *\ noask\ * ]]; then
   YES=${__TRUE}
else
   YES=${__FALSE}
fi

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
# ask_user
# 
# function: ask user for confirmation
# 
# usage; ask_user [message]
#
# returns: ${__TRUE} - use entered yes
#          ${__FALSE} - user entered no
#
# If the variable YES is ${__TRUE} the function does not ask the user and always returns ${__TRUE}
#
function ask_user {
  typeset THISMSG="$*"

  typeset THISRC=${__FALSE}
  typeset USER_INPUT=""

  THISMSG="${THISMSG:=Press return to continue or CTRL-C to abort}"

  if [ "${YES}"x = "${__TRUE}"x ] ; then
    THISRC=${__TRUE}
  else
    LogMsg "${THISMSG}"
    read USER_INPUT

    case ${USER_INPUT} in
      "" | "yes" | "Y" | "y" )
        THISRC=${__TRUE}
	;;

      * )
        THISRC=${__FALSE}
	;;
    esac
  fi

  return ${THISRC}
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
 
  DEFAULT_USER="shell"

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

LogMsg "The user executing this script is \"${CUR_USER}\"; the current home directory is \"${HOME}\" ..."

if [ "${CUR_USER}"x != "${DEFAULT_USER}"x ] ; then
  if [ "${CUR_USER}"x = "root"x ] ; then
    LogMsg ""
    LogWarning "Executing the setup script using the user \"root\" is not recommended"
    LogMsg ""
    ask_user "Press return to continue anyway or CTRL-C to abort the script (use the parameter \"noask\" to suppress this question)" || die 100 "Script aborted by the user"
  else
    LogMsg ""
    LogWarning "The user executing the script \"${CUR_USER}\" is NOT the default shell user \"${DEFAULT_USER}\" "
    LogMsg ""
    ask_user "Press return to continue anyway or CTRL-C to abort the script (use the parameter \"noask\" to suppress this question)" || die 100 "Script aborted by the user"
    
    OWNER_OF_SYSROOT="$( stat -c %U "${SYSROOT_DIR}" )"
    if [ "${OWNER_OF_SYSROOT}"x != "${CUR_USER}" ] ; then
      LogMsg ""
      LogWarning "The owner of the directory \"${SYSROOT_DIR}\" is \"${OWNER_OF_SYSROOT}\" but the user running this script is \"${CUR_USER}\" -- this will most probably not work"
      LogMsg ""
      ask_user "Press return to continue anyway or CTRL-C to abort the script (use the parameter \"noask\" to suppress this question)" || die 100 "Script aborted by the user"
    fi
  fi
fi

if [ ! -d "${HOME}" ] ; then
  LogMsg "Creating the directory \"${HOME}\" ..."
  mkdir -p "${HOME}"
else
  LogMsg "The directory \"${HOME}\" already exists"
fi
LogMsg ""


TMP_DIR="${SYSROOT_DIR}/tmp"
if [ ! -d "${TMP_DIR}" ] ; then
  LogMsg "Creating the directory \"$TMP_DIR}\" ..."
  mkdir -p "${TMPD_DIR}"
else
  LogMsg "The directory \"${TMP_DIR}\" already exists"
fi

TMP_DIR_PERM="$( stat -c %a "${TMP_DIR}" )"
if [ "${TMP_DIR_PERM}"x != "1777"x ] ; then
  LogMsg "Correcting the permissions for \"${TMP}\" ..."
  chmod 1777 "${TMP_DIR}"
else
  LogMsg "The permissions for \"${TMP_DIR}\" are already okay"	
fi

LogMsg ""
	
# ----------------------------------------------------------------------

LogMsg "Processing the certificate files ..."

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
    LogMsg ""
    ls -l "${CERTIFICATE_BUNDLE_FILE}"
    LogMsg ""

  fi
else
  LogMsg "The certificate bundle file \"${CERTIFICATE_BUNDLE_FILE}\" already exists:"
  LogMsg ""
  ls -l "${CERTIFICATE_BUNDLE_FILE}"
  LogMsg ""
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
    LogMsg "(Use \"git config --global http.sslCAInfo <cert_bundle_file>\" to change that)"
  else
    LogMsg "There is no certificate bundle file configured for git"
  fi
fi

# ----------------------------------------------------------------------
# unpack the tar file with the files from the NDK
#
LogMsg
LogMsg "Processing the tar files with the NDKs in the directory \"${SYSROOT_DIR}/usr/ndk/\" ..."

if [ -d "${SYSROOT_DIR}/usr/ndk/" ] ; then
  cd "${SYSROOT_DIR}/usr/ndk" 
  if [ $? -ne 0 ] ; then
    LogError "Can not change the working directory to \"${SYSROOT_DIR}/usr/ndk\" "
  else
    LogMsg "The tar files with NDKs found are:"
    LogMsg ""
    LogMsg "$( ls -l *tar.gz )"
    for NDK_TAR_FILE in *.tar.gz ; do
      LogMsg ""
      LogMsg "Processing the tar file \"${NDK_TAR_FILE}\" ..."
      
      DIR_IN_TAR_FILE="$( ${SYSROOT_DIR}/usr/bin/gzip -cd "${NDK_TAR_FILE}" | tar -tf - 2>/dev/null | head -1 )"

      CUR_NDK="${DIR_IN_TAR_FILE%%/*}"
      if [ "${CUR_NDK}"x = "."x ] ; then 
        DIR_IN_TAR_FILE="${DIR_IN_TAR_FILE#*/}"
        CUR_NDK="${DIR_IN_TAR_FILE%%/*}"
      fi
      
      LogMsg "The tar file contains the NDK \"${CUR_NDK}\" "
      if [ -d "${CUR_NDK}" ] ; then
        LogMsg "The directory with the NDK \"${CUR_NDK}\" already exists"
      else
        LogMsg "Unpacking the tar file \"${NDK_TAR_FILE}\" ..."
        ${SYSROOT_DIR}/usr/bin/gzip -cd "${NDK_TAR_FILE}" |  tar -xf - 
        if [ $? -ne 0 ] ; then
          LogMsg "WARNING: Error unpacking the file \"${NDK_TAR_FILE}\" "
        else
          LogMsg " ... tar file \"${NDK_TAR_FILE}\" succesfully unpacked"
        fi
      fi
    done
  fi
else
  LogMsg "The directory with the NDKs \"${SYSROOT_DIR}/usr/ndk\" does not exist"
fi
LogMsg ""
if [ ! -d "${SYSROOT_DIR}/usr/ndk/${NDK}" ] ; then
  LogWarning "The directory with the default NDK \"${SYSROOT_DIR}/usr/ndk/${NDK}\" does not exist"
else
  LogMsg "OK, the directory with the default NDK \"${SYSROOT_DIR}/usr/ndk/${NDK}\" exists"
fi


# ----------------------------------------------------------------------
# uncompress compressed executables
#
LogMsg ""
LogMsg "Uncompressing the compressed files in \"${SYSROOT_DIR}/usr/bin\" ..."

ls  ${SYSROOT_DIR}/usr/bin/*.gz 2>/dev/null 1>/dev/null
if [ $? -eq 0  ] ; then
  LogMsg "Uncompressing compressed executables in \"${SYSROOT_DIR}\" ..."

  for CUR_FILE in ${SYSROOT_DIR}/usr/bin/*.gz ; do
    LogMsg "Uncompressing the file \"${CUR_FILE}\" ..."
    ${SYSROOT_DIR}/usr/bin/gzip -d "${CUR_FILE}" 
  done
else
  LogMsg "No compressed executables found  in \"${SYSROOT_DIR}/usr/bin\" "
fi

# ----------------------------------------------------------------------
#  create the config file for vim
#
if [ ! -r "${HOME}/.vimrc" ] ; then
  echo "Creating the config file for vim ${HOME}/.vimrc ..."
  cat >"${HOME}/.vimrc" <<EOT
" Disable Visual Mode (v, V, and Ctrl-V)
nnoremap v <Nop>
nnoremap V <Nop>
nnoremap <C-v> <Nop>
EOT
fi

# ----------------------------------------------------------------------
# additional optional configuration changes that require root access
#
if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ] ; then

  which tmux 2>/dev/null 1>/dev/null
  if [ $? -eq 0 ]  ; then
    mkdir -p "${TMP}"
    if [ -d "${TMP}" ] ; then
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

  if [ -d /data/local/tmp/sysroot/var/empty ] ; then
    LogMsg "Changing the owner of the directory \"/data/local/tmp/sysroot/var/empty\" to \"root\" ..."
  fi
fi

if [ -x ${SYSROOT_DIR}/create_ssh_env.sh ] ; then
  LogMsg ""
  LogMsg "Executing now \"${SYSROOT_DIR}/create_ssh_env.sh\" ..."
  LogMsg ""
  ${SYSROOT_DIR}/create_ssh_env.sh
fi

if [ -r "${CLANG_INIT_SCRIPT}" ] ; then
  LogMsg ""
  LogMsg "Use the command

source ${CLANG_INIT_SCRIPT}

to init the clang19 session in an adb shell

"
else
  LogWarning "The init script \"${CLANG_INIT_SCRIPT}\" does not exist"
fi


LogMsg ""


