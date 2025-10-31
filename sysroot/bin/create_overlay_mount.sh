#!/system/bin/sh
#
#h#
#h# create_overlay_mount.sh <VERSION> - create one or more overlay mounts on a device running a rooted Android OS
#h#
#h# Usage:  create_overlay_mount.sh [-h|--help] [--version] [--verbose|-v] [--noselinux] [--selinux] [--initdisk|--format] [--details] [--short] [--active] [--nomagisk] [var=value] 
#h#                                 [help] [vars] [list] [test] [get] [undo] [diff] [get] [restore] [clean] [mount_only] [mount] [umount] [remount] [directory0] [... directory#] [default]
#h#
#H# The parameter that neither start with a "-" or "/" nor contain a "=" are the action parameter that determine what is to be done. 
#H# Only one action parameter for a run is allowed. 
#H#
#H# Without an action parameter the script prints the short usage help. If one more directories are found in the parameter the default action is "mount".
#H#
#H# All parameter starting with a "/" are considered to be a filename or directory name.
#H# The parameter with the directory names are optional.
#H#
#H# The default directory list for the actions "mount", "diff", "get" and "undo" is the list of directories in the environment variable DIRS_TO_OVERLAY.
#H# The default directory list for the actions "test", "umount", and "remount" is the list of directories currently mounted to an overlay filesystem.
#H#
#H# There are no default values for the action "restore"; the actions "mount_only" and "list" ignore directory parameter.
#H#
#H# The actions "vars" and "help" only print help messages.
#H#
#H# If the variable DIRS_TO_OVERLAY is empty the script uses the hardcoded default value for this variable; that is: /system_ext  /product  /odm  /system
#H#
#H# "directory#" must be either "default", "none", or the fully qualified directory name of a directory.
#H# The value "none" deletes the current list of directories in the variable DIRS_TO_OVERLAY; the value "default" adds the default directories to the list
#H# of directories. The parameter can be used more than once.
#H# 
#H# The known option parameter are:
#H# 
#H# --version    print the script version and exit
#H# --verbose    print more messages
#H# --noselinux  disable SELinux at start of the script (SELinux is NOT enabled again by the script)
#H# --selinux    enable SELinux at start of the script (SELinux is NOT disabled again by the script)
#H# --initdisk   format the virtual disk before creating the overlay mounts; this will undo all previous changes in the filesystems
#H#              Without this option the script never formats an existing virtual disk.
#H# --details    print more details
#H# --short      print only the important information
#H# --active     the tasks diff, get, and undo should work only on the currently mounted overlay filesystems
#H# --nomagisk   do not create temporary bind mounts for the Magisk binaries; without this parameter the script creates temporary
#H#              bind mounts for the executables magisk, su, and resetprop if Magisk is installed and the bind mount 
#H#              should be created for the directory "/system".
#H#              The bind mounts are created in the directory "/data/local/tmp"; to use another directory for the bind mounts set the environment variable
#H#              BIND_MOUNT_TARGET_DIR="<directory_name>"
#H#              To create bind mounts for additional files before creating the overlay mount for "/system", add the filenames to the variable FILES_TO_KEEP 
#H#              (see below for details); the files must exist and bind mounts for directories are not supported.
#H#
#H# The known action parameter are:
#H#
#H# help         print verbose usage help
#H# vars         print only the list of supported environment variables
#H# list         list directories mounted on overlay filesystems
#H# test         test write access to directories mounted on overlay filesystems; 
#H#              default is: test write access to all directories currently mounted on an overlay filesystems
#H# get          print the name of the backend used for a file or directory mounted on an overlay filesystem
#H# undo         delete all changes done in a directory with an overlay mount
#H#              default is: delete all changes done for all directories in the environment variable DIRS_TO_OVERLAY (regardless of the mount status)
#H# diff         list the file changes for directories with overlay mounts
#H#              default is: list the changes done for all directories in the environment variable DIRS_TO_OVERLAY (regardless of the mount status)
#H# restore      restore a file or directory mounted on an overlay filesystem
#H#
#H# mount_only   mount the virtual disk and exit
#H#
#H# mount        mount the overlays for the directories
#H# umount       umount the overlays for the directories; default is to umount all overlays
#H# remount      remount the overlay mounts
#H#
#H# clean        umount all overlay mounts and umount the virtual disk
#H#
#H# Other supported parameter:
#H#
#H# var=value sets the variable "var" to the value "value"
#H# 
#H#
#H# The number of filenames in the variable FILES_TO_KEEP is not limited; the filenames must be separated by whitespaces or commas.
#H# 
#H# The filenames in the variable FILES_TO_KEEP are interpreted by the script using these rules:
#H#
#H# - filenames without a slash are searched in the directory "/system/bin", e.g.  bash -> /system/bin/bash
#H# 
#H# - filenames starting with "bin/" are searched in the directory "/system", e.g.  bin/sh -> /system/bin/sh
#H# 
#H# - filenames starting with "./" are searched in the directory "/system", e.g.  ./etc/ssh/sshd_config  -> /system/./etc/ssh/sshd_config
#H# 
#H# - fully qualified names are searched in "/",  e.g /system_ext/bin/rsync -> /system_ext/bin/rsync
#H# 
#H#
#H# Notes
#H#  
#H# Set the variable TRACE to any value before starting the script to execute it with "set -x"
#H#
#H# The detailed documentation for the script can be found here:
#H#
#H#     http://bnsmb.de/android/Documentation_for_the_script_create_overlay_mount.sh.html
#H#
#
# Tested with
#
#    Android 13, 14, 15, and 16
#
# Author
#   Bernd Schemmer (bernd dot schemmer at gmx dot de)
#
# History
#   19.06.2025 /bs v1.0.0
#     initial release
#
#   23.06.2025 /bs v1.1.0
#     /vendor is not in the default directory list anymore
#
#   25.06.2025 /bs v1.2.0
#     the default mount point is now /dev/ov
#     the script now remounts sub directories in the directories for which overlay mounts are created
#     the script now refuses to create an overlay mount for a directory if there are already overlay mounts for sub directories in place
#     added more messages in verbose mode
#     LogInfoVar is now a alias
#
#   22.10.2025 /bs v1.3.0
#     added code to create bind mounts for the Magisk binaries before an overlay mount for /system is created
#     added support for additional bind mounts and the environment variables FILES_TO_KEEP and BIND_MOUNT_TARGET_DIR
#     added the parameter --nomagisk
#     correct some typos in the comments and messages
#     the parameter "var=value" now supports values with whitespaces
#
#   31.10.2025 /bs v1.3.1
#     added magiskpolicy to the list of Magisk binaries
#

# ----------------------------------------------------------------------

__TRUE=0
__FALSE=1

# ----------------------------------------------------------------------
# enable tracing if requested
#
if [ "${TRACE}"x != ""x ] ; then
  set -x
elif [[ $- == *x* ]] ; then
#
# tracing is already enabled 
#
  TRACE=${__TRUE}
fi

# ----------------------------------------------------------------------
# define default values
#

# script version 
#
SCRIPT_VERSION="$( grep  "^#" $0 | grep "/bs v"  | tail -1 | sed "s#.*v#v#g" )"

# file used as virtual disk 
#
DEFAULT_IMAGE_FILE="/data/local/tmp/image001"

# base directory for the directories necessary for the overlay mounts
# (the virtual disk is mounted on this directory)
#
DEFAULT_BASEDIR="/dev/ov"

# directories for which an overlay mount should be created
#
DEFAULT_DIRS_TO_OVERLAY="/system_ext  /product  /odm  /system"

# filesystem for the image file (must be a filesystem that is known by Android and that supports overlay filesystems like ext4 or ext3)
# use "cat /proc/filesystems" to list the filesystems supported by the running OS)
#
DEFAULT_FILESYSTEM_TO_USE="ext4"

# initial size of the image file; the value of this parameter must be acceptable by the dd binary for the parameter "bs"
#
DEFAULT_FILESYSTEM_SIZE="100m"

# additional options for mkfs
#
DEFAULT_MKFS_OPTIONS=""

# additional mount options 
#
DEFAULT_MOUNT_OPTIONS=""

# SELinux context for the directories used for the overlays. This SELinux context is only used when the script can not read the
# SELinux context of an existing directory.
#
#DEFAULT_SELINUX_CONTEXT="u:object_r:shell_data_file:s0"
DEFAULT_SELINUX_CONTEXT="u:object_r:system_file:s0"

# SELinux context for unlabeled files/dirs: The function "set_selinux_context" replaces this SELinux context with the default SELinux Context
# To disable this behaviour set UNLABELED_SELINUX_CONTEXT to an empty string or "none"
#
UNLABELED_SELINUX_CONTEXT="${UNLABELED_SELINUX_CONTEXT:=u:object_r:unlabeled:s0}"


# list of environment variables supported by the script
#
ENVIRONMENT_VARIABLES="$( grep ^DEFAULT_ $0 | sed -e "s/DEFAULT_//g" -e "s/=.*//g" )"


# in some Android versions it's necessary to wait some time between umounting the bind mount and
# umounting the overlay mount. Set this variable to the number of seconds the script should wait
# between these umounts.
#
# time to wait in seconds between the umount of the bind mounts and the umount of the overlay mounts
#
DEFAULT_UMOUNT_WAIT_TIME=0

# print more details
#
PRINT_MORE_DETAILS=${__FALSE}

# defaults for the executables used
#
DEFAULT_MOUNT=$( which mount )
DEFAULT_UMOUNT=$( which umount )
DEFAULT_LOSETUP=$( which losetup )
DEFAULT_MKFS=$( which mkfs )
DEFAULT_DD=$( which dd )

# list of Magisk binaries for which a bind mount should be created automatically before creating the overlay mount for /system
#
MAGISK_BINARIES=" magisk su resetprop magiskpolicy"

# list of additional files for which a bind mount should be created before creating the overlay mount for /system
#
DEFAULT_FILES_TO_KEEP=""

# directory for the bind mounts 
#
DEFAULT_BIND_MOUNT_TARGET_DIR="/data/local/tmp"

# ---------------------------------------------------------------------

# init the variables for the summary messages
#
  OVERLAY_MOUNTS_CREATED=""
  NO_OVERLAY_MOUNTS_CREATED=0

  OVERLAY_MOUNTS_ALREADY_CREATED=""
  NO_OVERLAY_MOUNTS_ALREADY_CREATED=0

  DIRECTORIES_MISSING=""
  NO_OF_DIRECTORIES_MISSING=0

  OVERLAY_MOUNTS_NOT_CREATED=""
  NO_OVERLAY_MOUNTS_NOT_CREATED=0

# ---------------------------------------------------------------------
# aliase

# enable aliase in bash
#
if [ "${BASH_VERSION}"x != ""x ] ; then
  shopt -s expand_aliases
fi

alias LogInfoVar='f() { [[ ${__FUNCTION} = "" ]] && __FUNCTION=main ; [[ ${VERBOSE} != 0 ]] && return; varname="$1"; eval "echo \"INFO: in $__FUNCTION:  $varname is \${$varname}\" >&2"; unset -f f; } ;  f'


# ---------------------------------------------------------------------
# functions

# ---------------------------------------------------------------------
# LogMsg - write a message to STDOUT
#
# Usage: LogMsg [message]
#
function LogMsg {
  typeset __FUNCTION="LogMsg"
  
  typeset THISMSG="$@"

  echo "${THISMSG}"

  return ${__TRUE}
}

# ---------------------------------------------------------------------
# LogInfo - write a message to STDERR if VERBOSE is ${__TRUE}
#
# Usage: LogInfo [message]
#
# The function  returns ${__TRUE} if the message was written and
# ${__FALSE} if the message was not written
#
function LogInfo { 
  typeset __FUNCTION="LogInfo"

  [[ ${VERBOSE} == ${__TRUE} ]] && LogMsg "INFO: $@" >&2 || return ${__FALSE}
}

# ---------------------------------------------------------------------
# LogWarning - write a warning message to STDERR
#
# Usage: LogWarning [message]
#
function LogWarning {
  typeset __FUNCTION="LogWarning"

  LogMsg "WARNING: $@" >&2
}


# ---------------------------------------------------------------------
# LogError - write an error message to STDERR
#
# Usage: LogError [message]
#
function LogError {
  typeset __FUNCTION="LogError"

  LogMsg "ERROR: $@" >&2
}


