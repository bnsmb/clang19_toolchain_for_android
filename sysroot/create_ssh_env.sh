#!/system/bin/sh
#
# Script to create the neccessary directories and files for ssh and sshd
#
# Usage: create_ssh_env.sh
#
# History
#   24.12.2024 1.0.0 /bs
#     initial release
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

# --------------------------------------------------------------------
#
# variables for the script control flow and the script return code
#
THISRC=${__TRUE}
CONT=${__TRUE}

SYSROOT_DIR="/data/local/tmp/sysroot"
SYSROOT_VAR_DIR="${SYSROOT_DIR}/var"
SYSROOT_ETC_SSH_DIR="${SYSROOT_DIR}/etc/ssh"

SYSROOT_SSH_HOSTKEYS="ecdsa ed25519 rsa"

SSH_CONFIG_FILE="${SYSROOT_DIR}/etc/ssh/ssh_config"
SSHD_CONFIG_FILE="${SYSROOT_DIR}/etc/ssh/sshd_config"

MAIL_DIR="${SYSROOT_DIR}/var/mail"
VAR_EMPTY_DIR="${SYSROOT_DIR}/var/empty"
PID_DIR="${SYSROOT_DIR}/var/run"

PID_FILE="${PID_DIR}/sshd.pid"

SSH_USER="shell"

HOME_DIR="${SYSROOT_DIR}/home"
SHELL_HOME_DIR="${SYSROOT_DIR}/home/${SSH_USER}"

export PATH="${SYSROOT_DIR}/usr/bin:$PATH"

# LD_LIBRARY_PATH is not necessary
# export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${SYSROOT_DIR}/usr/lib"

INIT_ENV_FILE="/data/local/tmp/sysroot/init_ssh_env"


# ----------------------------------------------------------------------
#
# functions
#

# ----------------------------------------------------------------------
# LogMsg
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
LogMsg "Initializing the ssh environment in ${SYSROOT_DIR} ..."
LogMsg ""

cd "${SYSROOT_DIR}" || die 10 "Can not change the working directory to \"${SYSROOT_DIR}\" "

if [ "${CUR_ID}"x = "${SSH_USER}"x ] ; then
  LogMsg "OK; the user executing this script is \"${SSH_USER}\" "
elif [ "${CUR_ID}"x = "root"x ] ; then
  LogMsg "The user executing this script is \"root\" -- will no restart the script as user \"${SSH_USER}\" ... "
  id "${SSH_USER}" 2>/dev/null 1>/dev/null \
    die 90 "The user \"${SSH_USER}\" does not exist"
  exec su - "${SSH_USER}" -c $0 $*
  exit?
else
  die 101 "The script $0 must be executed either by the user \"${SSH_USER}\" or the user \"root\" "
fi


if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
  if [ ! -d "${SYSROOT_DIR}" ] ; then
    die 100 "ERROR: The root directory used \"${SYSROOT_DIR}\" does NOT exist"
  fi

fi


if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then

  if [ ! -d "${SYSROOT_VAR_DIR}" ] ; then
    LogMsg "Creating the directory \"${SYSROOT_VAR_DIR}\" ..."
    mkdir -p "${SYSROOT_VAR_DIR}" && chmod 755  "${SYSROOT_VAR_DIR}" || \
      die 105 "ERROR: Error creating the directory  \"${SYSROOT_DIR}\" "
  else
    LogMsg "The directory \"${SYSROOT_VAR_DIR}\" already exists"
  fi

  if [ ! -d "${MAIL_DIR}" ] ; then
    LogMsg "Creating the directory \"${MAIL_DIR}\" ..."
    mkdir -p "${MAIL_DIR}" && chmod 755  "${MAIL_DIR}" || \
      die 107 "ERROR: Error creating the directory  \"${MAIL_DIR}\" "
  else
    LogMsg "The directory \"${MAIL_DIR}\" already exists"
  fi

  if [ ! -d "${VAR_EMPTY_DIR}" ] ; then
    LogMsg "Creating the directory \"${VAR_EMPTY_DIR}\" ..."
    mkdir -p "${VAR_EMPTY_DIR}" && chmod 700  "${VAR_EMPTY_DIR}" || \
      die 109 "ERROR: Error creating the directory  \"${VAR_EMPTY_DIR}\" "
  else
    LogMsg "The directory \"${VAR_EMPTY_DIR}\" already exists"
  fi

  if [ ! -d "${PID_DIR}" ] ; then
    LogMsg "Creating the directory \"${PID_DIR}\" ..."
    mkdir -p "${PID_DIR}" && chmod 755  "${PID_DIR}" || \
      die 111 "ERROR: Error creating the directory  \"${PID_DIR}\" "
  else
    LogMsg "The directory \"${PID_DIR}\" already exists"
  fi

  if [ ! -d "${HOME_DIR}" ] ; then
    LogMsg "Creating the directory \"${HOME_DIR}\" ..."
    mkdir -p "${HOME_DIR}" && chmod 755  "${HOME_DIR}" || \
      die 111 "ERROR: Error creating the directory  \"${HOME_DIR}\" "
  else
    LogMsg "The directory \"${HOME_DIR}\" already exists"
  fi

  if [ ! -d "${SHELL_HOME_DIR}" ] ; then
    LogMsg "Creating the directory \"${SHELL_HOME_DIR}\" ..."
    mkdir -p "${SHELL_HOME_DIR}" && chmod 755  "${SHELL_HOME_DIR}" || \
      die 111 "ERROR: Error creating the directory  \"${SHELL_HOME_DIR}\" "
  else
    LogMsg "The directory \"${HOME_DIR}\" already exists"
  fi