# ---------------------------------------------------------------------
# die - end the program
#
# Usage:
#  die [returncode] [message]
# 
# returns:
#   n/a
#
function die {
  typeset __FUNCTION="die"

  typeset THISRC="$1"

  [ "${THISRC}"x = ""x ] && THISRC=0

  [ $# -gt 0 ] && shift

  typeset THISMSG="$*"

  if [ "${THISRC}"x = "0"x -o "${THISRC}"x = "1"x ] ; then
    [ "${THISMSG}"x != ""x ] && LogMsg "${THISMSG} (RC=${THISRC})"
  else
    LogError "${THISMSG} (RC=${THISRC})"
  fi


  exit ${THISRC}
}

# ---------------------------------------------------------------------
# create_dir_name_for_the_overlay_filesystem - create the name for the directory in ./merged or ./upper
#
# usage: 
#   create_dir_name_for_the_overlay_filesystem [directory]
#
# parameter: 
#   directory = fully qualified directory name
#
# returns:
#   the directory name is written to STDOUT
#
function create_dir_name_for_the_overlay_filesystem {
  typeset __FUNCTION="create_dir_name_for_the_overlay_filesystem"

  [ $# -eq 1 ] && echo "$( echo "$1" | cut -c2- | tr "/" "#" )"
}

# ---------------------------------------------------------------------
# get_mount_device - retrieve the device a directory is mounted to
#
# usage: 
#   get_mount_device [directory]
#
# parameter: 
#   directory = fully qualified directory name
#
# returns:
#   the device name is written to STDOUT
#
function get_mount_device {
  typeset __FUNCTION="get_mount_device"

  [ $# -eq 1 ] && df -h "$1" 2>/dev/null | tail -1 | tr "\t" " " |  cut -f1 -d " " 
}

# ---------------------------------------------------------------------
# get_mountpoint- get the mount point for a file or directory on an overly filesystem
#
# usage: 
#   get_mountpoint [directory|file] [subdir]
# 
# parameter: 
#   directory|file = fully qualified directory or file name in the filesystem used for the overlay
#   subdir can be "merged", "upper", or "lower"
#
# returns:
#   the name of the mountpoint is written to STDOUT
#
function get_mount_point {
  typeset __FUNCTION="get_mount_point"

  typeset CUR_FILE="$1"
  typeset CUR_SUBDIR="$2"


  typeset FILENAME=""
  typeset CUR_MOUNT_DIR=""

  CUR_SUBDIR="${CUR_SUBDIR:=merged}"

  FILENAME="${CUR_FILE#${BASEDIR}/${CUR_SUBDIR}/*/}"
    
  CUR_MOUNT_DIR="$( echo "${CUR_FILE}" | sed "s=/${FILENAME}==g" )"

  echo "${CUR_MOUNT_DIR}"

  LogInfoVar CUR_SUBDIR 
  LogInfoVar FILENAME 
  LogInfoVar CUR_MOUNT_DIR
}


# ---------------------------------------------------------------------
# get_file_overlay  - get the overlay for a file or directory
#
# usage: 
#   get_file_overlay [directory|file]
#
# parameter: 
#   directory|file = fully qualified directory or filename
#
# returns:
#   0 - there is an overlay for the directory/file configured and the directory/file was changed
#   1 - there is an overlay for the directory/file configured and the directory/file was deleted
#   2 - there is an overlay for the directory/file configured but the directory/file was not yet changed or deleted
#   3 - there is no overlay for the directory/file configured
#
# If the global variable EXTERNAL_USE is ${__TRUE} the function prints the filename and details.
# 
function get_file_overlay {
  typeset __FUNCTION="get_file_overlay"

  typeset THISRC=${__FALSE}

  typeset UPPERDIR="${BASEDIR}/upper"

  typeset TESTFILE=""
  typeset CUR_MOUNT_POINT=""
  
  typeset NEW_DIR_NAME=""
  typeset NEW_FILE_NAME=""

  typeset FILE_INFO=""
  typeset FILE_COMMENT=""
  
  typeset TARGET_FILE="$1"
 
  typeset CUR_MOUNTS="$( ${MOUNT} )"
  
  if [ $# -eq 1 ] ; then

    if [ ${THISRC} != ${__TRUE} ] ; then
 
      TESTFILE="${UPPERDIR}$1"
    
      CUR_MOUNT_POINT="$( get_mount_point "${TESTFILE}" "upper"  )"
           
      LogInfoVar TESTFILE
      LogInfoVar CUR_MOUNT_POINT
      
      if [ "${CUR_MOUNT_POINT}"x != ""x ] ; then
        echo "${CUR_MOUNTS}" | grep "upperdir=${CUR_MOUNT_POINT}," >/dev/null
        if [ $? -eq 0 ]  ; then    
          THISRC=${__TRUE}            
        fi
      fi
    fi
     
    if [ ${THISRC} != ${__TRUE} ] ; then

      TESTFILE="${TESTFILE#${UPPERDIR}/*}"

      while true ; do
        
        LogInfoVar TESTFILE
        LogInfoVar NEW_DIR_NAME
        LogInfoVar NEW_FILE_NAME

        NEW_DIR_NAME="${TESTFILE%%/*}"
        NEW_FILE_NAME="${TESTFILE#*/}"

        [ "${NEW_FILE_NAME}"x = "${NEW_DIR_NAME}"x ] && break
        
        TESTFILE="${NEW_DIR_NAME}#${NEW_FILE_NAME}"

        LogInfoVar TESTFILE

        CUR_MOUNT_POINT="$( get_mount_point "${UPPERDIR}/${TESTFILE}" "upper"  )"

        LogInfoVar CUR_MOUNT_POINT

        if [ "${CUR_MOUNT_POINT}"x != ""x ] ; then
          echo "${CUR_MOUNTS}" | grep "upperdir=${CUR_MOUNT_POINT}," >/dev/null
          if [ $? -eq 0 ] ; then
            TESTFILE="${UPPERDIR}/${TESTFILE}"

            LogInfoVar TESTFILE
            
            THISRC=${__TRUE}
            break
          fi
        fi
        
      done
    fi

    if [ ${THISRC} = ${__TRUE} ] ; then
      
      FILE_INFO=""      
      FILE_COMMENT="# ${TARGET_FILE}"

      if [ -r "${TESTFILE}" ] ; then

        if [ -c "${TESTFILE}" -a "$( stat -c %t%T  "${TESTFILE}" )"x = "00"x  ] ; then
          FILE_COMMENT="${FILE_COMMENT} # the file/directory was deleted"
          THISRC=1
        elif [ -d "${TESTFILE}"  ] ; then
#          if [  -d "${TARGET_FILE}" ] ; then
#            FILE_COMMENT="${FILE_COMMENT} # the directory was created"
#          fi
          THISRC=0
        else
          FILE_COMMENT="${FILE_COMMENT} # the file was changed"
          THISRC=0
        fi
 
        if [ ${PRINT_MORE_DETAILS} = ${__TRUE} ] ; then
          FILE_INFO="$( ls -ldZ "${TESTFILE}" 2>&1 )"
        else
          FILE_INFO="$( ls -1d "${TESTFILE}" 2>&1 )"
        fi
      else
        THISRC=2
        FILE_INFO="${TESTFILE}"
        FILE_COMMENT="${FILE_COMMENT} # the file was not yet changed or deleted"
      fi
    else 
      
      FILE_INFO="# There is no overlay mount active for \"${TARGET_FILE}\" in the backend \"${BASEDIR}\""

      THISRC=3
    fi

    if [ ${EXTERNAL_USE}x != ${__TRUE}x ] ; then
#
# internal usage: the function is called by another function    
#
      echo "${TESTFILE}"
    else
      if [ ${SHORT_INFOS}x = ${__TRUE}x ] ; then
        LogMsg "${FILE_INFO}"
      else
        LogMsg "${FILE_INFO} ${FILE_COMMENT}"
      fi
    fi
  fi

  return ${THISRC}
}


# ---------------------------------------------------------------------
# retrieve_overlay_filesystem_backend - get the overlay filesystem backend for a directory
#
# usage: 
#   retrieve_overlay_filesystem_backend [directory]
#
# parameter: 
#   directory = fully qualified directory name
#
# returns:
#   0 - backend dir and backend disk retrieved
#   1 - only backend dir retrieved
#   2 - this is an overlay mount but neither backend dir nor backend disk retrieved
#   3 - there is no overlay mount for the directory
#   8 - parameter error
#   9 - the directory is not mounted to an overlay filesystem
#
#   The script sets these global variables:
#     CUR_BACKEND_DIR = backend directory used
#     CUR_BACKEND_DISK = virtual disk used
#
# If there is an overlay mount for the directory the returncode is less then 3.
#
function retrieve_overlay_filesystem_backend {
  typeset __FUNCTION="retrieve_overlay_filesystem_backend"

  THISRC=1

  typeset CUR_DIR="$1"
  
  CUR_BACKEND_DIR=""
  CUR_BACKEND_DISK=""
  
  if [ $# -eq 1 ]; then
  
    df -h "${CUR_DIR}" | tail -1 | grep "^overlay" >/dev/null
    if [ $? -eq 0 ] ; then

      CUR_BACKEND_DIR="$( ${MOUNT} | grep " ${CUR_DIR} " | grep "^overlay" | tail -1 | sed -e "s#.*upperdir=##g" -e "s#/upper.*##g" )"
      if [ "${CUR_BACKEND_DIR}"x = ""x ] ; then
        THISRC=2
      else

        CUR_BACKEND_DISK="$( ${LOSETUP} -a | grep $( df -h  "${CUR_BACKEND_DIR}" | tail -1 | cut -f1 -d " " ) |  sed -e "s#.*(##g" -e "s#).*##g" )"
        if [ "${CUR_BACKEND_DISK}"x = ""x ] ; then
          THISRC=1
        else
          THISRC=0
        fi
      fi  
    else
      THISRC=3
    fi
  else
    THISRC=9  
  fi
 
  LogInfoVar CUR_BACKEND_DIR  
  LogInfoVar CUR_BACKEND_DISK
  
  return ${THISRC}
}

# ---------------------------------------------------------------------
# is_directory_mounted - check if a directory is used as mount point
#
# usage: 
#   is_directory_mounted [directory]
# 
# returns:
#   ${__TRUE} - the directory is mounted to a filesystem
#   ${__FALSE} - the directory is not mounted to a filesystem
#
# The global variable CUR_DEVICE contains the device on which the directory is
# currently mounted
#
function is_directory_mounted {
  typeset __FUNCTION="is_directory_mounted"

  THISRC=${__FALSE}

  typeset CUR_DIR=""
  typeset BASE_DIR=""

# CUR_DEVICE is a global variable!
#  typeset CUR_DEVICE=""

  typeset BASE_DEVICE=""

  if [ $# -eq 1 ] ; then
    CUR_DIR="$1"
    BASE_DIR="${CUR_DIR%/*}"

    if [ "${CUR_DIR}" = "/" ] ; then
      THISRC=${__TRUE}
    else
    
      CUR_DEVICE="$( get_mount_device "${CUR_DIR}" )"
      BASE_DEVICE="$( get_mount_device "${BASE_DIR}" )"

      LogInfo "Checking wether \"${CUR_DIR}\" is mounted on a separate filesystem ..."
      LogInfo "The device used for the directory \"${CUR_DIR}\" is \"${CUR_DEVICE}\" "
      LogInfo "The device used for the directory \"${BASE_DIR}\" is \"${BASE_DEVICE}\" "

      if [ "${CUR_DEVICE}"x = "${BASE_DEVICE}"x ] ; then
        LogInfo "\"${CUR_DIR}\" is not mounted on a separate device"
        THISRC=${__FALSE}
      else
        LogInfo "\"${CUR_DIR}\" is mounted on a separate device"
        THISRC=${__TRUE}
      fi
    fi
  fi

  return ${THISRC}
}


# ---------------------------------------------------------------------
# set_permissions - copy the permissions from the source directory to the target directory
#
# usage: 
#   set_permissions [source_dir|upper] [target_dir]
# 
#   upper = use the permissions of the upper directory
#
# returns:
#   ${__TRUE} - ok
#   ${__FALSE} - error
#
function set_permissions {
  typeset __FUNCTION="set_permissions"

  typeset SOURCE_DIR=""
  typeset TARGET_DIR=""
  
  typeset CUR_PERMSSIONS=""
  typeset CUR_OWNER=""
  
  typeset THISRC=${__FALSE}
 
  if [ $# -ne 1 -o $# -ne 2 ]; then

    if [ $# -eq 1 ] ; then
      TARGET_DIR="$1"
    else
      SOURCE_DIR="$1"
      TARGET_DIR="$2"

      if [ "${SOURCE_DIR}"x = "upper"x ] ; then
        SOURCE_DIR="${TARGET_DIR%/*}" 
      fi

      if [ ! -d "${SOURCE_DIR}" ] ; then
        LogError "The source directory \"${SOURCE_DIR}\" does not exist"
      else
        CUR_PERMISSIONS="$( stat -c %a "${SOURCE_DIR}" )" && CUR_OWNER="$( stat -c %u:%g "${SOURCE_DIR}" )"
        if [ "${CUR_OWNER}"x = ""x ] ; then
          LogWarning "Can not read the permissions or owner of the directory \"${SOURCE_DIR}\" "
        fi
      fi
    fi

    if [ "${CUR_OWNER}"x != ""x ] ; then
      LogInfo "Setting the permissions for the directory \"${TARGET_DIR}\" to \"${CUR_PERMSSIONS}\" "
      LogInfo "Setting the onwer of the directory \"${TARGET_DIR}\" to \"${CUR_OWNER}\" "

      if [ ! -d "${TARGET_DIR}" ] ; then
        LogError "The directory \"${TARGET_DIR}\" does not exist"
      else
        chmod  "${CUR_PERMISSIONS}" "${TARGET_DIR}"  && chown "${CUR_OWNER}" "${TARGET_DIR}" 
        if [ $? -ne 0 ] ; then
          LogWarning "Error changing the permissions or the owner for the directory \"${TARGET_DIR}\" to \"${CUR_SELINUX_CONTEXT}\" "
        else
          THISRC=${__TRUE}
          LogInfo "Permissions and owner of the directory \"${TARGET_DIR}\" successfully changed: " && \
            LogMsg "$( ls -ldZ "${TARGET_DIR}" 2>&1 )"
        fi
      fi
    fi

  fi

  LogInfoVar SOURCE_DIR 
  LogInfoVar TARGET_DIR 
  LogInfoVar CUR_PERMISSIONS 
  LogInfoVar CUR_OWNER
  
  return ${THISRC}  
}

# ---------------------------------------------------------------------
# set_selinux_context - copy the SELinux context from the source directory to the target directory
#
# usage: 
#   set_selinux_context [source_dir|upper] [target_dir]
# 
#   upper = use the SELinux context of the upper directory
#
# returns:
#   ${__TRUE} - ok
#   ${__FALSE} - error
#
function set_selinux_context {
  typeset __FUNCTION="set_selinux_context"

  typeset SOURCE_DIR=""
  typeset TARGET_DIR=""
  typeset CUR_SELINUX_CONTEXT=""

  typeset THISRC=${__FALSE}
 
  if [ $# -ne 1 -o $# -ne 2 ]; then

    if [ $# -eq 1 ] ; then
      TARGET_DIR="$1"
    else
      SOURCE_DIR="$1"
      TARGET_DIR="$2"

      if [ "${SOURCE_DIR}"x = "upper"x ] ; then
        SOURCE_DIR="${TARGET_DIR%/*}" 
      fi

      if [ ! -d "${SOURCE_DIR}" ] ; then
        LogError "The source directory \"${SOURCE_DIR}\" does not exist"
      else
        CUR_SELINUX_CONTEXT="$( stat -c %C "${SOURCE_DIR}" )"
        if [ "${CUR_SELINUX_CONTEXT}"x = ""x ] ; then
          LogWarning "Can not read the SELinux context from the directory \"${SOURCE_DIR}\" "
        fi
      fi
    fi

# use the default value for the SELinux context if it can't be retrieved from the source directory
#
    if [ "${CUR_SELINUX_CONTEXT}"x = ""x ] ; then
      LogInfo "Using the default SELinux context \"${SELINUX_CONTEXT}\" "
      CUR_SELINUX_CONTEXT="${SELINUX_CONTEXT}"
    fi


    if [ "${CUR_SELINUX_CONTEXT}"x = "u:object_r:unlabeled:s0"x ] ; then

      LogWarning "The SELinux context to use for \"${TARGET_DIR}\" is \"${UNLABELED_SELINUX_CONTEXT}\" "

      if [ "${UNLABELED_SELINUX_CONTEXT}"x != ""x -a "${UNLABELED_SELINUX_CONTEXT}"x != "none"x ] ; then
 
        LogWarning "That does not work -- using the default SELinux context \"${SELINUX_CONTEXT}\" now "

        CUR_SELINUX_CONTEXT="${SELINUX_CONTEXT}"
      fi
    fi

    if [ ! -d "${TARGET_DIR}" ] ; then
      LogError "The directory \"${TARGET_DIR}\" does not exist"
    else
      chcon ${CHCON_PARAMETER} "${CUR_SELINUX_CONTEXT}" "${TARGET_DIR}" 
      if [ $? -ne 0 ] ; then
        LogWarning "Error changing the SELinux context for the directory \"${TARGET_DIR}\" to \"${CUR_SELINUX_CONTEXT}\" "
      else
        THISRC=${__TRUE}
        LogInfo "SELinux context for the directory \"${TARGET_DIR}\" successfully changed to \"${CUR_SELINUX_CONTEXT}\" " && \
          LogMsg "$( ls -ldZ "${TARGET_DIR}" 2>&1 )"
      fi
    fi

  fi

  LogInfoVar SOURCE_DIR 
  LogInfoVar TARGET_DIR 
  LogInfoVar CUR_SELINUX_CONTEXT

  return ${THISRC}
}

# ---------------------------------------------------------------------
# create_directory - create one or more directories
#
# usage: 
#   create_directory [dir1] [...] [dir#]
# 
# parameter:
#
#   dir# is the directory to create; use "dir:permissions" to define the permissions for the directory
#   the default permissions for a directory are 755
#
# returns:
#   0 - all directories could be created
#   1 - one or more directories could not be created
#
# The function adds the name of each directory created to the global variable DIRECTORIES_CREATED
#
function create_directory {
  typeset __FUNCTION="create_directory"

  typeset THISRC=0

  typeset NEW_DIR=""

  typeset CUR_SELINUX_CONTEXT=""

# default permissions for new directories
#
  typeset PERMISSIONS="755"

  while [ $# -ne 0 ] ; do
    NEW_DIR="$1"
    shift

    if [[ ${NEW_DIR} == *:* ]] ; then
      PERMISSIONS="${NEW_DIR#*:}"
      NEW_DIR="${NEW_DIR%:*}"
    fi

    LogInfoVar PERMISSIONS 
    LogInfoVar NEW_DIR
    
    if [ ! -d "${NEW_DIR}" ] ; then
      LogMsg "Creating the directory \"${NEW_DIR}\" ..."
      mkdir "${NEW_DIR}" &&  chmod "${PERMISSIONS}" "${NEW_DIR}"
      if [ $? -eq 0 ] ; then
        LogInfo "Directory \"${NEW_DIR}\" successfully created"
        DIRECTORIES_CREATED="${DIRECTORIES_CREATED} ${NEW_DIR}"
      else
        LogError "Error creating the directory \"${NEW_DIR}\" "
        THISRC=$?
      fi
    else
      LogInfo "The directory \"${NEW_DIR}\" already exists"
    fi

  done

  return ${THISRC}
}


# ---------------------------------------------------------------------
# format_virtual_disk - format the virtual disk
#
# usage: 
#   format_virtual_disk [imagefile]
#
# parameter:
#   imagefile - imagefile used; default is ${IMAGE_FILE}
#
# returns:
#   0 - virtual disk successfully formated
#   1 - error formating the virtual disk
#   2 - the imagefile is not defined
#   3 - the imagefile device does not exist
#   4 - the binary to format the disk does not exist
#
function format_virtual_disk {
  typeset __FUNCTION="format_virtual_disk"

  typeset THISRC=0

  typeset CUR_IMAGE_FILE="$1"
 
  typeset TEMPRC=0


  CUR_IMAGE_FILE="${CUR_IMAGE_FILE:=${IMAGE_FILE}}"

  if [ "${MKFS}"x = ""x ] ; then
    LogError "The binary to create the filesystem, mkfs.${FILESYSTEM_TO_USE}, is not available via PATH variable"
    THISRC=4
  else
    if [ "${CUR_IMAGE_FILE}"x != ""x ] ; then
      if [ -f "${CUR_IMAGE_FILE}" ] ; then
        LogInfo "Creating a filesystem using \"${MKFS}\" on the image file \"${CUR_IMAGE_FILE}\" ..."

        [[ ${VERBOSE} = ${__TRUE} ]] && set -x 

        "${MKFS}" ${MKFS_OPTIONS} "${CUR_IMAGE_FILE}" 
        TEMPRC=$?

        [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x

        if [ ${TEMPRC} -eq 0 ] ; then
          THISRC=0
        else
          LogError "Error creating a filesystem on the imagefile \"${CUR_IMAGE_FILE}\" "
          THISRC=1
        fi
      else
        LogError "The imagefile \"${CUR_IMAGE_FILE}\" does not exist"
        THISRC=3
      fi
    else
      LogError "The image file is not defined"
      THISRC=2
    fi 
  fi

  return ${THISRC}
}



# ---------------------------------------------------------------------
# create_disk_image - create the file for the virtual disk
#
# usage: 
#   create_disk_image [image_file]
#
# parameter:
#   image_file - file to create; default is ${IMAGE_FILE}
#
# returns:
#   0 - image file successfully created
#   1 - the image file already exists
#   2 - error creating the image file
#   3 - the binary dd does not exist
#
function create_disk_image {
  typeset __FUNCTION="create_disk_image"

  typeset THISRC=0

  typeset CUR_IMAGE_FILE="$1"
  typeset TEMPRC=0

  CUR_IMAGE_FILE="${CUR_IMAGE_FILE:=${IMAGE_FILE}}"

  if [ "${DD}"x = ""x ] ; then
    LogError "The binary to create the image file for the virtual disk, dd, is not available via PATH variable"
    THISRC=3
  else
    if [ ! -r "${CUR_IMAGE_FILE}" ] ; then
      LogMsg "Creating the image file \"${CUR_IMAGE_FILE}\" with the size ${FILESYSTEM_SIZE} ..." 

      [[ ${VERBOSE} = ${__TRUE} ]] && set -x 

      "${DD}" if=/dev/zero of="${CUR_IMAGE_FILE}" bs=${FILESYSTEM_SIZE} count=1
      TEMPRC=$?

      [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x 

      if [ ${TEMPRC} -ne 0 ] ; then
        THISRC=2
        LogError "Error creating the image file \"${CUR_IMAGE_FILE}\" "
      else
        THISRC=0

        LogInfo "Image file \"${CUR_IMAGE_FILE}\" succesfully created:" && \
          LogMsg "$( ls -lh "${CUR_IMAGE_FILE}" 2>&1 )"
      fi
    else
      THISRC=1

      LogInfo "The image file \"${CUR_IMAGE_FILE}\" already exists:" && \
        LogMsg "$( ls -lh "${CUR_IMAGE_FILE}" 2>&1 )"
    fi
  fi

  return ${THISRC}
}


# ---------------------------------------------------------------------
# mount_virtual_disk - create and mount the virtual disk
#
# usage: 
#   mount_virtual_disk
#
# returns:
#   in case of an error the script is aborted
#
function mount_virtual_disk {
  typeset __FUNCTION="mount_virtual_disk"

  typeset THISRC=${__TRUE}

  typeset IMAGE_FILE_CREATED=${__FALSE}

  typeset TEMPRC=0
       
#
# create the image file if it does not already exist
#
  create_disk_image "${IMAGE_FILE}"
  TEMPRC=$?

  case ${TEMPRC} in
    0 )
      IMAGE_FILE_CREATED=${__TRUE}
      ;;

    1 )
      IMAGE_FILE_CREATED=${__FALSE}
      ;;

    * )
      die 10 "Error creating the image file \"${IMAGE_FILE}\" "
      ;;
  esac

#
# create an filesystem on the loop device if necessary
#
  if  [ ${IMAGE_FILE_CREATED} = ${__TRUE} -o ${INIT_DISK} = ${__TRUE} ] ; then
    LogMsg "Creating a \"${FILESYSTEM_TO_USE}\" filesystem on the image file \"${IMAGE_FILE}\" now ..."

    format_virtual_disk "${IMAGE_FILE}" || \
      die 25 "Error creating a filesystem on the image file \"${IMAGE_FILE}\" "
  else
    LogMsg "The image file \"${IMAGE_FILE}\" already exists - there should already be a filesystem"
  fi

# create the mount point for mounting the loop device
#
  create_directory "${BASEDIR}:755" && set_selinux_context "/system" "${BASEDIR}" || \
    die 30 "Error creating the directory \"${BASEDIR}\"" 

# mount the loop device
#
  is_directory_mounted "${BASEDIR}" 
  if [ $? -eq 0 -a ${IMAGE_FILE_CREATED} = ${__TRUE} ] ; then
    die 35 "The directory \"${BASEDIR}\" is already mounted on \"${CUR_DEVICE}\" "
  fi
  
#
# The global variable CUR_DEVICE is set by the function is_directory_mounted
#
  if [[ ${CUR_DEVICE} == /dev/block/loop* ]] ; then
    LOOP_DEVICE="${CUR_DEVICE}"
    LogInfo "\"${BASEDIR}\" is already mounted on the loop device \"${LOOP_DEVICE}\" "
  else
    LogMsg "Mounting the imagefile \"${IMAGE_FILE}\" to \"${BASEDIR}\" ..."

    [[ ${VERBOSE} = ${__TRUE} ]] && set -x 

# create a new loop device if necessary
# (losetup sometimes writes useless error messages ....)
    NEW_LOOP_DEVICE="$( ${LOSETUP} -f  2>/dev/null )"
    LogInfoVar NEW_LOOP_DEVICE
    
    ${MOUNT} -o rw -t "${FILESYSTEM_TO_USE}" ${MOUNT_OPTIONS} "${IMAGE_FILE}" "${BASEDIR}"
    TEMPRC=$?

    [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x 

    [ ${TEMPRC} != 0 ]  && die 40 "Error mounting the image file \"${IMAGE_FILE}\" to \"${BASEDIR}\" " 

    LOOP_DEVICE="$( get_mount_device "${BASEDIR}" )"

# correct the SELinux context 
#
    set_selinux_context "/system" "${BASEDIR}"

    LogInfo "Successfully mounted the image file \"${IMAGE_FILE}\" to \"${BASEDIR}\" " && \
      LogMsg "$( df -h "${BASEDIR}" 2>&1 )"
  fi

  return ${THISRC}
}


# ---------------------------------------------------------------------
# create_overlay_directory_tree - create the directories used for the overlay mounts
#
# usage: 
#   create_overlay_directory_tree
#
# returns:
#   in case of an error the script is aborted
#
function create_overlay_directory_tree {
  typeset __FUNCTION="create_overlay_directory_tree"

  typeset THISRC=${__TRUE}

# correct the SELinux context for the directory lost+found (the directory is created by mkfs)
#
  if [ -d "${BASEDIR}/lost+found" ] ; then
    set selinux_context  "/lost+found" "${BASEDIR}/lost+found"
  fi
  
# create the directory structure for the overlay mounts
#
  for CUR_DIR in upper merged work ; do
    NEW_DIR="${BASEDIR}/${CUR_DIR}"

    create_directory "${NEW_DIR}:777"  && set_selinux_context "upper" "${NEW_DIR}" || \
      die 45 "Error creating the directory \"${NEW_DIR}\"" 

  done

# create the symbolic link necessary for creating an overlay mount for /system
# (some programs in Android use ../../sys instead of /sys to access files in /sys)
# (the links are not harmful if no overlay filesystem is created for /system)
#
  for CUR_DIR in /sys /dev /proc; do 
    if [ ! -L "${BASEDIR}/merged/${CUR_DIR}" ] ; then
      LogInfo "Creating the symbolic link \"${BASEDIR}/merged${CUR_DIR}\" -> \"${CUR_DIR}\" .."
      ln -s "${CUR_DIR}" "${BASEDIR}/merged${CUR_DIR}"
    fi
  done
  
  return ${THISRC}
}


# ---------------------------------------------------------------------
# test_overlay_mounts - test write access for the overlay mounts
#
# usage: 
#   test_overlay_mounts
#
# returns:
#   ${__TRUE}  - write access is okay for all overlay mounts 
#   ${__FALSE} - write access is not okay for one or more overlay mounts
#
function test_overlay_mounts {
  typeset __FUNCTION="test_overlay_mounts"

  typeset THISRC=${__TRUE}

  typeset CUR_DIR=""
  typeset CUR_TEST_FILE=""

  typeset DIRS_TO_TEST=""

  create_list_of_mounted_overlays

  if [ ${DIRECTORY_FOUND_IN_THE_PARAMETER} = ${__TRUE} ] ; then
    DIRS_TO_TEST="${DIRS_TO_OVERLAY}"
  else
    DIRS_TO_TEST="${CUR_OVERLAY_FILESYSTEMS}"
  fi

  if [ "${DIRS_TO_TEST}"x != ""x ] ; then
    LogMsg "Testing the write access for directories mounted on overlay filesystems ..."
    LogMsg ""
 
    for CUR_DIR in ${DIRS_TO_TEST} ; do
      LogMsg ""
      LogMsg "Testing write access for the directory \"${CUR_DIR}\" ..."

      CUR_TEST_FILE="${CUR_DIR}/testfile.$$.${RANDOM}"

      touch "${CUR_TEST_FILE}"
      if [ $? -eq 0 ] ; then

        LogInfo "The testfile created is (the file will be deleted) " && \
          LogMsg "$( ls -ld "${CUR_TEST_FILE}" 2>&1 )"

        \rm -f "${CUR_TEST_FILE}"
        LogMsg "  OK, the write access to the directory \"${CUR_DIR}\" works"
      else
        LogError "The write access to the directory \"${CUR_DIR}\" does NOT work"
        THISRC=${__FALSE}
      fi

    done
  else
    LogMsg "No directories are mounted on an overlay filesystem"
  fi

  return ${THISRC}
}

# ---------------------------------------------------------------------
# list_overlay_mounts - list the active overlay mounts
#
# usage: 
#   list_overlay_mounts
#
# returns:
#   ${__TRUE}  - overlay mounts printed
#   ${__FALSE} - no overlay mounts found
#
function list_overlay_mounts {
  typeset __FUNCTION="list_overlay_mounts"

  typeset THISRC=${__TRUE}

  typeset CUR_DIR=""
  typeset FIELD_SIZE=10
  
  create_list_of_mounted_overlays

  for CUR_DIR in ${CUR_OVERLAY_FILESYSTEMS} ; do
    [ ${#CUR_DIR} -gt ${FIELD_SIZE} ] && FIELD_SIZE=${#CUR_DIR}
  done
  (( FIELD_SIZE = FIELD_SIZE + 5 ))
  
  
  if [ "${CUR_OVERLAY_FILESYSTEMS}"x != ""x ] ; then
    LogMsg "Directories mounted on an overlay filesystem"

    if [ ${PRINT_MORE_DETAILS} != ${__TRUE} ] ; then
       LogMsg ""
       LogMsg "${CUR_OVERLAY_FILESYSTEMS}"
       LogMsg ""
    else
      LogMsg 
      printf "%-${FIELD_SIZE}s %s \n" "Directory" "Backend Directory"
      printf "%-${FIELD_SIZE}s %s \n" "---------" "-----------------"

      for CUR_DIR in ${CUR_OVERLAY_FILESYSTEMS} ; do

        retrieve_overlay_filesystem_backend "${CUR_DIR}"

        if [ "${CUR_BACKEND_DIR}"x = ""x ] ; then
          CUR_BACKEND_DIR="???"
        else
          if [ "${CUR_BACKEND_DISK}"x != ""x ] ; then
            CUR_BACKEND_DIR="${CUR_BACKEND_DIR} (Virtual disk: ${CUR_BACKEND_DISK})"
          fi
        fi
        printf "%-${FIELD_SIZE}s %s \n" "${CUR_DIR}" "${CUR_BACKEND_DIR}"
      done
    fi
    
#    LogMsg "${CUR_OVERLAY_FILESYSTEMS}"
    LogMsg 
  else
    LogMsg "No directories are mounted on an overlay filesystem"
    THISRC=${__FALSE}
  fi

  return ${THISRC}
}

# ---------------------------------------------------------------------
# list_file_changes - list all changes done in directories with an overlay mount
#
# usage: 
#   list_file_changes
#
# returns:
#   ${__TRUE}  - list successfully done
#   ${__FALSE} - list failed for one or more directories
#
function list_file_changes {
  typeset __FUNCTION="list_file_changes"

  typeset THISRC=${__TRUE}

  typeset CUR_DIR=""

  typeset OVERLAY_UPPER_DIR=""

  if [ "${DIRS_TO_OVERLAY}"x = ""x ] ; then
    LogMsg "No directories with overlays found"
    THISRC=${__TRUE}
  else
    LogMsg "List the changes in the directories ..."

    create_list_of_mounted_overlays
 
    for CUR_DIR in ${DIRS_TO_OVERLAY} ; do
      LogMsg ""
      LogMsg " ---------------------------------------------------------------------- "
      OVERLAY_UPPER_DIR="${BASEDIR}/upper/$( create_dir_name_for_the_overlay_filesystem "${CUR_DIR}" )"
      if [ -d "${OVERLAY_UPPER_DIR}" ] ; then
        LogMsg "List the changes in the directory \"${CUR_DIR}\" ..."

        echo "${CUR_OVERLAY_FILESYSTEMS}" | grep "^${CUR_DIR}$" >/dev/null
        if [ $? -eq 0 ] ; then
          LogMsg "There is currently an overlay mounted for the directory \"${CUR_DIR}\""
        else
          LogMsg "There is currently no overlay mounted for the directory \"${CUR_DIR}\""
        fi

        cd  "${OVERLAY_UPPER_DIR}"
        if [ $? -ne 0 ] ; then
          LogError "Can not change to the directory \"${OVERLAY_UPPER_DIR}\" "
          THISRC=${__FALSE}
        else
          LogMsg "File changes in the directory \"${CUR_DIR}\" :"
          LogMsg 
          if [ ${PRINT_MORE_DETAILS} = ${__TRUE} ] ; then
            find . ! -type c -exec ls -ldZ {} +  | grep -v " .$"
          else
            find . ! -type c -exec ls  -1d {} +  | grep -v "^.$"
          fi
          LogMsg 

          LogMsg "Files or directories deleted in the directory \"${CUR_DIR}\" :"
          LogMsg 
          find .  -type c -exec ls -1d {} +
          LogMsg 
        fi 
      else
        LogWarning "No overlay for the directory \"${CUR_DIR}\" found."
      fi
    done
  fi

  return ${THISRC}
}

# ---------------------------------------------------------------------
# undo_file_changes - undo all changes in a directory with overlay mount
#
# usage: 
#   undo_file_changes
#
# returns:
#   ${__TRUE}  - undo successfully done
#   ${__FALSE} - undo failed for one or more directories
#
function undo_file_changes {
  typeset __FUNCTION="undo_file_changes"

  typeset THISRC=${__TRUE}

  typeset CUR_DIR=""

  typeset OVERLAY_UPPER_DIR=""

  if [ "${DIRS_TO_OVERLAY}"x = ""x ] ; then
    LogMsg "No directories for undo found"
    THISRC=${__TRUE}
  else
    LogMsg "Undoing the change in the directories ..."
 
    for CUR_DIR in ${DIRS_TO_OVERLAY} ; do
      OVERLAY_UPPER_DIR="${BASEDIR}/upper/$( create_dir_name_for_the_overlay_filesystem "${CUR_DIR}" )"
      if [ -d "${OVERLAY_UPPER_DIR}" ] ; then
        LogMsg "Undoing the changes for the directory \"${CUR_DIR}\" ..."
        \rm -rf "${OVERLAY_UPPER_DIR}"/*
        if [ $? -ne 0 ] ; then
          LogError "The undo for the directory \"${CUR_DIR}\" failed"
          THISRC=${__FALSE}
        fi
      else
        LogWarning "No overlay for the directory \"${CUR_DIR}\" found."
      fi
    done
  fi

  return ${THISRC}
}

# ---------------------------------------------------------------------
# umount_overlay_mounts - umount the overlay mounts
#
# usage: 
#   umount_overlay_mounts
#
# returns:
#   ${__TRUE}  - overlay mounts umounted
#   ${__FALSE} - umounting of one or more mounts failed
#
function umount_overlay_mounts {
  typeset __FUNCTION="umount_overlay_mounts"

  typeset THISRC=${__TRUE}

  typeset CUR_DIR=""
  typeset OVERLAY_MERGED_DIR=""

  typeset DIRECTORYS_TO_PROCESS=""

  typeset DIRECTORY_LIST=""
  typeset DIRECTORY_LIST2=""

  typeset TEMPRC=0

  typeset SUB_MOUNT_POINTS=""
  typeset CUR_SUB_MOUNT=""

# the function create_list_of_mounted_overlays sets the global variables
#   CUR_OVERLAY_FILESYSTEMS
#   ALL_OVERLAY_MOUNTS

  create_list_of_mounted_overlays

  if [ ${DIRECTORY_FOUND_IN_THE_PARAMETER} = ${__TRUE} ] ; then 
    DIRECTORYS_TO_PROCESS="${DIRS_TO_OVERLAY}"
  else
    DIRECTORYS_TO_PROCESS="${CUR_OVERLAY_FILESYSTEMS}"
  fi

  if [ "${DIRECTORYS_TO_PROCESS}"x = ""x ] ; then
    LogMsg "No directories to umount found"
    THISRC=${__TRUE}
  else

    for CUR_DIR in ${DIRECTORYS_TO_PROCESS} ; do

      echo "${CUR_OVERLAY_FILESYSTEMS}" | grep "^${CUR_DIR}$" >/dev/null
      if [ $? -eq 0 ] ;then
        DIRECTORY_LIST="${DIRECTORY_LIST} ${CUR_DIR}"
      else
        LogWarning "${CUR_DIR} is not mounted on an overlay filesystem"
      fi

    done

    LogInfo "Directories to umount are:" && \
      LogMsg "${DIRECTORY_LIST}"
  fi

  DIRECTORY_LIST2=""

  if [ "${DIRECTORY_LIST}"x != ""x ] ; then

    LogMsg "Umounting the bind mounts ..."
    for CUR_DIR in ${DIRECTORY_LIST} ; do

#
# retrieve the list of mount points in the directory
#
      SUB_MOUNT_POINTS="$( mount | grep " ${CUR_DIR}/" | grep "^/dev/block/sd" | tr "\t" " " | tr -s " " | cut -f3 -d  " " | sort | uniq )"

      LogInfoVar SUB_MOUNT_POINTS

      if [ "${SUB_MOUNT_POINTS}"x != ""x ] ; then
        LogMsg "Umounting the mounted sub directories ..."

        for CUR_SUB_MOUNT in ${SUB_MOUNT_POINTS} ; do
          LogMsg "Umounting \"${CUR_SUB_MOUNT}\" ..."

          [[ ${VERBOSE} = ${__TRUE} ]] && set -x       
          ${UMOUNT} ${CUR_SUB_MOUNT}
          TEMPRC=$?
          [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x 

          if [ ${TEMPRC} != 0 ] ;then
            LogError "Error umounting \"${CUR_SUB_MOUNT}\" "
          fi
        done
      fi
      
      LogMsg "Umounting the bind mount  \"${CUR_DIR}\" ..."

      [[ ${VERBOSE} = ${__TRUE} ]] && set -x 
      ${UMOUNT} "${CUR_DIR}" 
      TEMPRC=$?
      [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x 

      if [ ${TEMPRC} -eq 0 ] ; then
       OVERLAY_MERGED_DIR="${BASEDIR}/merged/$( create_dir_name_for_the_overlay_filesystem "${CUR_DIR}" )"

        echo "${ALL_OVERLAY_MOUNTS}" | grep "^${OVERLAY_MERGED_DIR}$" >/dev/null
        if [ $? -eq 0 ] ; then
           DIRECTORY_LIST2="${DIRECTORY_LIST2} ${OVERLAY_MERGED_DIR}" 
        fi
      else
        THISRC=${__FALSE}
      fi    
    done 
    LogMsg " ... done"
  fi

  LogInfoVar DIRECTORY_LIST2
  
  if [ "${DIRECTORY_LIST2}"x != ""x ] ; then

    if [ ${UMOUNT_WAIT_TIME}x != 0x ] ; then
      LogMsg "Sleeping ${UMOUNT_WAIT_TIME} seconds now ..."
      sleep ${UMOUNT_WAIT_TIME}
    fi
    
    LogInfo "The overlay mounts are now" && 
      LogMsg "$( df -h | grep "^overlay" )"

    LogMsg "Umounting the overlay mounts ..."
    for CUR_DIR in ${DIRECTORY_LIST2} ; do

      LogMsg "Umounting \"${CUR_DIR}\" ..."

      [[ ${VERBOSE} = ${__TRUE} ]] && set -x 
      ${UMOUNT} "${CUR_DIR}" || THISRC=${__FALSE}
      [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x 

    done
    LogMsg " ... done"

    LogInfo "The overlay mounts are now" && 
      LogMsg "$( df -h | grep "^overlay" )"
  fi

  return ${THISRC}
}

# ---------------------------------------------------------------------
# remount_overlay_mounts - remount the overlay mounts
#
# usage: 
#   remount_overlay_mounts
#
# returns:
#   ${__TRUE}  - overlay mounts reounted
#   ${__FALSE} - remounting of one or more mounts failed
#
function remount_overlay_mounts {
  typeset __FUNCTION="remount_overlay_mounts"

  typeset THISRC=${__TRUE}

  typeset CUR_DIR=""
  typeset OVERLAY_MERGED_DIR=""

  typeset DIRECTORYS_TO_PROCESS=""

  typeset DIRECTORY_LIST=""

  typeset TEMPRC=0
  
# the function create_list_of_mounted_overlays sets the global variables
#   CUR_OVERLAY_FILESYSTEMS
#   ALL_OVERLAY_MOUNTS

  create_list_of_mounted_overlays

  if [ ${DIRECTORY_FOUND_IN_THE_PARAMETER} = ${__TRUE} ] ; then 
    DIRECTORYS_TO_PROCESS="${DIRS_TO_OVERLAY}"
  else
    DIRECTORYS_TO_PROCESS="${CUR_OVERLAY_FILESYSTEMS}"
  fi

  if [ "${DIRECTORYS_TO_PROCESS}"x = ""x ] ; then
    LogMsg "No directories to remount found"
    THISRC=${__TRUE}
  else

    for CUR_DIR in ${DIRECTORYS_TO_PROCESS} ; do

      echo "${CUR_OVERLAY_FILESYSTEMS}" | grep "^${CUR_DIR}$" >/dev/null
      if [ $? -eq 0 ] ;then
        DIRECTORY_LIST="${DIRECTORY_LIST} ${CUR_DIR}"
      else
        LogWarning "${CUR_DIR} is not mounted on an overlay filesystem"
      fi

    done

    LogInfo "Directories to renount are:" && \
      LogMsg "${DIRECTORY_LIST}"
  fi

  if [ "${DIRECTORY_LIST}"x != ""x ] ; then

    LogMsg "Remounting the overlay mounts ..."
    for CUR_DIR in ${DIRECTORY_LIST} ; do

      LogMsg "Remounting \"${CUR_DIR}\" ..."

      OVERLAY_MERGED_DIR="$( ${MOUNT} | grep "^overlay" | grep  " ${CUR_DIR} " | sed -e "s/.*upperdir=//g" -e "s/,workdir=.*//g" | sed "s#/upper/#/merged/#"  )"

#      OVERLAY_MERGED_DIR="${BASEDIR}/merged/$( create_dir_name_for_the_overlay_filesystem "${CUR_DIR}" )"
      
      LogInfo "\"${CUR_DIR}\" is mounted on \"${OVERLAY_MERGED_DIR}\" "
      
      [[ ${VERBOSE} = ${__TRUE} ]] && set -x 
      ${MOUNT} -o remount "${OVERLAY_MERGED_DIR}" 
      TEMPRC=$?
      [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x 
      if [ ${TEMPRC} -ne 0 ] ; then
        THISRC=${__FALSE}
      fi

    done 
    LogMsg " ... done"
  fi

  return ${THISRC}
}

# ---------------------------------------------------------------------
# restore_files - restore files or directories
#
# usage: 
#   restore_files [file|dir] [...file#|dir#]
#
# returns:
#   ${__TRUE}  - all files and directories restored
#   ${__FALSE} - restoring one or more files or directories failed
#
function restore_files {
  typeset __FUNCTION="restore_files"

  typeset THISRC=${__TRUE}

  typeset CUR_ENTRY=""
  typeset CUR_DIR=""
  typeset DIRS_TO_REMOUNT=""
  typeset MERGED_BACKEND=""
  typeset CUR_BACKEND=""
  typeset FILENAME=""

  
#
# DIRECTORY_FOUND_IN_THE_PARAMETER is global variable
#  

  DIRS_TO_REMOUNT=""
#
# DIRS_TO_OVERLAY is a global variable
#
  for CUR_ENTRY in ${DIRS_TO_OVERLAY} ; do
     
    echo  "${CUR_OVERLAY_FILESYSTEMS}" | grep "^${CUR_ENTRY}$" >/dev/null
    if [ $? -eq 0 ] ; then
      LogMsg "\"${CUR_ENTRY}\" is a directory with an overlay mount -- use the parameter \"undo ${CUR_ENTRY}\" to undo all changes for this directory"
      continue
    fi

    CUR_BACKEND="$( get_file_overlay "${CUR_ENTRY}" )"
    if [ $? -eq 2 ] ; then
      LogMsg "The file or directory \"${CUR_ENTRY}\" was not yet changed "
    elif [ $? -gt 3 ] ; then
      LogMsg "There is no overlay active for the file or directory \"${CUR_ENTRY}\""
    elif [ "${CUR_BACKEND}"x = ""x ] ; then
      LogError "Can not retrieve the backend for the file or directory \"${CUR_ENTRY}\" "
      THISRC=${__FALSE}
    else

      MERGED_BACKEND="$( echo "${CUR_BACKEND}" | sed "s=^${BASEDIR}/upper/=${BASEDIR}/merged/=g" )"

      LogInfo "The backend for the file \"${CUR_ENTRY}\" is \"${CUR_BACKEND}\" "

      LogInfo "Deleting the files \"${CUR_BACKEND}\" and \"${MERGED_BACKEND}\" ..."
      if [ -d "${CUR_BACKEND}" ] ; then
        LogMsg "Restoring the directory \"${CUR_ENTRY}\" ..."
      else
        LogMsg "Restoring the file \"${CUR_ENTRY}\" ..."
      fi

      if [ -c "${CUR_BACKEND}" ] ; then
#
# this is a deleted file or directory -- add the filesystem to the list of filesystems that should be remounted
#
        FILENAME="${MERGED_BACKEND#${BASEDIR}/merged/*/}"
        CUR_MERGED_DIR="$( echo "${MERGED_BACKEND}" | sed "s'/${FILENAME}''" )"
           
        if [[ " ${DIRS_TO_REMOUNT} " != *\ ${CUR_MERGED_DIR}\ * ]] ;then
          LogInfo "Restore of a deleted file requested -- adding the directory \"${CUR_MERGED_DIR}\" to the list of directories to re-mount"
          DIRS_TO_REMOUNT="${DIRS_TO_REMOUNT} ${CUR_MERGED_DIR} "
        else
          LogInfo "Restore of a deleted file requested -- the directory \"${CUR_MERGED_DIR}\" is already in the list of directories to re-mount"
        fi
      fi
      [[ ${VERBOSE} = ${__TRUE} ]] && set -x 
      \rm -rf "${MERGED_BACKEND}" "${CUR_BACKEND}"  || THISRC=${__FALSE}
      [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x 
    fi
  done

# 
# remount the directories in which files or directories were undeleted
#  
  if [ "${DIRS_TO_REMOUNT}"x != ""x ] ; then
    LogInfo "One or more deleted files restored -- now remounting the overlay mounts ..."
    for CUR_DIR in ${DIRS_TO_REMOUNT} ; do
      LogInfo "Remounting \"${CUR_DIR}\" ..."

      [[ ${VERBOSE} = ${__TRUE} ]] && set -x       
      ${MOUNT} -o remount "${CUR_DIR}" || THISRC=${__FALSE}
      [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x 

    done
  fi
  
  return ${THISRC}
}

# ---------------------------------------------------------------------
# clean_mount_config - umount the mountpoint and delete the loop device
#
# usage: 
#   clean_mount_config [directory]
#
# default directory is ${BASEDIR}
#
# returns:
#   ${__TRUE} -- ok
#   ${__FALSE} -- error
#
function clean_mount_config {
  typeset __FUNCTION="clean_mount_config"

  THISRC=${__FALSE}

  typeset CUR_DIR=""
  
  CUR_DIR="$1"
  CUR_DIR="${CUR_DIR:=${BASEDIR}}"

  LogMsg "Cleaning the config for \"${CUR_DIR}\" "

  if [ "${CUR_DIR}"x != ""x ] ; then
    is_directory_mounted "${CUR_DIR}"
    if [ $? -ne ${__TRUE} ] ; then
      LogWarning "\"${CUR_DIR}\" is not mounted"
    elif [[ ${CUR_DEVICE} != /dev/block/loop* ]] ; then
      LogWarning "\"${CUR_DIR}\" is mounted on \"${CUR_DEVICE}\" - that is not a looop device"
    else
      LogMsg "Umounting \"${CUR_DIR}\" ..."
      ${UMOUNT} "${CUR_DIR}" 
      if [ $? -ne 0 ] ; then
        LogError "Error umounting \"${CUR_DIR}\" "
      else

        LogMsg "... \"${CUR_DIR}\" successully umounted"
        THISRC=${__TRUE}
      fi
    fi
  else
    LogError "clean_mount_config: No directory to clean found"
  fi
  
  return ${__THISRC}
}
  

# ---------------------------------------------------------------------
# create_overlay_mounts - create the overlay mounts
#
# usage: 
#   create_overlay_mounts
#
# returns:
#   in case of an error the script is aborted
#
function create_overlay_mounts {
  typeset __FUNCTION="create_overlay_mounts"


  typeset THISMSG=""
  
  typeset CUR_DEVICE=""
  typeset LINK_TARGET=""
  typeset CUR_DIR=""
    
  typeset CUR_MOUNT_POINT=""

  typeset SUB_MOUNT_POINTS=""
  typeset CUR_SUB_MOUNT_DEVICE=""
  typeset CUR_SUB_MOUNT_FILESYSTEM_TYPE=""
  typeset CUR_SUB_MOUNT_OPTIONS=""

  typeset DIRECTORY_OKAY=${__TRUE}
  typeset OVERLAY_ALREADY_IN_PLACE=${__FALSE}
  
  typeset CUR_OVERLAY_MOUNTS=""

  typeset CUR_PROG=""
  typeset CUR_SOURCE=""
  typeset MOUNT_TARGET=""
  typeset CUR_SUB_DIR=""
  typeset CUR_TARGET_SIZE=0
  
# these are global variables:
#
#  OVERLAY_MOUNTS_CREATED=""
#  NO_OVERLAY_MOUNTS_CREATED=0
#
#  OVERLAY_MOUNTS_ALREADY_CREATED=""
#  NO_OVERLAY_MOUNTS_ALREADY_CREATED=0
#
#  DIRECTORIES_MISSING=""
#  NO_OF_DIRECTORIES_MISSING=0
#
#  OVERLAY_MOUNTS_NOT_CREATED=""
#  NO_OVERLAY_MOUNTS_NOT_CREATED=0
#
  
  for CUR_DIR in ${DIRS_TO_OVERLAY} ; do

    LogMsg ""
    LogMsg "Creating and mounting the directories for the overlay mount for \"${CUR_DIR}\" ..."

    if [[ ${CUR_DIR} == / ]] ; then
      LogError "overlay mounts for \"/\" are not allowed"

# change the global variables
#
      DIRECTORIES_MISSING="${DIRECTORIES_MISSING}
  ${CUR_DIR}"
      (( NO_OF_DIRECTORIES_MISSING = NO_OF_DIRECTORIES_MISSING + 1 ))

      continue
    fi

# add leading /
    [[ ${CUR_DIR} != /* ]] && CUR_DIR="/${CUR_DIR}"

# remove trailing /
    [[ ${CUR_DIR} == */ ]] && CUR_DIR="${CUR_DIR%*/}"

# check for overlay mounts for /system 
#    
    if [[ ${CUR_DIR} == /system ]] ; then

# check if magisk is installed
#
      if [ -x /system/bin/magisk ] ; then         
        if [ ${IGNORE_MAGISK} = ${__TRUE} ] ; then
          LogMsg "INFO: Magisk is installed but no temporary copies of the Magisk executables created on request"
        else
          LogMsg ""
          LogMsg "Magisk is installed - creating temporary copies of the Magisk executables ..."
          FILES_TO_KEEP="${FILES_TO_KEEP} ${MAGISK_BINARIES}"
        fi
      fi


# list of files for which a bind mount should be created
#   
      FILES_TO_KEEP="$( echo "${FILES_TO_KEEP}" | tr "," " " )"
      
      for CUR_PROG in ${FILES_TO_KEEP} ; do

        if [[ ${CUR_PROG} != */* ]] ; then
          CUR_SOURCE="/system/bin/${CUR_PROG}"
        elif [[ ${CUR_PROG} == bin/* ]]  ; then
          CUR_SOURCE="/system/${CUR_PROG}"
        elif [[ ${CUR_PROG} = /* ]]  ; then
          CUR_SOURCE="${CUR_PROG}"                
        elif [[ ${CUR_PROG} = ./* ]]  ; then
          CUR_SOURCE="/system/${CUR_PROG}"
        else   
          CUR_SOURCE="${CUR_PROG}"                
        fi
           
        if [  -d "${CUR_SOURCE}" ] ; then
          LogError "\"${CUR_SOURCE}\" is a directory -- directories are not supported"
        elif [ ! -r "${CUR_SOURCE}" ] ; then
          LogWarning "The file \"${CUR_SOURCE}\" does not exist -- can not create a bind mount"
        else
          MOUNT_TARGET="${BIND_MOUNT_TARGET_DIR}${CUR_SOURCE}"

          if [ ! -r "${MOUNT_TARGET}" ] ; then
            CUR_SUB_DIR="${MOUNT_TARGET%/*}"
            [ ! -d "${CUR_SUB_DIR}" ] && mkdir -p "${CUR_SUB_DIR}"          
            touch "${MOUNT_TARGET}"
          fi
          CUR_TARGET_SIZE="$(  stat -c%s "${MOUNT_TARGET}" )"
          if [ "${CUR_TARGET_SIZE}"x != "0"x ] ; then          
            LogMsg "The temporary flie \"${MOUNT_TARGET}\" already exists"
          else
            LogMsg "Creating the temporary file \"${MOUNT_TARGET}\" ..."
            mount -o bind "${CUR_SOURCE}" "${MOUNT_TARGET}"
          fi
        fi
      done
      LogMsg ""

    fi


    DIRECTORY_OKAY=${__TRUE}

    if [ ! -r "${CUR_DIR}" ] ; then
      LogError "The directory \"${CUR_DIR}\" does NOT exist -- ignored"
      THISMSG="# directory does not exist"
      DIRECTORY_OKAY=${__FALSE}
    elif [ -L "${CUR_DIR}" ] ; then
      LINK_TARGET="$( readlink "${CUR_DIR}" )"
      LogError "\"${CUR_DIR}\" is a symbolic link for \"${LINK_TARGET}\" -- ignored"
      THISMSG="# this is a symbolic link"
      DIRECTORY_OKAY=${__FALSE}
    elif [ -f "${CUR_DIR}" ] ; then
      LogError "\"${CUR_DIR}\" is a file -- ignored"
      THISMSG="# this is a file "
      DIRECTORY_OKAY=${__FALSE}
    elif [ ! -d "${CUR_DIR}" ] ; then
      LogError "\"${CUR_DIR}\" is not a directory -- ignored"
      THISMSG="# this is not a directory"
      DIRECTORY_OKAY=${__FALSE}
    fi 

    if [ ${DIRECTORY_OKAY} = ${__FALSE} ] ; then
#
# change the global variables
# 
      DIRECTORIES_MISSING="${DIRECTORIES_MISSING}
  ${CUR_DIR} ${THISMSG}"
      (( NO_OF_DIRECTORIES_MISSING = NO_OF_DIRECTORIES_MISSING + 1 ))

      continue
    fi

    OVERLAY_ALREADY_IN_PLACE=${__FALSE}

#
# check if there is already an overlay mount for this directory
#
    CUR_DEVICE="$( df -h "${CUR_DIR}" |  grep "^overlay" )"
    [ "${CUR_DEVICE}"x != ""x ] && CUR_DEVICE="/${CUR_DEVICE#*/}"
#    
# print short infos
#
    if [ ${PRINT_MORE_DETAILS} != ${__TRUE} ] ; then
      if [ "${CUR_DEVICE}"x != ""x ] ; then
        THISMSG="There is already an overlay mount for the directory \"${CUR_DIR}\" in place "
        OVERLAY_ALREADY_IN_PLACE=${__TRUE}
      fi
    else
#
# print detailed infos
#    

      THISMSG="There is already an overlay mount for the directory \"${CUR_DIR}\" in place"

      retrieve_overlay_filesystem_backend "${CUR_DIR}"
      if [ $? -gt 2 ] ; then
        retrieve_overlay_filesystem_backend "/${CUR_DEVICE#*/}"
      fi
      
      if [ "${CUR_BACKEND_DIR}"x != ""x ] ; then    
        THISMSG="There is already an overlay mount for the directory \"${CUR_DIR}\" in place for for \"${CUR_DEVICE}"
        if [ "${CUR_BACKEND_DIR}"x != ""x ] ; then    
          THISMSG="${THISMSG} (backend directory is \"${CUR_BACKEND_DIR}\" "
          if [ "${CUR_BACKEND_DISK}"x != ""x ] ; then
            THISMSG="${THISMSG}, backend disk is \"${CUR_BACKEND_DISK}\" )"
          else
            THISMSG="${THISMSG})"
          fi
        fi
      fi
      OVERLAY_ALREADY_IN_PLACE=${__TRUE}
    fi

# 
# check if there are one or more overlay mounts for sub directries in this directory
#
    if [ ${OVERLAY_ALREADY_IN_PLACE} != ${__TRUE} ] ; then          
      CUR_OVERLAY_MOUNTS="$( mount  | grep "^overlay" | grep "${CUR_DIR}/" | grep -v "/merged/" | cut -f3 -d " "  | tr "\n" " "  )"
      if [ "${CUR_OVERLAY_MOUNTS}"x != ""x ] ; then
        LogError "There are already overlay mounts in place for sub directories in \"${CUR_DIR}\" : " "${CUR_OVERLAY_MOUNTS}"

        OVERLAY_ALREADY_IN_PLACE=${__TRUE}
      fi                  
    fi


    if [ ${OVERLAY_ALREADY_IN_PLACE} = ${__TRUE} ] ; then          
      LogMsg "${THISMSG}"
#
# change the global variables
#
      OVERLAY_MOUNTS_ALREADY_CREATED="${OVERLAY_MOUNTS_ALREADY_CREATED}
  ${CUR_DIR}"
      (( NO_OVERLAY_MOUNTS_ALREADY_CREATED = NO_OVERLAY_MOUNTS_ALREADY_CREATED + 1 ))
      continue
 
    fi

#
# there is no overlay mount in place for this directory --> create the overlay mount
#

    OVERLAY_SUBDIR="/$( create_dir_name_for_the_overlay_filesystem "${CUR_DIR}" )"

#
# DIRECTORIES_CREATED is a global variable: the function create_directory adds the name of the directories created to this variable
#
    DIRECTORIES_CREATED=""

    create_directory "${BASEDIR}/upper${OVERLAY_SUBDIR}" && \
      set_permissions "${CUR_DIR}" "${BASEDIR}/upper${OVERLAY_SUBDIR}" && \
      set_selinux_context "${CUR_DIR}" "${BASEDIR}/upper${OVERLAY_SUBDIR}" || \
      die 50 "Error creating the directory \"${BASEDIR}/upper${OVERLAY_SUBDIR}\""

    create_directory "${BASEDIR}/merged${OVERLAY_SUBDIR}" && \
      set_permissions "${CUR_DIR}" "${BASEDIR}/upper${OVERLAY_SUBDIR}" && \
      set_selinux_context "${CUR_DIR}" "${BASEDIR}/merged${OVERLAY_SUBDIR}" || \
      die 55 "Error creating the directory \"${BASEDIR}/merged${OVERLAY_SUBDIR}\""

    create_directory "${BASEDIR}/work${OVERLAY_SUBDIR}" && \
      set_permissions "${CUR_DIR}" "${BASEDIR}/upper${OVERLAY_SUBDIR}" && \
      set_selinux_context "${CUR_DIR}" "${BASEDIR}/work${OVERLAY_SUBDIR}" ||  \
      die 60 "Error creating the directory \"${BASEDIR}/work${OVERLAY_SUBDIR}\""
 
    LogMsg "Creating the overlay mount for \"${CUR_DIR}\" ..."


    LogInfo "The overlay directory used for the directory \"${CUR_DIR}\" is  " && \
      ls -ldZ "${BASEDIR}/merged${OVERLAY_SUBDIR}"

#
# retrieve the list of mount points in the directory (we must remount them later after creating the bind mount)
#
    SUB_MOUNT_POINTS="$( mount | grep " ${CUR_DIR}/" | grep "^/dev/block/sd" | tr "\t" " " | tr -s " " | cut -f3 -d  " " | sort | uniq )"

# 
# create the overlay mount
#
    [[ ${VERBOSE} = ${__TRUE} ]] && set -x 
    ${MOUNT} -t overlay overlay -o "lowerdir=${CUR_DIR},upperdir=${BASEDIR}/upper${OVERLAY_SUBDIR},workdir=${BASEDIR}/work${OVERLAY_SUBDIR}" "${BASEDIR}/merged${OVERLAY_SUBDIR}"
    TEMPRC=$?
    [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x 

    if [ ${TEMPRC} -ne 0 ] ; then
      LogError "Error creating the overlay mount for \"${CUR_DIR}\" "

      OVERLAY_MOUNTS_NOT_CREATED="${OVERLAY_MOUNTS_NOT_CREATED}
${CUR_DIR}"
      (( NO_OVERLAY_MOUNTS_NOT_CREATED = NO_OVERLAY_MOUNTS_NOT_CREATED + 1 ))

      if [ "${DIRECTORIES_CREATED}"x != ""x ] ; then
        LogInfo "Deleting the directories just created for this overlay mount" 
        rm -rf ${DIRECTORIES_CREATED}
      fi

      continue
    fi

#
# create the bind mount
#
    LogMsg "Creating the bind mount \"${CUR_DIR}\"..."
 
    [[ ${VERBOSE} = ${__TRUE}  ]] && set -x 
    ${MOUNT} -o bind "${BASEDIR}/merged${OVERLAY_SUBDIR}" "${CUR_DIR}"
    TEMPRC=$?
    [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x 

    if [ ${TEMPRC} -ne 0 ] ; then
      LogError "Error creating the bind mount for \"${CUR_DIR}\" "
#
# change the global variables
#
      OVERLAY_MOUNTS_NOT_CREATED="${OVERLAY_MOUNTS_NOT_CREATED}
${CUR_DIR}"
      (( NO_OVERLAY_MOUNTS_NOT_CREATED = NO_OVERLAY_MOUNTS_NOT_CREATED + 1 ))

      continue
    fi

# 
# remount mount points in the directory if there are any
#
    for CUR_MOUNT_POINT in ${SUB_MOUNT_POINTS} ; do
      LogMsg "Remounting the mount point \"${CUR_MOUNT_POINT}\" ... "
      CUR_LINE="$( grep " ${CUR_MOUNT_POINT} " /proc/mounts | tr "\t" " " | tr -s " " )"
      if [ "${CUR_LINE}"x = ""x ] ; then
        LogWarning "No config for \"${CUR_MOUNT_POINT}\" in \"/proc/mounts\" found"
        continue
      fi
      
      CUR_SUB_MOUNT_DEVICE="$( echo "${CUR_LINE}" | cut -f1 -d " " )"
      CUR_SUB_MOUNT_FILESYSTEM_TYPE="$( echo "${CUR_LINE}" | cut -f3 -d " " )"
      CUR_SUB_MOUNT_OPTIONS="$( echo "${CUR_LINE}" | cut -f4 -d " " )"

      [[ ${VERBOSE} = ${__TRUE} ]] && set -x 
      
      mount -t "${CUR_SUB_MOUNT_FILESYSTEM_TYPE}" -o "${CUR_SUB_MOUNT_OPTIONS}" "${CUR_SUB_MOUNT_DEVICE}" "${CUR_MOUNT_POINT}"
      TEMPRC=$?
      [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x 

      if [ ${TEMPRC} -ne 0 ] ; then
        LogError "Error mounting  \"${CUR_MOUNT_POINT}\" to  \"${CUR_SUB_MOUNT_DEVICE}\"  "
      fi
    done

#
# check the file permissions in the bind mount
#
    LogMsg "Checking the overlay mount for \"${CUR_DIR}\" ..."
    ls -ltr "${CUR_DIR}" | grep -- "----------"  2>/dev/null >/dev/null 
    if [ $? -eq 0 ] ; then
      LogWarning "Seems like the overlay mount for \"${CUR_DIR}\" works only partial -- please check the directory contents"
    fi

    LogInfo "The permissions for the directory \"${CUR_DIR}\" are now  " && \
      LogMsg "$( ls -ldZ "${CUR_DIR}" 2>&1 )"
#
# change the global variables
#
    OVERLAY_MOUNTS_CREATED="${OVERLAY_MOUNTS_CREATED}
  ${CUR_DIR}"
      (( NO_OVERLAY_MOUNTS_CREATED = NO_OVERLAY_MOUNTS_CREATED + 1 ))

  done
}

# ---------------------------------------------------------------------
# create_list_of_mounted_overlays
#
# usage: 
#   create_list_of_mounted_overlays
#
# returns:
#   ${__TRUE} - at least one overlay mount found
#   ${__FALSE} - no overlay mounts found
#
#   The global variable CUR_OVERLAY_FILESYSTEMS contains the list of mount overlays
#   The global variable ALL_OVERLAY_MOUNTS contains the list of all overlay mounts
#
function create_list_of_mounted_overlays {
  typeset __FUNCTION="create_list_of_mounted_overlays"

  typeset THISRC=${__FALSE}

  typeset CUR_DIR=""
  typeset CUR_DEVICE=""
 
  typeset THIS_OVERLAY_MOUNTS=""
  typeset LIST_OF_OVERLAY_MOUNTS=""

#
# init the global variables
#
  CUR_OVERLAY_FILESYSTEMS=""
  ALL_OVERLAY_MOUNTS=""

#
# retrieve the list of active overlay mounts
#
  LIST_OF_OVERLAY_MOUNTS="$( df  -h | grep "^overlay" )"
  
#
# set the global variables
#
  THIS_OVERLAY_MOUNTS="$( echo "${LIST_OF_OVERLAY_MOUNTS}" | sed -e "s#.*/##g"  -e "s/#/\//g" -e "s#^#/#g" )"

  ALL_OVERLAY_MOUNTS="$( echo "${LIST_OF_OVERLAY_MOUNTS}" | tr "\t" " " | tr -s " " | cut -f6 -d " " )"

  LogInfo "ALL_OVERLAY_MOUNTS is now:" &&  \
    LogMsg "${ALL_OVERLAY_MOUNTS}"

  LogInfo "THIS_OVERLAY_MOUNTS is now:" &&  \
    LogMsg "${THIS_OVERLAY_MOUNTS}"

  for CUR_DIR in ${THIS_OVERLAY_MOUNTS} ; do

    CUR_DEVICE="$( get_mount_device "${CUR_DIR}"  )"
 
    LogInfo "\"${CUR_DIR}\" is mounted on \"${CUR_DEVICE}\" "

    if [ "${CUR_DEVICE}"x = "overlay"x ] ; then
      CUR_OVERLAY_FILESYSTEMS="${CUR_OVERLAY_FILESYSTEMS}
${CUR_DIR}"
      THISRC=${__TRUE}
    fi
  done

  CUR_OVERLAY_FILESYSTEMS="$( echo "${CUR_OVERLAY_FILESYSTEMS}" | grep -E -v "^$" )"

  LogInfo "CUR_OVERLAY_FILESYSTEMS is now:" &&  \
    LogMsg "${CUR_OVERLAY_FILESYSTEMS}"

  return ${THISRC}
}

# ---------------------------------------------------------------------
# print_summary - print the summary
#
# usage: 
#   print_summary
#
# returns:
#   0
#
# the variables used in this function are all global variables
#
function print_summary {
  typeset __FUNCTION="print_summary"


  LogMsg
  LogMsg "Summary:"
  LogMsg "--------"

  if [ ${NO_OVERLAY_MOUNTS_CREATED} != 0 ] ; then
    LogMsg
    LogMsg "${NO_OVERLAY_MOUNTS_CREATED} overlay mount(s) created:"
    LogMsg "${OVERLAY_MOUNTS_CREATED}"
  fi

  if [ ${NO_OVERLAY_MOUNTS_ALREADY_CREATED} != 0 ] ; then
    LogMsg
    LogMsg "${NO_OVERLAY_MOUNTS_ALREADY_CREATED} directory or files are already on an overlay mount:"
    LogMsg "${OVERLAY_MOUNTS_ALREADY_CREATED}"
  fi

  if [ ${NO_OVERLAY_MOUNTS_NOT_CREATED} != 0 ] ; then
    LogMsg
    LogMsg "${NO_OVERLAY_MOUNTS_NOT_CREATED} overlay mount(s) not created because of an error:"
    LogMsg "${OVERLAY_MOUNTS_NOT_CREATED}"
  fi

  if [ ${NO_OF_DIRECTORIES_MISSING} != 0 ] ; then
    LogMsg
    LogMsg "${NO_OF_DIRECTORIES_MISSING} directory(s) missing:"
    LogMsg "${DIRECTORIES_MISSING}"
  fi
}

# ---------------------------------------------------------------------
# print_environment_variables - print the list of supported environment variables
#
# usage: 
#   print_environment_variables
#
# returns:
#   0
#
function print_environment_variables {
  typeset __FUNCTION="print_environment_variables"


  typeset  NAME_FIELD_LENGTH=10
  typeset CUR_VAR=""

  typeset CUR_ENVIRONMENT_VARIABLES="$( echo "${ENVIRONMENT_VARIABLES}" | sort )"
  
  echo
  echo "Supported environment variables:"
  echo

#
# calculate the size of the field for the variable name
#
  for CUR_VAR in ${CUR_ENVIRONMENT_VARIABLES} ; do
    [ ${#CUR_VAR} -gt ${NAME_FIELD_LENGTH} ] && NAME_FIELD_LENGTH="${#CUR_VAR}"
  done

  let NAME_FIELD_LENGTH=NAME_FIELD_LENGTH+5
  printf "%-${NAME_FIELD_LENGTH}s %s\n" "Name" "Default Value"
  printf "%-${NAME_FIELD_LENGTH}s %s\n" "----" "-------------"
  for CUR_VAR in ${CUR_ENVIRONMENT_VARIABLES} ; do
    printf "%-${NAME_FIELD_LENGTH}s %s\n" "${CUR_VAR}" "$( eval echo "\$DEFAULT_${CUR_VAR}" )"
  done

  echo
}
 
# ---------------------------------------------------------------------
# main function
#

# ----------------------------------------------------------------------
# enable verbose mode if requested
#

if [[ " $* " == *\ -v\ * || " $* " == *\ --verbose\ *  ]] ; then
  VERBOSE=${__TRUE}
  CHCON_PARAMETER="-v"
fi

# ----------------------------------------------------------------------
# print the current value of the supported environment variables
#
if [ ${VERBOSE}x = ${__TRUE}x ] ; then
  LogInfo "Values of the used environment variables BEFORE processing the parameter:"
  for CUR_VAR in ${ENVIRONMENT_VARIABLES} ; do
    echo "The current value of the variable \"${CUR_VAR}\" is \"$( eval echo \$${CUR_VAR} )\" " 
  done
fi

# ----------------------------------------------------------------------
# return code of the script

MAIN_RC=0

# ----------------------------------------------------------------------
#
# process the parameter
#

VERBOSE_USAGE_HELP=${__FALSE}

NEW_SELINUX_MODE=""

INIT_DISK=${__FALSE}

DIRECTORY_FOUND_IN_THE_PARAMETER=${__FALSE}

SHORT_INFOS=${__FALSE}

EXTERNAL_USE=${__FALSE}

PROCESS_ONLY_MOUNTED_OVERLAY_FILESYSTEMS=${__FALSE}

IGNORE_MAGISK=${__FALSE}

if [ $# -ne 0 ] ; then

  LogInfo "Processing the parameter ..."

  LogInfo "The parameter for the script are "  && \
    LogMsg "$*"

  while [ $# -ne 0 ] ; do
    CUR_PARAMETER="$1"
    shift

    case ${CUR_PARAMETER}  in

      -h | --help )
        ACTION="help"
        ;;

      help )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "      
        ACTION="help"
        VERBOSE_USAGE_HELP=${__TRUE}
        ;;

      vars | list_vars )
        ACTION="print_vars"
        ;;

     --active )
        PROCESS_ONLY_MOUNTED_OVERLAY_FILESYSTEMS=${__TRUE}
        ;;

     --nomagisk )
        IGNORE_MAGISK=${__TRUE}
        ;;

     --details )
        PRINT_MORE_DETAILS=${__TRUE}
        ;;

      --short )
        SHORT_INFOS=${__TRUE}        
        ;;

      *=* )
        LogInfo "Executing now \"${CUR_PARAMETER}\" ..."
        CUR_VAR="${CUR_PARAMETER%%=*}"
        CUR_VAL="${CUR_PARAMETER#*=}"
        eval ${CUR_VAR}=\"${CUR_VAL}\"
        if [ $? -ne 0 ] ; then
          die 70 "Error executing \"${CUR_PARAMETER}\" "
        fi
        ;;

      -V | --version )
        ACTION="version"
         ;;
 
      list )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="list"
        ;;

      clean )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="clean"
        ;;

      get )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="get"
        ;;

      restore )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="restore"
        ;;

      diff )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="diff"
        ;;

      umount )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="umount"
        ;;

      undo )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="undo"
        ;;

      mount )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="mount"
        ;;

      remount )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="remount"
        ;;

      mount_only )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="mount_only"

        ;;

      test )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="test"
        ;;

      --initdisk | --format )
        INIT_DISK=${__TRUE}
        ;;
 
      --verbose | -v )
        VERBOSE=${__TRUE}
        ;; 

      ++verbose | +v )
        VERBOSE=""
        ;; 

      --noselinux | --no_selinux | --disable_selinux )
        NEW_SELINUX_MODE="Permissive"
        ;;

      --selinux | --selinux | --enable_selinux )
        NEW_SELINUX_MODE="Enforcing"
        ;;

      --* | -* )
        die 80 "Unknown parameter found: ${CUR_PARAMETER}"
        ;;

      * )
        DIRECTORY_FOUND_IN_THE_PARAMETER=${__TRUE}

        case ${CUR_PARAMETER} in
          default )
            DIRS_TO_OVERLAY="${DIRS_TO_OVERLAY} ${DEFAULT_DIRS_TO_OVERLAY}"
            ;;

          none ) 
            DIRS_TO_OVERLAY=""
            ;;

          /* )
           if [[ ${CUR_PARAMETER} == *'#'* ]] ; then
             die 81 "Directory names with a hash \"#\" are not supported (${CUR_PARAMETER})"
           fi
           DIRS_TO_OVERLAY="${DIRS_TO_OVERLAY} ${CUR_PARAMETER}"
           ;;

          * ) 
            die 90 "Unknown parameter found: \"${CUR_PARAMETER}\" " 
            ;;

        esac
        ;;

    esac
  done
fi

#
# default action if there is no directory in the parameter is to print the usage help
#

if [ "${ACTION}"x = ""x ] ; then
  if [ "${DIRS_TO_OVERLAY}"x != ""x ] ; then
    LogInfo "Directories found in the parameter: The default action is mount"
    ACTION="mount"
  else
    LogInfo "No directories found in the parameter: The default action is help"
    ACTION="help"
  fi
fi

LogInfo " ... parameter processing done"

# ----------------------------------------------------------------------
# use user defined binaries only if the variables are defined
#
[ "${BIND_MOUNT_TARGET_DIR}"x = ""x ] && BIND_MOUNT_TARGET_DIR="${DEFAULT_BIND_MOUNT_TARGET_DIR}"

[ "${LOSETUP}"x = ""x ] && LOSETUP="${DEFAULT_LOSETUP}"
[ "${MOUNT}"x = ""x ]   && MOUNT="${DEFAULT_MOUNT}"
[ "${UMOUNT}"x = ""x ]  && UMOUNT="${DEFAULT_UMOUNT}"
[ "${MKFS}"x = ""x ]    && MKFS="${DEFAULT_MKFS}"
[ "${DD}"x = ""x ]      && DD="${DEFAULT_DD}"

LogInfoVar LOSETUP 
LogInfoVar MOUNT 
LogInfoVar UMOUNT 
LogInfoVar MKFS 
LogInfoVar DD

# ----------------------------------------------------------------------
# use default values for the variables if necessary

UMOUNT_WAIT_TIME="${UMOUNT_WAIT_TIME:=${DEFAULT_UMOUNT_WAIT_TIME}}"

if [ "${DIRS_TO_OVERLAY}"x = ""x ] ; then
  DIRS_TO_OVERLAY="${DEFAULT_DIRS_TO_OVERLAY}"

  LogInfo "Using the default list of directories to overlay \"${DIRS_TO_OVERLAY}\" (variable DIRS_TO_OVERLAY)"
else
  LogInfo "Using this list of directories to overlay \"${DIRS_TO_OVERLAY}\" (variable DIRS_TO_OVERLAY)"
fi

if [ "${BASEDIR}"x = ""x ] ; then
  BASEDIR="${DEFAULT_BASEDIR}"

  LogInfo "Using the default base directory \"${BASEDIR}\" (variable BASEDIR)"
else
  LogInfo "Using the base directory \"${BASEDIR}\" (variable BASEDIR)"
fi

if [ "${IMAGE_FILE}"x = ""x ] ; then
  IMAGE_FILE="${DEFAULT_IMAGE_FILE}"

  LogInfo "Using the default image file \"${IMAGE_FILE}\" (variable IMAGE_FILE)"
else
  LogInfo "Using the image file \"${IMAGE_FILE}\" (variable IMAGE_FILE)"
fi

if [ "${FILESYSTEM_SIZE}"x = ""x ] ; then
  FILESYSTEM_SIZE="${DEFAULT_FILESYSTEM_SIZE}"

  LogInfo "Using the default size for the image file \"${FILESYSTEM_SIZE}\" (variable FILESYSTEM_SIZE)"
else
  LogInfo "Using the size for the image file \"${FILESYSTEM_SIZE}\" (variable FILESYSTEM_SIZE)"
fi

if [ "${MKFS_OPTIONS}"x = ""x ] ; then
  MKFS_OPTIONS="${DEFAULT_MKFS_OPTIONS}"

  LogInfo "Using the default options for the mkfs* command to create the filesystem on the loop device \"${MKFS_OPTIONS}\" (variable MKFS_OPTIONS)"
else
  LogInfo "Using the options \"${MKFS_OPTIONS}\" for the mkfs* command to create the filesystem on the loop device (variable MKFS_OPTIONS)"
fi

if [ "${MOUNT_OPTIONS}"x = ""x ] ; then
  MOUNT_OPTIONS="${DEFAULT_MOUNT_OPTIONS}"

  LogInfo "Using the default mount options to mount the loop device \"${MOUNT_OPTIONS}\" (variable MOUNT_OPTIONS)"
else
  LogInfo "Using the mount options \"${MOUNT_OPTIONS}\" to mount the loop device (variable MOUNT_OPTIONS)"
fi


if [ "${FILESYSTEM_TO_USE}"x = ""x ] ; then
  FILESYSTEM_TO_USE="${DEFAULT_FILESYSTEM_TO_USE}"

  LogInfo "Using the default filesystem type \"${FILESYSTEM_TO_USE}\" (variable FILESYSTEM_TO_USE)"
else
  LogInfo "Using the filesystem type \"${FILESYSTEM_TO_USE}\" (variable FILESYSTEM_TO_USE)"
fi


if [ "${SELINUX_CONTEXT}"x = ""x ] ; then
  SELINUX_CONTEXT="${DEFAULT_SELINUX_CONTEXT}"

  LogInfo "Using the default SELinux context \"${SELINUX_CONTEXT}\" (variable SELINUX_CONTEXT)"
else
  LogInfo "Using the SELinux context \"${SELINUX_CONTEXT}\" (variable SELINUX_CONTEXT)"
fi

# ---------------------------------------------------------------------
# retrieve the list of directories currently mounted on an overlay filesystem
#
create_list_of_mounted_overlays

if [ ${PROCESS_ONLY_MOUNTED_OVERLAY_FILESYSTEMS} = ${__TRUE} -a ${DIRECTORY_FOUND_IN_THE_PARAMETER} = ${__FALSE} -a "${ACTION}"x != "mount"x ] ; then
  LogInfo "option \"--active\" found in the parameter -- now processing only the mounted overlay filesystems.."
  DIRS_TO_OVERLAY="${CUR_OVERLAY_FILESYSTEMS}"
fi
        
# ---------------------------------------------------------------------
#
# delete duplicate entries in the list of directories
#
LogInfo "Deleting duplicate entries from the list of directories/files ..."

NEW_DIRS_TO_OVERLAY=""

for CUR_DIR in ${DIRS_TO_OVERLAY} ; do
#
# remove trailing slash "/"
 [[ ${CUR_DIR} = */ ]] && CUR_DIR="${CUR_DIR%*/}"
 
 [[ " ${NEW_DIRS_TO_OVERLAY} " != *\ ${CUR_DIR}\ * ]] && NEW_DIRS_TO_OVERLAY="${NEW_DIRS_TO_OVERLAY} ${CUR_DIR}"
done

LogInfo "The list of directories to process was: \"${DIRS_TO_OVERLAY}\" "
LogInfo "The list of directories to process is now: \"${NEW_DIRS_TO_OVERLAY}\" "

DIRS_TO_OVERLAY="${NEW_DIRS_TO_OVERLAY}"

# ---------------------------------------------------------------------


# ---------------------------------------------------------------------
# first check for actions that can be executed by any user
#
case ${ACTION} in

  help )
    grep "^#h#" $0 | cut -c4- | sed -e "s#<VERSION>#${SCRIPT_VERSION}#g"

    if [ ${VERBOSE}x = ${__TRUE}x -o  ${VERBOSE_USAGE_HELP}x = ${__TRUE}x ] ; then
      grep "^#H#" $0 | cut -c4- 
 
      print_environment_variables
    fi
    die 0
    ;;

  print_vars )
    print_environment_variables
    die 0
    ;;

  version )
    echo "${SCRIPT_VERSION}"
    die 0
    ;;

  list )
    [ ${DIRECTORY_FOUND_IN_THE_PARAMETER} = ${__TRUE} ] && \
      die 75 "Directory parameter are not allowed for the action \"${ACTION}\" " 
  
    if [ ${PRINT_MORE_DETAILS} = ${__TRUE}  ] ; then
      ${LOSETUP} -a 2>/dev/null 1>/dev/null
      if [ $? -ne 0 ] ; then
        die 76 "For the action \"list\" with the option \"--details\" is root access required"
      fi
    fi
    
    list_overlay_mounts
    die $?
    ;;