fi

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
  for CUR_HOST_KEY in ${SYSROOT_SSH_HOSTKEYS} ; do
    CUR_HOST_KEY_FILE="${SYSROOT_ETC_SSH_DIR}/ssh_host_${CUR_HOST_KEY}_key" 
    if [ ! -r "${CUR_HOST_KEY_FILE}" ] ; then
      LogMsg "Creating the ssh host key \"${CUR_HOST_KEY_FILE}\" ..."
      ssh-keygen -t "${CUR_HOST_KEY}" -f "${CUR_HOST_KEY_FILE}" -N ""
    else
      LogMsg "The ssh host key \"${CUR_HOST_KEY_FILE}\" already exists"
    fi
  done
   
  if [ ! -r "${SSHD_CONFIG_FILE}" ] ; then
    LogMsg "Creating the file \"${SSHD_CONFIG_FILE}\" ..."
    cp "${SSHD_CONFIG_FILE}.new" "${SSHD_CONFIG_FILE}"
  else
    LogMsg "The file \"${SSHD_CONFIG_FILE}\" already exists"
  fi

  if [ ! -r "${SSH_CONFIG_FILE}" ] ; then
    LogMsg "Creating the file \"${SSH_CONFIG_FILE}\" ..."
    cp "${SSH_CONFIG_FILE}.new" "${SSH_CONFIG_FILE}"
  else
    LogMsg "The file \"${SSH_CONFIG_FILE}\" already exists"
  fi
  
  if [ ! -r "${INIT_ENV_FILE}" ] ; then
    LogMsg "Creating the file \"${INIT_ENV_FILE}\" ..."
    cat >"${INIT_ENV_FILE}" <<EOT

echo "Initializing the environment for SSH ..."

export HOME="${HOME_DIR}"

export PATH="${SYSROOT_DIR}/usr/bin:\$PATH"

[ \$# -ne 0 ] && \$*

EOT
    chmod 755 "${INIT_ENV_FILE}"
  fi
fi

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
 
  CURVAR=$( grep "^AuthorizedKeysFile" etc/ssh/sshd_config | tr "\t" " " | tr -s " " )
  AUTHORIZED_KEYS_FILE="${CURVAR#* }"
  
# awk does not exist in some Android OS
#
#  AUTHORIZED_KEYS_FILE="$( grep "^AuthorizedKeysFile" "${SYSROOT_DIR}/etc/ssh/sshd_config" | awk '{ print $NF}' )"

  if [ ! -r "${AUTHORIZED_KEYS_FILE}" ] ; then
    LogMsg "Creating the empty file \"${AUTHORIZED_KEYS_FILE}\" ..."
    touch "${AUTHORIZED_KEYS_FILE}" && chmod 600 "${AUTHORIZED_KEYS_FILE}"
  else
    LogMsg "The file \"${AUTHORIZED_KEYS_FILE}\" already exists"
  fi

  CURVAR=$( grep "^Port" etc/ssh/sshd_config | tr "\t" " " | tr -s " " )
  SSHD_PORT="${CURVAR#* }"

  CUR_IP_ADDRES="$( ip addr list wlan0 | grep "inet " | tr -s " " | sed -e "s/^.*inet //g" -e "s#/.*##g"  )"
  
# awk does not exist in some Android OS
#
#  SSHD_PORT="$( grep "^Port" "${SYSROOT_DIR}/etc/ssh/sshd_config" | awk '{ print $NF}' )"
#
#  CUR_IP_ADDRESS="$( ip addr list wlan0 | grep "inet " | awk '{ print $2 }' | cut -f1 -d "/" )"
  
  LogMsg "

To enable access via ssh add your public ssh key to the file

${AUTHORIZED_KEYS_FILE}

To start the sshd use the command

${SYSROOT_DIR}/usr/sbin/sshd

The sshd then listens on the port ${SSHD_PORT}

To connect to the sshd on this machine use the command

ssh -p ${SSHD_PORT} ${CUR_IP_ADDRESS}

To copy a file via scp to this machine use the command

scp -P ${SSHD_PORT} [source_file]  ${CUR_IP_ADDRESS}:[targetfile|targetdir]

To connect to other machines using ssh from this phone use

${SYSROOT_DIR}/usr/bin/ssh [hostname]

"

  if [ -r "${PID_FILE}" ] ; then
    CUR_PID="$( cat "${PID_FILE}" )"
    if [ "${CUR_PID}"x != ""x ] ; then
      LogMsg "The sshd is currently running: "
      ps -e -p "${CUR_PID}"
      LogMsg ""
    fi
  fi  
fi