esac

# ---------------------------------------------------------------------
# all other actions need root access
#


# check the prerequisites for the other actions 

CUR_USER="$( id -un )"

if [ "${CUR_USER}"x != "root"x ] ; then
  die 250 "The script \"$0\" must be executed by the root user (the current user is \"${CUR_USER}\")"
fi

LogInfo "The filesystems supported in the running OS are: " && \
  LogMsg "$( cat /proc/filesystems 2>&1 | grep -E -v "^nodev" )"

grep overlay /proc/filesystems >/dev/null
if [ $? -ne 0 ] ; then
  die 251 "overlay filesystems are not supported in the running OS"
fi

grep "${FILESYSTEM_TO_USE}" /proc/filesystems >/dev/null
if [ $? -ne 0 ] ; then
  die 252 "${FILESYSTEM_TO_USE} filesystems are not supported in the running OS"
fi

if [ "${MKFS}"x = ""x ] ; then
  MKFS="$( which mkfs.${FILESYSTEM_TO_USE} )"
fi



# ---------------------------------------------------------------------
# correct the SELinux status if requested via parameter
#
if [ "${NEW_SELINUX_MODE}"x != ""x  ] ; then
  CUR_SELINUX_MODE="$( getenforce )"

  if [ "${CUR_SELINUX_MODE}"x = "${NEW_SELINUX_MODE}"x ] ; then
    LogInfo "SELinux is already \"${CUR_SELINUX_MODE}\" "
  else
    LogMsg "Changing SELinux status to  \"${NEW_SELINUX_MODE}\""
    setenforce "${NEW_SELINUX_MODE}"
  fi
fi

CUR_SELINUX_MODE="$( getenforce )"
if [ "${CUR_SELINUX_MODE}"x = "Permissive"x ] ; then
  LogInfo "SELinux is currently disabled"
else
  LogInfo "SELinux is currently enabled"
fi

# ---------------------------------------------------------------------

case ${ACTION} in

  get )
   MAIN_RC=0

   EXTERNAL_USE=${__TRUE}
   for CUR_ENTRY in ${DIRS_TO_OVERLAY} ; do
     get_file_overlay "${CUR_ENTRY}" 
     [ $? -gt 3 ] && MAIN_RC=1
   done
   unset EXTERNAL_USE
   ;;

  restore )
    if [ ${DIRECTORY_FOUND_IN_THE_PARAMETER} != ${__TRUE} ] ;then
      LogError "The action \"restore\" needs at least one file or directory name"
      MAIN_RC=1
    else
      restore_files
      MAIN_RC=$?
    fi
    ;;
   
  undo )
    undo_file_changes
    MAIN_RC=$?
    ;;

  diff )
    list_file_changes 
    MAIN_RC=$?
    ;;

  umount )
    umount_overlay_mounts
    MAIN_RC=$?
    ;;

  remount )
    remount_overlay_mounts
    MAIN_RC=$?
    ;;

  test )
    test_overlay_mounts
    MAIN_RC=$?
    ;;

  clean )
    [ ${DIRECTORY_FOUND_IN_THE_PARAMETER} = ${__TRUE} ] && \
      die 75 "Directory parameter are not allowed for the action \"${ACTION}\" " 
  
    umount_overlay_mounts || \
       die 100 "clean config requested but umounting the overlay filesystems failed"
    clean_mount_config
    MAIN_RC=$?
    ;;

  mount | mount_only )
    if [ ${INIT_DISK} = ${__TRUE} ] ; then
      LogMsg "Initializing the virtual disk requested -- now umounting all overlay filesystems ..."
      umount_overlay_mounts || \
        die 100 "init disk requested but umounting the overlay filesystems failed"
    fi

#
# create the image file
#
    mount_virtual_disk
    if [ "${ACTION}"x != "mount_only"x ] ; then
      create_overlay_directory_tree
      create_overlay_mounts
      print_summary
    else
      LogMsg ""
      LogMsg "The virtual disk is mounted to \"${BASEDIR}\" "
    fi
    ;;

esac

LogMsg ""

die ${MAIN_RC}

