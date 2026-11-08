#!/system/bin/sh
#
#h#
#h# create_overlay_mount.sh <VERSION> - create overlay mounts on a device running a rooted Android OS
#h#
#h# Usage:  create_overlay_mount.sh [-h|--help] [-V|--version] [--verbose|-v] [--noselinux] [--selinux] [--no_relabel|--relabel] [--initdisk|--format] [--no_su] [--sparse]
#h#                                 [--yes|-y] [--no|-n] [--no_rootfs] [-r|--relax] [-d|--details]  [--short] [--active] [--nomagisk] [--patch] [var=value] [--run=script[,..,script#]] [help] [vars]
#h#                                 [list] [list_disk] [delete] [test] [undo] [diff] [diff_file] [get] [restore] [clean] [mount_only] [mount] [mount_existing] [umount] [remount]
#H#                                 [directory0] [... directory#] [default]
#H#
#H# The parameter that neither start with a "-" or "/" nor contain a "=" are the action parameter that determine what is to be done.
#H# Only one action parameter for a run is allowed.
#H#
#H# Without an action parameter the script prints the short usage help. If one or more directories are found in the parameter the default action is "mount".
#H#
#H# The script needs root access.
#H#
#H# If started as non-root user, the script restarts itself using "su -c $0 $@" if possible; use the parameter "--no-su" to disable this feature.
#H#
#H# All parameter starting with a "/" are considered to be a directory name (or filename for some of the actions)
#H# The parameter with the directory names are optional.
#H#
#H# The default directory list for the actions "mount", "diff", "get" and "undo" is the list of directories in the environment variable DIRS_TO_OVERLAY.
#H# The default directory list for the actions "test", "umount", and "remount" is the list of directories currently mounted to an overlay filesystem.
#H#
#H# There are no default values for the action "restore".
#H#
#H# "directory" parameter are not allowed for the actions "mount_only", "mount_existing", and "list". If the parameter "--relax" is used
#H# these action ignore "directory" parameter.
#H#
#H# The actions "vars" and "help" only print help messages.
#H#
#H# If the variable DIRS_TO_OVERLAY is empty the script uses the hardcoded default value for this variable:
#H#
#H#   /system_ext  /product  /odm  /system
#H#
#H# "directory#" must be either "default", "none", or the fully qualified directory name of a directory.
#H# The value "none" deletes the current list of directories in the variable DIRS_TO_OVERLAY; the value "default" adds the default directories to the list
#H# of directories. The parameter can be used more than once.
#H#
#H# The known option parameter are:
#H#
#H# --version      print the script version and exit
#H# --verbose      print more messages
#H# --noselinux    disable SELinux at start of the script (SELinux is NOT enabled again by the script)
#H# --selinux      enable SELinux at start of the script (SELinux is NOT disabled again by the script)
#H# --no_relabel   do not modify the SELinux context for files with unlabeled or default SELinux context in the overlay filesystem
#H# --relabel      modify the SELinux context for files with unlabeled or default SELinux context in the overlay filesystems
#H#                The default is not to relabel.
#H# --initdisk     format the virtual disk before creating the overlay mounts; this will undo all previous modifications in the filesystems
#H#                Without this option the script never formats an existing virtual disk.
#H# --no_su        do not restart the script as user root automatically
#H# --sparse       create the virtual disk as a sparse file
#H# --yes          answer all questions with "yes"
#H# --no           answer all questions with "no"
#H# --no_rootfs    do not mount the original devices to ${BASEDIR}/rootfs; note that without these mounts the action "diff_file" does not work
#H# --relax        ignore parameter that are not a directory (e.g. symbolic links); ignore parameter that are not used for an action
#H# --details      print more details
#H# --short        print only the important information
#H# --active       the tasks diff, get, and undo should work only on the currently mounted overlay filesystems
#H# --nomagisk     do not create temporary bind mounts for the Magisk binaries; without this parameter the script creates temporary
#H#                bind mounts for the executables magisk, su, resetprop, and magiskpolicy if Magisk is installed and an overlay filesystem
#H#                should be created for the directory with these executables.
#H# --patch        write the output of the diff commands (action "diff_file") to a file. The directory for the patch files is defined
#H#                in the variable PATCH_DIR. The name of the patch file is the fully qualified filename with blanks and slashes ("/")
#H#                replaced with underscores ("_")
#H#                Existing patch files are renamed to "[filename].$$.bak"
#H# --run          run the executable "script" if it exists after the overlay mounts are in place. "script" can be any executable.
#H#                The parameter can be used multiple times; Note that "--script" is an alias for "--run".
#H#                Ths option is only used for the action "mount".
#H#
#H# Options, that are not used for an action, are silently ignored. For example, the option "--patch" is only used for the action "diff_file".
#H#
#H# The known action parameter are:
#H#
#H# help           print verbose usage help
#H# vars           print only the list of supported environment variables; the script prints the default values and the current values of these variables
#H# list           list directories mounted on overlay filesystems
#H# list_disk      list all directories available on the virtual disk mounted to ${BASEDIR}; use the option "--details" to print the details for the directories
#H# delete         delete the overlay directories for a directory on the virtual disk
#H# test           test write access to directories mounted on overlay filesystems;
#H#                default is: test write access to all directories currently mounted on an overlay filesystems
#H# get            print the name of the backend used for a file or directory mounted on an overlay filesystem
#H# undo           undo all modifications done in a directory with an overlay mount; be aware that there is NO redo action!
#H#                default is: undo all modifications done for all directories in the environment variable DIRS_TO_OVERLAY (regardless of the mount status)
#H# diff           list the file modifications for directories with overlay mounts
#H#                default is: list the modifications done for all directories in the environment variable DIRS_TO_OVERLAY (regardless of the mount status)
#H#                Use the option "--active" to list only the files with modifications in the directories with an active overlay mount
#H#                Use the opton "--short" to only print the number of modified or deleted files
#H#                Use the option "--details" for a verbose list of the modified files
#H# diff_file      compare one or more new files to the existing files using diff; the task parameter can be files or directories
#H#                use a trailing double slash (//) to executed diff for all files in the sub directories of a directory
#H#                set the environment variable DIFF to specify the diff executable to use; use the environment variable DIFF_OPTIONS to define the
#H#                options for the diff command; use the option "--short" to disable the summary output; use the option "--patch" to write the diff output
#H#                to files (see above for details).
#H# restore        restore files or directories in a directory mounted on an overlay filesystem
#H#
#H# mount_only     mount the virtual disk and exit (do not create an overlay mount)
#H#                The script does not relabel files if the parameter "mount_only" is used (even if there are relabel files in the overlay filesystems).
#H#                To force relabeling the files when "mount_only" is used, add the option "--relabel"
#H#
#H# mount          mount the overlays for the directories
#H# mount_existing mount only the existing overlay filesystems on the virtual disk; this action will fail if there are conflicting entries on the virtual disk
#H#                e.g. an entry for "/system" and "/system/etc"
#H# umount         umount the overlays for the directories; default is to umount all overlay mounts
#H# remount        remount the overlay mounts
#H#
#H# clean          umount all overlay mounts and umount the virtual disk
#H#
#H# Other supported parameter:
#H#
#H# var=value sets the variable "var" to the value "value"
#H#
#H#
#H# The script can create temporary bind mounts for files that will no longer be available after an overlay mount is created for a directory. This
#H# applies, for example, to files created by a Magisk module.
#H#
#H# To create bind mounts for files before the overlay mounts are created, add the file names to the environment variable FILES_TO_KEEP.
#H#
#H# The number of filenames in the variable FILES_TO_KEEP is not limited; the filenames must be separated by white spaces or commas.
#H#
#H# The filenames in the variable FILES_TO_KEEP are interpreted by the script using these rules:
#H#
#H# - filenames without a slash are searched in the directory "/system/bin",     Example:  bash -> /system/bin/bash
#H#
#H# - filenames starting with "bin/" are searched in the directory "/system",    Example:  bin/sh -> /system/bin/sh
#H#
#H# - filenames starting with "./" are searched in the directory "/system",      Example:  ./etc/ssh/sshd_config  -> /system/./etc/ssh/sshd_config
#H#
#H# - fully qualified names are searched in "/",                                 Example:  /system_ext/bin/rsync -> /system_ext/bin/rsync
#H#
#H# All files in other directories than /system must be specified with fully qualified filename.
#H#
#H# bind mounts for the Magisk binaries are created automatically (see the description for the parameter "--nomagisk" above)
#H#
#H# bind mounts for directories are not supported.
#H#
#H# The script creates bind mounts only for files in directories for which an overlay mount is requested.
#H# Other entries in the variable FILES_TO_KEEP are silently ignored
#H#
#H# The bind mounts are created in the directory "/data/local/tmp"; to use another directory for the bind mounts set the environment variable
#H# BIND_MOUNT_TARGET_DIR="<directory_name>"
#H#
#H# Please note that the bind mounts created by the script are not deleted when the overlay mount is removed.
#H# To delete the bind mounts, either manually umount them or simply restart the phone.
#H#
#H# Note:
#H#
#H# The following information is only valid for virtual disks created in an OS other than Android, such as Linux.
#H# For virtual disks created in Android, the following information can be ignored.
#H#
#H# --------------------------------------------------------------------
#H#
#H# For virtual disks created on operating systems other than Android, the SELinux context for most files and directories on the virtual disk is
#H# “system_u:object_r:unlabeled_t:s0” or “unconfined_u:object_r:default_t:s0” or something similar. Because of this SELinux context, these files
#H# cannot be accessed by users without root privileges.
#H# Therefore, it is essential to correct the SELinux context for these files before they can be used.
#H#
#H# The “--relabel” parameter of the script create_overlay_mount.sh can be used for this purpose:
#H#
#H# If the “--relabel” parameter is specified, the script corrects the SELinux context for all files in the overlay directories for all
#H# directories specified in the parameters for the script. The SELinux context used for this modification is the SELinux context of the
#H# target directory for the overlay mount. The script modifies only the files with an SELinux context that matches the expression
#H# "*:unlabeled*" or "*:default:*"-.
#H#
#H# If the SELinux context of the files is to be corrected only for certain overlay file systems, the file “relabel” can be created in
#H# those directories. In this case, the “--relabel” parameter must not be specified.
#H# For the overlay filesystem for /system, this is, for example, the file ./upper/system/relabel. I
#H#
#H# To relabel the files in the overlay filesystem with other SELinux contexts, create a script to modify the SELinux context and
#H# run it as post install script using the parameter "--run=script". The script can also be located on the overlay filesystem.
#H# Do not use the parameter "--relabel" in this case.
#H#
#H#
#H# If the parameter “--norelabel” is specified, the “relabel” files are ignored.
#H#
#H# To correct the SELinux contexts in all overlay filesystems on the virtual disk, the following script command can also be used:
#H#
#H# create_overlay_mount.sh --relabel mount_only
#H#
#H# Using these parameter, the script mounts the virtual disk and corrects the SELinux context for all overlay filesystems on the
#H# virtual disk without mounting the overlay file systems.
#H#
#H# The code for correcting the SELinux context is currently implemented only for overlay filesystems for directories in the root directory
#H# (such as /system, /product, /vendor, etc.)
#H#
#H# Please note that this correction only needs to be performed once for each overlay file system on the virtual hard drive; however,
#H# it does no harm if the code to modify the SELinux context for the files is executed every time the virtual hard drive is mounted.
#H#
#H# For virtual disks created under Android, no correction is necessary.
#H#
#H# --------------------------------------------------------------------
#H#
#H# Overlay mounts are NOT persistent -- if something goes terrible wrong, simply reboot the phone.
#H#
#H# --------------------------------------------------------------------
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
#   28.07.2026 /bs v1.4.0
#     the default mount options are now "-o seclabel"
#     the script now relabels all files with the SELinux context "u:object_r:unlabeled:s0" in the overlay filesystems
#     added the parameter "--no_label" to disable the relabling of unlabeled files
#     added the parameter "--label" to enable the relabling of unlabeled files (this is the default behaviour of the script)
#
#   29.07.2026 /bs v1.4.1
#     the script now fails if there is a filename in the parameter
#     the script now prints a warning if an unknown environment variable is used in the parameter
#     corrected the code to relabel unlabeled files and directories (the previous code failed for symbolic links)
#
#   03.09.2026 /bs v1.5.0
#     added the parameter "--run" to execute post installation scripts or executables
#     added the parameter "mount_existing" to only mount the overlay filesystems that already exist on the virtual disk
#     the code to relabel the files and directories has been rewritten from scratch
#     the automatically relabeling of the overlay filesystem is now disabled
#     now an overlay filesystem is automatically relabeled if the file ./upper/<dir_name>/relabel exists
#
#   28.10.2026 /bs v1.6.0
#     the script now restarts itself using "su -" if started as non-root user if possible
#     added the parameter "--no_su" to disable the automatic restart as user root
#     the script now prints the default value and the current value for the supported environment variables when the parameter "vars" is used
#     the script no longer attempts to create bind mounts for files to be retained if an overlay mount already exists.
#     the script now processes the variable FILES_TO_KEEP if an overlay mount for any directory in / is requested
#     the script now creates bind mounts for the Magisk executables in any directory if necessary
#     added the parameter "--relax"
#     in the previous version of the script you could mount a virtual disk multiple times using different mount points -- that is fixed now
#     the action "clean" now also umounts orphan overlay mounts
#     added the parameter "cleanup"
#
#   08.11.2026 /bs v2.0.0 
#     added the action parameter "diff_file" with the alias "diff_files"
#     added the action "list_disk" to list the directories on a mounted virtual disk
#     added the parameter "--sparse" to create a sparse file
#     added the parameter "--patch"
#     added the parrameter "--yes" and "--no"
#     added the parameter "--no_rootfs"
#     the action "diff" now also prints the number of modified and deleted files and optional only the number of modified and deleted files
#     the action "mount_existing" will now fail if there are conflicting entries on the virtual disk
#     added the environment variables DIFF and DIFF_OPTIONS
#     added the environment variable TMP_MOUNT_OPTIONS
#     added the environment variable PATCH_DIR
#     the script now checks the environment variables SU and BIND_MOUNT_TARGET_DIR to find su if it's not available via the PATH variable
#     the script now creates temporary mounts for the filesystems in the directory ${BASEDIR}/rootfs before creating an overlay mount
#     optimized the code for performance
#     "cleanup" is now an alias for "clean"
#     the code for the action "clean" was rewritten;
#     the action "clean" now umounts all existing overlay mounts and the mount of the BASEDIR
#     the action "umount" now only umounts overlay mounts for the active BASEDIR
#     the script now asks the user for confirmation if the action "undo" without a directory parameter is used
#     added the parameter "delete" to delete the directories on a virtual disk used for overlay filesystems 
#     the action "test" now prints more messages when the parameter "--details" is used
#   

# ----------------------------------------------------------------------
# define some constants
#
__TRUE=0
__FALSE=1

# ----------------------------------------------------------------------


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

# base directory for the temporary bind mounts
# (-> the bind mounts are then created in /data/local/tmp/<directory_name> or in sub directories in this directory)
#
DEFAULT_BIND_MOUNT_TARGET_DIR="/data/local/tmp"


# ----------------------------------------------------------------------
# restart the script as user "root" if running as non-root user
#

SU_ERROR_MESSAGE=""

if [[ " $* " != *\ --no_su\ * &&  " $* " != *\ --no-su\ * ]] ; then
  if [ "$( id -un )"x != "root"x ] ; then
#
# the script is running as non-root user -- check if root access via "su -" is possible
#
    if [ "${SU}"x = ""x ] ; then
      SU="$( which su )"
      
      [ "${SU}"x = ""x -a -x "${BIND_MOUNT_TARGET_DIR}/system/bin/su" ] && SU="${BIND_MOUNT_TARGET_DIR}/system/bin/su"
      [ "${SU}"x = ""x -a -x "${BIND_MOUNT_TARGET_DIR}/product/bin/su" ] && SU="${BIND_MOUNT_TARGET_DIR}/product/bin/su"

      [ "${SU}"x = ""x -a -x "${DEFAULT_BIND_MOUNT_TARGET_DIR}/product/bin/su" ] && SU="${DEFAULT_BIND_MOUNT_TARGET_DIR}/product/bin/su"
      [ "${SU}"x = ""x -a -x "${DEFAULT_BIND_MOUNT_TARGET_DIR}/product/bin/su" ] && SU="${DEFAULT_BIND_MOUNT_TARGET_DIR}/product/bin/su"
      
    fi

    if [ "${SU}"x != ""x ] ; then
      CUR_OUTPUT="$( ${SU} -c uname -a 2>&1 )"
      if [ $? -eq 0 ] ;then
#
# restart the script as user root
#
        exec ${SU} -c "$0 $(printf "'%s' " "$@")"
#
# this code should never run
#
        THISRC=$?
        echo "ERROR: The \"exec\" command failed with RC=${THISRC}"
        exit $?
      else
#
# "su - -c" does not work -- save an error message and ignore the error for now (root access is only required for some of the actions)
#
        SU_ERROR_MESSAGE="Executing a command as user \"root\" via \"${SU} -c \" failed:
${CUR_OUTPUT}"
      fi
    else
      SU_ERROR_MESSAGE="su executable not found"
    fi
  fi
fi

# ----------------------------------------------------------------------
# define default values
#

# read the script version from the script file
#
SCRIPT_VERSION="$( grep  "^#" $0 | grep "/bs v"  | tail -1 | sed "s#.*v#v#g" )"


# The variables starting with the string "DEFAULT_" contain the default values for the various variables that can be
# overwritten by environment variables or parameter (the action "vars" prints all variables with a name starting with DEFAULT_)


#  file used as virtual disk
#
DEFAULT_IMAGE_FILE="/data/local/tmp/image001"

# base directory for the directories necessary for the overlay mounts
# (the virtual disk is mounted on this directory; all user must have read and execute permissions for this directory!)
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

# additional mount options for the temporary mounts
#
DEFAULT_TMP_MOUNT_OPTIONS=""

# default extension for patch files
#
DEFAULT_EXTENSION_FOR_PATCH_FILES=".patch"

# SELinux context for the directories used for the overlays. This SELinux context is only used when the script can not read the
# SELinux context of an existing directory.
#
#DEFAULT_SELINUX_CONTEXT="u:object_r:shell_data_file:s0"
DEFAULT_SELINUX_CONTEXT="u:object_r:system_file:s0"

# SELinux context for unlabeled files/dirs for virtual disks created on a non-Android OS
#
 UNLABELED_SELINUX_CONTEXT="${UNLABELED_SELINUX_CONTEXT:=*:unlabeled*:*}"
UNLABELED_SELINUX_CONTEXT1="${UNLABELED_SELINUX_CONTEXT1:=*:default*:*}"

# relabel all files in the overlay filesystem with the SELinux context "*:unlabeled:*" or "*:default:*"
#
RELABEL_UNLABELED_FILES=${__FALSE}

# list of environment variables supported by the script
#
ENVIRONMENT_VARIABLES="$( grep ^DEFAULT_ $0 | sed -e "s/DEFAULT_//g" -e "s/=.*//g" )"

ENVIRONMENT_VARIABLES_LIST="$( echo "${ENVIRONMENT_VARIABLES}" | tr "\n" " " )"


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
DEFAULT_DD=$( which dd )
DEFAULT_DIFF=$( which diff )

# the variable DEFAULT_MKFS is a dummy variable defined to make the parameter "vars" happy; 
# the default for MKFS is build with the variable for the filesystem to use (e.g. mkfs.ext4)
#
DEFAULT_MKFS=$( which mkfs )

# default options for diff to compare new and old files
#
DEFAULT_DIFF_OPTIONS=" -u "

# list of Magisk binaries for which a bind mount should be created automatically before creating the overlay mount for the directory with these executables
#
MAGISK_BINARIES=" magisk su resetprop magiskpolicy"

# list of additional files for which a bind mount should be created before creating the overlay mount for the directory with these files
# The value of this variable is only used if the variable FILES_TO_KEEP is empty or if the variable FILES_TO_KEEP contains the string "default".
#
DEFAULT_FILES_TO_KEEP=""

# directory for patch files created by the action "diff_file" with the option "--patch"
#
DEFAULT_PATCH_DIR="/data/local/tmp/patches"

# user response for yes/no questions 
#
DEFAULT_USER_RESPONSE=""

# prefix for log messages
#
LOG_MSG_PREFIX=

# ---------------------------------------------------------------------

# init the variables for the summary messages
#
  OVERLAY_MOUNTS_CREATED=""
  NO_OF_OVERLAY_MOUNTS_CREATED=0

  OVERLAY_MOUNTS_ALREADY_CREATED=""
  NO_OF_OVERLAY_MOUNTS_ALREADY_CREATED=0

  DIRECTORIES_MISSING=""
  NO_OF_DIRECTORIES_MISSING=0

  OVERLAY_MOUNTS_NOT_CREATED=""
  NO_OF_OVERLAY_MOUNTS_NOT_CREATED=0

# ---------------------------------------------------------------------
# aliase

# enable aliase in bash
#
if [ "${BASH_VERSION}"x != ""x ] ; then
  shopt -s expand_aliases
fi

# ---------------------------------------------------------------------
# functions

# ---------------------------------------------------------------------
# LogInfoVar - log the name and the value of a local variable
#
# Usage: LogInfoVar [varname]
#
LogInfoVar() {
  [ ! -n "${VERBOSE}" ] && return
  [ "${VERBOSE}" != 0 ] && return
  _fn="${__FUNCTION:-main}"
  _name="$1"
  eval "_val=\${${_name}-<unset>}"
  printf 'INFO: in %s: %s is %s\n' "$_fn" "$_name" "$_val" >&2
  unset _fn _name _val
}


# ---------------------------------------------------------------------
# LogMsg - write a message to STDOUT with Linefeed
#
# Usage: LogMsg [message]
#
# The functions prints the variable ${LOG_MSG_PREFIX} before the string
#
function LogMsg {
  typeset __FUNCTION="LogMsg"

  typeset THISMSG="$@"

  echo "${LOG_MSG_PREFIX}${THISMSG}"

  return ${__TRUE}
}


# ---------------------------------------------------------------------
# PrintMsg - write a message to STDOUT without Linefeed
#
# Usage: PrintMsg [message]
#
function PrintMsg {
  typeset __FUNCTION="PrintMsg"

  typeset THISMSG="$@"

  printf "${THISMSG}"

  return ${__TRUE}
}

# ---------------------------------------------------------------------
# LogInfo - write a message to STDERR if VERBOSE is ${__TRUE}
#
# Usage: LogInfo [message]
#
# The function  returns ${__TRUE} if the message has been written and
# ${__FALSE} if the message has not been written
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
# AskUser - print a message and read the user input
#
# Usage: AksUser [message_text] [default_value]
#
# returns:
#   ${__TRUE}  - the user answered "yes"
#   ${__FALSE} - the user answered "no"
#   2          - the user answered something different
#
# The global variable USER_INPUT contains the input of the user
#
# If the variable USER_RESPONSE is not empty; the function uses the contents of this variable as user input
# without asking the user.
# If the user input is an empty string; the value from the parameter "default_value" is used
#
function AskUser {
  typeset __FUNCTION="AskUser"

  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__TRUE}
  typeset THISMSG=""
  typeset DEFAULT_RESPONSE=""

#
# clear the global variable
#  
  USER_INPUT=""
  
  if [ $# -ge 1 ] ; then

    THISMSG="$1"
    shift
  
    typeset DEFAULT_RESPONSE="$2"

    if [ "${USER_RESPONSE}"x != ""x ] ; then
      USER_INPUT="${USER_RESPONSE}"
    else
      PrintMsg "${THISMSG} "
      read USER_INPUT
      case "${USER_INPUT}" in
        y | yes | YES | Yes )
          USER_INPUT="yes"
          ;;
  
        no | n )
          USER_INPUT="no"
          ;;

        "" )
          USER_INPUT="${DEFAULT_RESPONSE}"
          ;;

       esac
     fi
  
    case ${USER_INPUT} in
      
      yes )
        THISRC=${__TRUE}
        ;;
      
      no )
        THISRC=${__FALSE}
        ;;
      
      * )
        THISRC=2
        ;;
    esac
  fi

  return ${THISRC}
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
    THISMSG="${THISMSG:=The script ended}"
    LogError "${THISMSG} (RC=${THISRC})"
  fi

  exit ${THISRC}
}

# ---------------------------------------------------------------------
# print_list_of_mounts - print the list of mounts to STDOUT
#
# usage:
#   print_list_of_mounts [force] [quiet]
#
# Parameter:
#
#   force - execute the mount command to retrieve the list of mounts again
#   quiet - do not print the list of mounts to STDOUT
#
# Unknown parameter will be ignored
#
# The function reads the list of mounts once and stores it in a global variable. 
# When called again, the function uses the stored list of mounts.
#
# returns:
#   ${__TRUE} - list of mounted filesystems written to stdout
#   ${__FALSE} - error retrieving the list of mounted filesystems
#
function print_list_of_mounts {
  typeset __FUNCTION="print_list_of_mounts"

  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__TRUE}

  typeset FORCE=${__FALSE}
  typeset QUIET=${__FALSE}

# CUR_MOUNT_LIST is a global variable

  while [ $# -ne 0 ] ; do
    case $1 in
      force | f )
        FORCE=${__TRUE}
        ;;
      quiet | q )
        QUIET=${__TRUE}
        ;;

      * )
        LogError "${__FUNCTION}: Invalid parameter ignored: \"$1°\" "
        ;;
    esac
    shift
  done

  if [ ${FORCE} = ${__TRUE}  -o ${#CUR_MOUNT_LIST} = 0 ] ; then
    LogInfo "Retrieving the list of mounts"
    CUR_MOUNT_LIST="$( ${MOUNT} )" || THISRC=${__FALSE}
  else
    LogInfo "Using the cached list of mounts"

  fi

  [ ${QUIET} != ${__TRUE} ] && echo "${CUR_MOUNT_LIST}"

  return ${THISRC}
}


# ---------------------------------------------------------------------
# mount_device - mount a device and update the list of mounts afterwards
#
# usage:
#   mount_device [parameter_for_mount]
#
# returns:
#   the return code of the mount command
#
function mount_device {
  typeset __FUNCTION="mount_device"

  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__FALSE}

  ${MOUNT} $@
  THISRC=$?

  print_list_of_mounts force quiet

  return ${THISRC}
}


# ---------------------------------------------------------------------
# umount_device - umount a device and update the list of mounts afterwards
#
# usage:
#   umount_device [parameter_for_mount]
#
# returns:
#   the return code of the mount command
#
function umount_device {
  typeset __FUNCTION="mount_devumount_deviceice"

  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__FALSE}

  ${UMOUNT} $@
  THISRC=$?

  print_list_of_mounts force quiet

  return ${THISRC}
}

# ---------------------------------------------------------------------
# mount_real_dir - mount the original directory 
#
# usage:
#   mount_real_dir [dir] [mount_options]
#
# returns:
#   ${__TRUE} - directory is mounted
#   ${__FALSE} - error mounting the directory
#
function mount_real_dir {
  typeset __FUNCTION="mount_real_dir"

  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__TRUE}

  typeset CUR_DIR=""

  typeset CUR_MOUNTPOINT=""
  typeset CUR_DEV=""
  typeset CUR_NEW_MOUNT_POINT=""
  
  typeset ROOT_DEV=""

  typeset DATA_DEV=""
  
  typeset MOUNT_ORIGINAL_FILESYSTEM=${__TRUE}

# global variables used in this function:
#
# ROOTFS_MOUNT_POINT
#
  if [ $# -ne 0 ] ; then
    CUR_DIR="$1"
    shift
    [ $# -ne 0 ] && TMP_MOUNT_OPTIONS="$*"
  else
    LogError "${__FUNCTION}: Parameter missing"
    THISRC=${__FALSE}
  fi

  LogInfo "The mount options are \"${TMP_MOUNT_OPTIONS}\""
  
  if [ ${THISRC} = ${__TRUE} ] ; then
    if [ ! -d "${ROOTFS_MOUNT_POINT}" ] ; then
      LogMsg "Creating the directory \"${ROOTFS_MOUNT_POINT}\" ..."
  
      mkdir -p  "${ROOTFS_MOUNT_POINT}"
      if [ $? -ne 0 ] ; then
        LogError "Error creating the directory \"${ROOTFS_MOUNT_POINT}\"  "
        THISRC=${__FALSE}
      fi
    else
      LogInfo "The directory \"${ROOTFS_MOUNT_POINT}\" already exists"
    fi
  fi
      
# first mount ${BASEDIR}/rootfs to the device used for "/"
#
  if [ ${THISRC} = ${__TRUE} ] ; then
    is_directory_mounted "${ROOTFS_MOUNT_POINT}"
    if [ $? -eq ${__TRUE} ] ; then
      LogInfo "\"${ROOTFS_MOUNT_POINT}\" is already mounted on \"${CUR_DEVICE}\" "
    else
      ROOT_DEV="$( get_mount_device "/" )"
      if [ "${ROOT_DEV}"x != ""x ] ; then
        LogMsg "Mounting \"${ROOTFS_MOUNT_POINT}\" on \"${ROOT_DEV}\" ..."
        mount_device -o ro "${ROOT_DEV}"  "${ROOTFS_MOUNT_POINT}"
        if [ $? -ne 0 ] ; then
          LogWarning "Error mounting \"${ROOTFS_MOUNT_POINT}\" on \"${ROOT_DEV}\" "
        fi
      else
        LogWarning "Can not detect the device used for \"/\" "
      fi
    fi
  fi 



  if [[ ${CUR_DIR} == /data/* && -d "${ROOTFS_MOUNT_POINT}/data"  ]] ; then
#
# an overlay mount for /data/* is requested --mount the device with /data on ${ROOTFS_MOUNT_POINT}/data
#
    DATA_DEV="$( get_mount_device "/data" )"
    ROOTFS_DATA_DEV="$( get_mount_device "${ROOTFS_MOUNT_POINT}/data" )"
    
    LogInfoVar DATA_DEV
    LogInfoVar ROOTFS_DATA_DEV
    if [ "${DATA_DEV}"x = ""x ] ; then
      LogWarning "Can not retrieve the device used for /data"
    elif [ "${DATA_DEV}"x = "${ROOTFS_DATA_DEV}"x ] ; then
      LogInfo "\"${ROOTFS_MOUNT_POINT}\" is already mounted on \"${DATA_DEV}\" "
    else
      LogMsg "Mounting \"${ROOTFS_MOUNT_POINT}/data\"  on \"${DATA_DEV}\" ..."
      mount_device -o rw "${DATA_DEV}" "${ROOTFS_MOUNT_POINT}/data"
      if [ $? -ne 0 ] ; then
        LogWarning "Error mounting \"${ROOTFS_MOUNT_POINT}/data\" on \"${DATA_DEV}\" "
      fi
    fi
  fi

  if [ ${THISRC} = ${__TRUE} ] ; then

    LogInfo "Retrieving the mount point for \"${CUR_DIR}\" ..."
    CUR_MOUNT_POINT="$( stat -c %m "${CUR_DIR}"  )"
    LogInfoVar CUR_MOUNT_POINT
    
    if [ "${TMP_MOUNT_OPTIONS}"x = ""x ] ; then
      LogInfo "Retrieving the mount options for \"${CUR_DIR}\" ..."
      mount | grep " ${CUR_MOUNT_POINT} " | tr "()"  "," | grep ",rw," >/dev/null
      [ $? -eq 0 ] && TMP_MOUNT_OPTIONS="-o rw" ||  TMP_MOUNT_OPTIONS="-o ro"
    else
      LogInfo "Using the mount options defined in the variable TMP_MOUNT_OPTIONS"
    fi
      
    LogInfo "Using the mount options \"${TMP_MOUNT_OPTIONS}\" ..."
    
    if [ "${CUR_MOUNT_POINT}"x = "/"x ] ; then
      LogMsg "\"${CUR_DIR}\" is not on a separate device -- no temporary mount is necessary or this directory"     
      
      THISRC=${__FALSE}
    elif [ "${CUR_MOUNT_POINT}"x != ""x ] ; then
      LogInfo "The mount point for \"${CUR_DIR}\" is: \"${CUR_MOUNT_POINT}\" "

      CUR_DEV="$( df -h "${CUR_MOUNT_POINT}" | tail -1 | cut -f1 -d " " )"
      if [ "${CUR_DEV}"x = ""x ] ; then
        LogError "Can not detect the device for \"${CUR_DIR}\"  "
        THISRC=${__FALSE}
      else
        LogInfo "The device for \"${CUR_DIR}\" is: \"${CUR_DEV}\" "
      fi
    else
      LogError "Can not detect the mount point for \"${CUR_DIR}\"  "
      THISRC=${__FALSE}
    fi
  fi

  if [ ${THISRC} = ${__TRUE} ] ; then

    CUR_NEW_MOUNT_POINT="${ROOTFS_MOUNT_POINT}${CUR_MOUNT_POINT}"

    if [ ! -d "${CUR_NEW_MOUNT_POINT}" ] ; then
      LogInfo "Creating the temporary mount point \"${CUR_NEW_MOUNT_POINT}\" ..."

      mkdir -p "${CUR_NEW_MOUNT_POINT}"
      if [ $? -ne 0 ] ; then
        LogError "Error creating the directory \"${CUR_NEW_MOUNT_POINT}\" "
        THISRC=${__FALSE}
      fi
    else
      LogInfo "The temporary mount point \"${CUR_NEW_MOUNT_POINT}\" already exists"
    fi
  fi

  if [ ${THISRC} = ${__TRUE} ] ; then

    OLD_DEV="$( df -h "${CUR_NEW_MOUNT_POINT}" | tail -1 |  cut -f1 -d " " )"
    if [ "${OLD_DEV}"x = "${CUR_DEV}"x ] ; then
      LogInfo "The directory \"${CUR_NEW_MOUNT_POINT}\" is already mounted on \"${CUR_DEV}\""
    else
      LogMsg "Mounting \"${CUR_NEW_MOUNT_POINT}\" on \"${CUR_DEV}\" ..."
      
      mount_device ${TMP_MOUNT_OPTIONS}  "${CUR_DEV}" "${CUR_NEW_MOUNT_POINT}"
      if [ $? -ne 0 ] ; then
        LogWarning "Error mounting the directory \"${CUR_NEW_MOUNT_POINT}\" on \"${CUR_DEV}\" -- the overlay mount works but actions like \"diff\" will not work for this mountpoint"
        THISRC=${__FALSE}
      fi

    fi
  fi

  return ${THISRC}
}


# ---------------------------------------------------------------------
# umount_real_dir - umount the temporary mount for the filesystem with the original directory
#
# usage:
#   umount_real_dir [dir]
#
# returns:
#   ${__TRUE} - directory is umounted
#   ${__FALSE} - error umounting the directory
#
function umount_real_dir {
  typeset __FUNCTION="umount_real_dir"
  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__TRUE}

  typeset CUR_DIR=""

  typeset TEMPORARY_MOUNTPOINT=""

# global variables used in this function:
#
# ROOTFS_MOUNT_POINT
#

  if [ $# -eq 1 ] ; then
    CUR_DIR="$1"
  else
    LogError "${__FUNCTION}: Parameter missing"
    THISRC=${__FALSE}
  fi

  if [ ${THISRC} = ${__TRUE} ] ; then
    LogInfo "Retrieving the mount point for \"${CUR_DIR}\" ..."

    TEMPORARY_MOUNTPOINT="$( df -h "${ROOTFS_MOUNT_POINT}${CUR_DIR}" | tail -1 | awk '{ print $NF}' )"

    if [ "${TEMPORARY_MOUNTPOINT}"x = "${BASEDIR}"x ] ; then
      LogInfo "There is no temporary mount point for \"${CUR_DIR}\" "

    elif [ "${TEMPORARY_MOUNTPOINT}"x != ""x ] ; then
      LogInfo "The temporary mount point for \"${CUR_DIR}\" is: \"${TEMPORARY_MOUNTPOINT}\" "

      is_directory_mounted "${TEMPORARY_MOUNTPOINT}"
      if [ $? -eq ${__TRUE} ] ; then
        LogInfo "Umounting the temporary mount point \"${TEMPORARY_MOUNTPOINT}\" ..."

        umount_device "${TEMPORARY_MOUNTPOINT}"
        if [ $? -ne 0 ] ; then
          LogError "Error umounting the temporary mount point \"${TEMPORARY_MOUNTPOINT}\" "
          THISRC=${__FALSE}
        fi
      else
        LogInfo "There is no temporary mount point for \"${CUR_DIR}\" mounted "
      fi
    fi
  fi

  return ${THISRC}
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
  LogInfo "*** Function ${__FUNCTION} started"

  [ $# -eq 1 ] && echo "$( echo "$1" | cut -c2- | tr "/" "#" )"
}


# ---------------------------------------------------------------------
# create_dir_name_from_the_overlay_filesystem - create the real dir name 
#
# usage:
#   create_dir_name_from_the_overlay_filesystem [directory]
#
# parameter:
#   directory = fully qualified directory name
#
# returns:
#   the directory name is written to STDOUT
#
function create_dir_name_from_the_overlay_filesystem {
  typeset __FUNCTION="create_dir_name_from_the_overlay_filesystem"
  LogInfo "*** Function ${__FUNCTION} started"

  [ $# -eq 1 ] && echo "$( echo "$1" | cut -c2- | tr "#" "/" )"
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
#   the device name is written to STDOUT if the directory exists
#  
#
function get_mount_device {
  typeset __FUNCTION="get_mount_device"
  LogInfo "*** Function ${__FUNCTION} started"

  [ $# -eq 1 ] && test -d "$1" && df -h "$1" 2>/dev/null | tail -1 | tr "\t" " " |  cut -f1 -d " " 
  
  return 
}

# ---------------------------------------------------------------------
# get_mountpoint- get the mount point for a file or directory on an overlay filesystem
#
# usage:
#   get_mountpoint [directory|file] [subdir]  [quiet]
#
# parameter:
#   directory|file = fully qualified directory or file name in the filesystem used for the overlay
#   subdir can be "merged", "upper", or "lower"
#
# returns:
#   the name of the mountpoint is written to STDOUT
#   the function also sets the global variable GET_MOUNT_POINT_RESULT
#
function get_mount_point {
  typeset __FUNCTION="get_mount_point"
  LogInfo "*** Function ${__FUNCTION} started"

  typeset CUR_FILE="$1"
  typeset CUR_SUBDIR="$2"

  typeset FILENAME=""
  typeset CUR_MOUNT_DIR=""

  CUR_SUBDIR="${CUR_SUBDIR:=merged}"

  FILENAME="${CUR_FILE#${BASEDIR}/${CUR_SUBDIR}/*/}"

  CUR_MOUNT_DIR="$( echo "${CUR_FILE}" | sed "s=/${FILENAME}==g" )"

  [ "$3"x != "quiet"x ] && echo "${CUR_MOUNT_DIR}"

#
# set the global variable
#
  GET_MOUNT_POINT_RESULT="${CUR_MOUNT_DIR}"

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
#   0 - there is an overlay for the directory/file configured and the directory/file has been modified
#   1 - there is an overlay for the directory/file configured and the directory/file has been deleted
#   2 - there is an overlay for the directory/file configured but the directory/file hast not yet been modified or deleted
#   3 - there is no overlay for the directory/file configured
#
# The function stores the directory with the overlay in the global variable GET_FILE_OVERLAY_RESULT
#
# If the global variable EXTERNAL_USE is ${__TRUE} the function prints the filename and details.
#

function get_file_overlay {
  typeset __FUNCTION="get_file_overlay"
  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=3

  typeset TEMPRC=${__FALSE}
  
  typeset UPPERDIR="${BASEDIR}/upper"

  typeset TESTFILE=""
  typeset CUR_MOUNT_POINT=""

  typeset NEW_DIR_NAME=""
  typeset NEW_FILE_NAME=""

  typeset FILE_INFO=""
  typeset FILE_COMMENT=""

  typeset TARGET_FILE="$1"

  typeset CUR_MOUNTS=""

# clear the global variable
#
  GET_FILE_OVERLAY_RESULT=""
  
  if [ $# -eq 1 ] ; then

#
# use the cached mount list if available
#
    CUR_MOUNTS="$( print_list_of_mounts  )"

    if [ ${TEMPRC} != ${__TRUE} ] ; then

      TESTFILE="${UPPERDIR}$1"

      get_mount_point "${TESTFILE}" "upper" "quiet"
#
# the global variable CUR_MOUNT_POINT is set by the function get_mount_point
#
      CUR_MOUNT_POINT="${GET_MOUNT_POINT_RESULT}"

      LogInfoVar TESTFILE
      LogInfoVar CUR_MOUNT_POINT

      if [ "${CUR_MOUNT_POINT}"x != ""x ] ; then

        case "${CUR_MOUNTS}" in
          *"upperdir=${CUR_MOUNT_POINT},"* )
            TEMPRC=${__TRUE}
            ;;
        esac
      fi
    fi

    if [ ${TEMPRC} != ${__TRUE} ] ; then

# the first check was not successfulll

      TESTFILE="${TESTFILE#${UPPERDIR}/*}"

      while true ; do

        LogInfoVar TESTFILE

        NEW_DIR_NAME="${TESTFILE%%/*}"
        NEW_FILE_NAME="${TESTFILE#*/}"

        LogInfoVar NEW_DIR_NAME
        LogInfoVar NEW_FILE_NAME

        [ "${NEW_FILE_NAME}"x = "${NEW_DIR_NAME}"x ] && break

        TESTFILE="${NEW_DIR_NAME}#${NEW_FILE_NAME}"

        LogInfoVar TESTFILE

        get_mount_point "${UPPERDIR}/${TESTFILE}" "upper" quiet
#
# the global variable CUR_MOUNT_POINT is set by the function get_mount_point
#
        CUR_MOUNT_POINT="${GET_MOUNT_POINT_RESULT}"


        LogInfoVar CUR_MOUNT_POINT

        if [ "${CUR_MOUNT_POINT}"x != ""x ] ; then

          case "${CUR_MOUNTS}" in
            *"upperdir=${CUR_MOUNT_POINT},"* )
            TESTFILE="${UPPERDIR}/${TESTFILE}"

            LogInfoVar TESTFILE

            TEMPRC=${__TRUE}
            break
            ;;
          esac

        fi

      done
    fi

    if [ ${TEMPRC} = ${__TRUE} ] ; then

      FILE_INFO=""
      FILE_COMMENT="# ${TARGET_FILE}"

      if [ -r "${TESTFILE}" ] ; then

        if [ -c "${TESTFILE}" ] ;then
          if [ "$( stat -c %t%T  "${TESTFILE}" )"x = "00"x  ] ; then
            FILE_COMMENT="${FILE_COMMENT} # the file/directory has been deleted"
            THISRC=1
          fi
        elif [ -d "${TESTFILE}"  ] ; then
#          if [  -d "${TARGET_FILE}" ] ; then
#            FILE_COMMENT="${FILE_COMMENT} # the directory has been created"
#          fi
          THISRC=0
        else
          FILE_COMMENT="${FILE_COMMENT} # the file has been modified"
          THISRC=0
        fi

        if [ ${PRINT_MORE_DETAILS} = ${__TRUE} ] ; then
           FILE_INFO="$(  stat -c '%A %h %U %G %C %s %y %n' "${TESTFILE}" 2>&1 )"
        else
           FILE_INFO="$(  stat -c '%A %h %U %G %s %y %n' "${TESTFILE}" 2>&1 )"
        fi
      else
        THISRC=2
        FILE_INFO="${TESTFILE}"
        FILE_COMMENT="${FILE_COMMENT} # the file has not yet been modified or deleted"
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

# store the result in the global variable
#
  GET_FILE_OVERLAY_RESULT="${TESTFILE}"

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
  LogInfo "*** Function ${__FUNCTION} started"

  THISRC=1

  typeset CUR_DIR="$1"

# init the global variables
#
  CUR_BACKEND_DIR=""
  CUR_BACKEND_DISK=""

  if [ $# -eq 1 ]; then

    df -h "${CUR_DIR}" | tail -1 | grep "^overlay" >/dev/null
    if [ $? -eq 0 ] ; then

      CUR_BACKEND_DIR="$( print_list_of_mounts | grep " ${CUR_DIR} " | grep "^overlay" | tail -1 | sed -e "s#.*upperdir=##g" -e "s#/upper.*##g" )"
      if [ "${CUR_BACKEND_DIR}"x = ""x ] ; then
        THISRC=2
      else

        CUR_BACKEND_DISK="$( ${LOSETUP} -a | grep $( df -h  "${CUR_BACKEND_DIR}" 2>/dev/null| tail -1 | cut -f1 -d " " ) |  sed -e "s#.*(##g" -e "s#).*##g" )"
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
  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__FALSE}

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
    elif [ ! -r "${CUR_DIR}" ] ; then
      THISRC=${__FALSE}
      CUR_DEVICE=""
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
  LogInfo "*** Function ${__FUNCTION} started"

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
          LogInfo "Permissions and owner of the directory \"${TARGET_DIR}\" successfully modified: " && \
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
  LogInfo "*** Function ${__FUNCTION} started"

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


    if [[ "${CUR_SELINUX_CONTEXT}" == ${UNLABELED_SELINUX_CONTEXT} || "${CUR_SELINUX_CONTEXT}" == ${UNLABELED_SELINUX_CONTEXT1} ]] ; then

      LogWarning "The SELinux context to use for \"${TARGET_DIR}\" is \"${CUR_SELINUX_CONTEXT}\" "

      LogWarning "That does not work -- using the default SELinux context \"${SELINUX_CONTEXT}\" now "

      CUR_SELINUX_CONTEXT="${SELINUX_CONTEXT}"
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
# set_selinux_context_for_files - copy the SELinux context from a directory to all
# files in the directory with the SELinux context "*:unlabeled*" or "*:default:*"
#
# usage:
#   set_selinux_context_for_files [overlay_directory] [target_directory]
#
#
# returns:
#   ${__TRUE} - ok
#   ${__FALSE} - error
#
function set_selinux_context_for_files {
  typeset __FUNCTION="set_selinux_context_for_files"
  LogInfo "*** Function ${__FUNCTION} started"

  typeset OVERLAY_DIR="$1"

  typeset TARGET_DIR="$2"

  typeset NEW_SELINUX_CONTEXT=""

  typeset THISRC=${__TRUE}


  LogInfo "*** The function ${__FUNCTION} started"

  LogInfo "The overlay directory is \"${OVERLAY_DIR}\" "
  LogInfo "The target directory is  \"${TARGET_DIR}\" "

  if [ "${OVERLAY_DIR}"x = ""x -o "${TARGET_DIR}"x = ""x  ] ; then
    LogError "${__FUNCTION} called with missing parameter, the parameter for the function are: \"$*\" "
    THISRC=${__FALSE}
  elif [ ! -d "${OVERLAY_DIR}" ] ; then
    LogWarning "The overlay directory \"${OVERLAY_DIR}\" does not exist"
  elif [ ! -d "${TARGET_DIR}" ] ; then
    LogWarning "The target directory \"${TARGET_DIR}\" does not exist"
  else

    NEW_SELINUX_CONTEXT="$( stat -c %C "${TARGET_DIR}" )"

    LogInfo "The SELinux context of the target directory \"${TARGET_DIR}\" is \"${NEW_SELINUX_CONTEXT}\" "

    if [[ "${NEW_SELINUX_CONTEXT}" == ${UNLABELED_SELINUX_CONTEXT} || "${NEW_SELINUX_CONTEXT}" == ${UNLABELED_SELINUX_CONTEXT1}  ]] ; then
      LogWarning "Something might be wrong here: The SELinux Context for \"${TARGET_DIR}\" is \"${NEW_SELINUX_CONTEXT}\" "
    fi

    LogMsg "Now correcting the SELinux context for all files and directories with the SELinux context \"${UNLABELED_SELINUX_CONTEXT}\" or \"${UNLABELED_SELINUX_CONTEXT1}\" in the directory \"${OVERLAY_DIR}\" to \"${NEW_SELINUX_CONTEXT}\" ..."
    LogMsg  "This may take some minutes - please be patient "

    [[ ${VERBOSE} = ${__TRUE} ]] && set -x

    find "${OVERLAY_DIR}"  -type l \( -context "${UNLABELED_SELINUX_CONTEXT}" -o -context "${UNLABELED_SELINUX_CONTEXT1}" \) -print0 2>/dev/null | xargs -0 -r chcon -h "${NEW_SELINUX_CONTEXT}" || \
      THISRC=${__FALSE}

    find "${OVERLAY_DIR}"          \( -context "${UNLABELED_SELINUX_CONTEXT}" -o -context "${UNLABELED_SELINUX_CONTEXT1}" \) -print0 | xargs -0 -r chcon -h "${NEW_SELINUX_CONTEXT}" || \
      THISRC=${__FALSE}

    [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x

    if [ ${THISRC} -eq ${__TRUE} ] ; then
      LogMsg "... SELinux context for the files successfully modified"
      THISRC=${__TRUE}
    else
      if [ "$( getenforce )"x = "Enforcing"x ] ;then
        die 95 "Error correcting the SELinux contexts in the directory \"${OVERLAY_DIR}\""
      else
        LogError "Error correcting the SELinux contexts. SELinux is currently disabled. Please check the SELinux context for the files in the directory  \"${OVERLAY_DIR}\""
       fi
    fi
  fi

  LogInfoVar OVERLAY_DIR
  LogInfoVar TARGET_DIR
  LogInfoVar UNLABELED_SELINUX_CONTEXT
  LogInfoVar UNLABELED_SELINUX_CONTEXT1
  LogInfoVar NEW_SELINUX_CONTEXT

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
  LogInfo "*** Function ${__FUNCTION} started"

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
  LogInfo "*** Function ${__FUNCTION} started"

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
          LogError "Error creating a filesystem on the image file \"${CUR_IMAGE_FILE}\" "
          THISRC=1
        fi
      else
        LogError "The image file \"${CUR_IMAGE_FILE}\" does not exist"
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
  LogInfo "*** Function ${__FUNCTION} started"

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


# create a sparse file:
#
# dd if=/dev/zero of=/data/local/tmp/sparse.img bs=1 count=0 seek=1G
#
# or
#
# truncate -s 1G /data/local/tmp/sparse.img
#
      if [ ${CREATE_SPARSE_FILE} = ${__TRUE} ] ;then
        LogInfo "Creating a sparse file ..."

        [[ ${VERBOSE} = ${__TRUE} ]] && set -x

        "${DD}" if=/dev/zero of="${CUR_IMAGE_FILE}" bs=1 count=0 seek=${FILESYSTEM_SIZE}
        TEMPRC=$?
      else

        [[ ${VERBOSE} = ${__TRUE} ]] && set -x

        "${DD}" if=/dev/zero of="${CUR_IMAGE_FILE}" bs=${FILESYSTEM_SIZE} count=1
        TEMPRC=$?
      fi

      [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x

      LogMsg "Result:"  && LogMsg "$( ls -l "${CUR_IMAGE_FILE}"  )"

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
  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__TRUE}

  typeset IMAGE_FILE_CREATED=${__FALSE}

  typeset TEMPRC=0

  typeset EXISTING_LOOP_DEVICE=""
  typeset EXISTING_MOUNT_POINT=""

  typeset MOUNT_LOOP_DEVICE=${__TRUE}
  typeset CREATE_LOOP_DEVICE=${__TRUE}

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
# create an filesystem on the virtual disk if necessary
#
  if  [ ${IMAGE_FILE_CREATED} = ${__TRUE} -o ${INIT_DISK} = ${__TRUE} ] ; then
    LogMsg ""
    LogMsg "Creating a \"${FILESYSTEM_TO_USE}\" filesystem on the image file \"${IMAGE_FILE}\" now ..."

    format_virtual_disk "${IMAGE_FILE}" || \
      die 25 "Error creating a filesystem on the image file \"${IMAGE_FILE}\" "
  else
    LogMsg "The image file \"${IMAGE_FILE}\" already exists - there should already be a filesystem on the disk"
  fi
#
# create the mount point for mounting the loop device; copy the SELinux context from the directory /system
#
  create_directory "${BASEDIR}:755" && set_selinux_context "/system" "${BASEDIR}" || \
    die 30 "Error creating the directory \"${BASEDIR}\""
#
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
    LogMsg "Mounting the image file \"${IMAGE_FILE}\" to \"${BASEDIR}\" ..."

    [[ ${VERBOSE} = ${__TRUE} ]] && set -x

# check if there is already a loop device for the file with the virtual disk
#
    EXISTING_LOOP_DEVICE="$( ${LOSETUP} -a | grep  "(${IMAGE_FILE})" | head -1  | cut -f1 -d ":" )"

    if [ "${EXISTING_LOOP_DEVICE}"x != ""x ] ; then
      CREATE_LOOP_DEVICE=${__FALSE}
      NEW_LOOP_DEVICE="${EXISTING_LOOP_DEVICE}"

      LogInfo "The existing loop device for the file \"${IMAGE_FILE}\" is \"${EXISTING_LOOP_DEVICE}\""

# check if the loop device is already mounted
#
      EXISTING_MOUNT_POINT="$( mount | grep "${EXISTING_LOOP_DEVICE}" | cut -f3 -d " " )"
      if [ "${EXISTING_MOUNT_POINT}"x != ""x ] ; then
        if [ "${EXISTING_MOUNT_POINT}"x != "${BASEDIR}"x ] ; then
          die 36 "The image file \"${IMAGE_FILE}\" is already mounted on \"${EXISTING_MOUNT_POINT}\" "
        else
#
# this code should never run but you never know ....
#
          LogInfo "The image file \"${IMAGE_FILE}\" is already mounted on \"${EXISTING_MOUNT_POINT}\" "
          MOUNT_LOOP_DEVICE=${__FALSE}
        fi
      else
        LogInfo "The loop device for the file \"${IMAGE_FILE}\" (\"${EXISTING_LOOP_DEVICE}\") is not yet mounted"
      fi
    fi

    if [ ${CREATE_LOOP_DEVICE} = ${__TRUE} ] ; then
#
# create a new loop device if necessary
# (losetup sometimes writes useless error messages ....)
#
      NEW_LOOP_DEVICE="$( ${LOSETUP} -f  2>/dev/null )"
      LogInfoVar NEW_LOOP_DEVICE
    fi

    if [ ${MOUNT_LOOP_DEVICE} = ${__TRUE} ] ; then
#
# mount the loop device
#
      mount_device -o rw -t "${FILESYSTEM_TO_USE}" ${MOUNT_OPTIONS} "${IMAGE_FILE}" "${BASEDIR}"
      TEMPRC=$?

    fi

    [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x

    [ ${TEMPRC} != 0 ]  && die 40 "Error mounting the image file \"${IMAGE_FILE}\" to \"${BASEDIR}\" "

    LOOP_DEVICE="$( get_mount_device "${BASEDIR}" )"

# correct the SELinux context for the base directory
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
  LogInfo "*** Function ${__FUNCTION} started"

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
  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__TRUE}

  typeset CUR_DIR=""
  typeset CUR_TEST_FILE=""

  typeset DIRS_TO_TEST=""

  typeset OVERBOSE=${VERBOSE}
  
  create_list_of_mounted_overlays

  [ ${PRINT_MORE_DETAILS} = ${__TRUE} ] && VERBOSE=${__TRUE}

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

  VERBOSE=${OVERBOSE}

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
  LogInfo "*** Function ${__FUNCTION} started"

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
# list_virtual_disk_contents - list the contents of a virtual disk
#
# usage:
#   list_virtual_disk_contents
#
# returns:
#   ${__TRUE}  - directories on the virutal disk listed
#   ${__FALSE} - no mounted disk found
#
function list_virtual_disk_contents {
  typeset __FUNCTION="list_virtual_disk_contents"
  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__TRUE}

  typeset CUR_DIR=""
  typeset REAL_DIR=""
  typeset DIR_LIST=""
  typeset NO_OF_MODIFIED_FILES=0
  typeset NO_OF_DELETED_FILES
  typeset DISK_MSG=""
  typeset CUR_DISK_IMAGE=""
  
#
# mount the loop device
#
  is_directory_mounted "${BASEDIR}"
  if [ $? -eq 3 ] ; then
    LogMsg "The directory \"${BASEDIR}\" is not mounted to a virtual disk"
    THISRC=${__FALSE}
  elif [[ ${CUR_DEVICE} != /dev/block/loop* ]] ; then
    LogWarning "The directory \"${BASEDIR}\"  is mounted on an unknwon device \"${CUR_DEVICE}\" "
  else
    CUR_DISK_IMAGE="$( losetup -a  2>/dev/null | grep "${CUR_DEVICE}" | tr "()" "##"  | cut -f2 -d"#" )"
    [ "${DISK_MSG}" != ""x ] && DISK_MSG=" (mounted on the virtual disk \"${CUR_DISK_IMAGE}\")"
  fi

  if [ ! -d  "${BASEDIR}/upper" ] ; then
    LogError "\"${BASEDIR}\" is not mounted to a disk configured for disks with overlay filesystems"
    THISRC=${__FALSE}
  fi
    
  if [ ${THISRC} = ${__TRUE} ] ; then
    DIR_LIST="$( cd  "${BASEDIR}/upper" && ls -1 )"

    if [ "${DIR_LIST}"x = ""x ] ; then
      LogMsg "No overlay directories found on the virtual disk mounted at \"${BASEDIR}\":"
    else
      LogMsg "Overlay directories in \"${BASEDIR}\"${DISK_MSG}:"
      LogMsg ""

      DIR_FIELD_LENGTH=20

      for CUR_DIR in ${DIR_LIST} ; do
        [ ${#CUR_DIR} -gt ${DIR_FIELD_LENGTH} ] && DIR_FIELD_LENGTH=${#CUR_DIR}
      done
      
      (( DIR_FIELD_LENGTH= DIR_FIELD_LENGTH +4 ))

      PRINTF_FORMAT_STRING="%-${DIR_FIELD_LENGTH}s %-25s   %-25s  %-30s  %s\n"
      
      if [ ${PRINT_MORE_DETAILS} = ${__TRUE} ] ; then
        printf "${PRINTF_FORMAT_STRING}" "Target Directory" "No. of modified files" "No. of deleted files" "Directory currently mounted?" "Overlay Directory"
        printf "${PRINTF_FORMAT_STRING}" "----------------" "---------------------" "--------------------" "----------------------------" "-----------------"
      fi
        
      for CUR_DIR in ${DIR_LIST} ; do
        REAL_DIR="/${CUR_DIR//#//}"
        if [ ${PRINT_MORE_DETAILS} != ${__TRUE} ] ; then
          LogMsg "${REAL_DIR}"
        else

          NO_OF_MODIFIED_FILES="$( find "${BASEDIR}/upper/${CUR_DIR}" -type f | wc -l )"
          NO_OF_DELETED_FILES="$( find "${BASEDIR}/upper/${CUR_DIR}" -type c | wc -l )"
          DIR_MOUNTED="no"
          if get_file_overlay "${REAL_DIR}" 1>/dev/null  ; then
            if [[ ${GET_FILE_OVERLAY_RESULT} == ${BASEDIR}/* ]] ; then
              DIR_MOUNTED="yes" 
            fi
          fi
          printf "${PRINTF_FORMAT_STRING}" "${REAL_DIR}" "${NO_OF_MODIFIED_FILES}" "${NO_OF_DELETED_FILES}" "${DIR_MOUNTED}" "${BASEDIR}/upper/${CUR_DIR}"
        fi
      done    
      LogMsg ""  
    fi 
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
  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__TRUE}

  typeset CUR_DIR=""

  typeset OVERLAY_UPPER_DIR=""

  if [ "${DIRS_TO_OVERLAY}"x = ""x ] ; then
    LogMsg "No directories with overlays found"
    THISRC=${__TRUE}
  else
    LogMsg "List the modifications in the directories ..."

    create_list_of_mounted_overlays

    for CUR_DIR in ${DIRS_TO_OVERLAY} ; do
      LogMsg ""
      LogMsg " ---------------------------------------------------------------------- "
      OVERLAY_UPPER_DIR="${BASEDIR}/upper/$( create_dir_name_for_the_overlay_filesystem "${CUR_DIR}" )"
      if [ -d "${OVERLAY_UPPER_DIR}" ] ; then
        LogMsg "List the modifications in the directory \"${CUR_DIR}\" ..."

        echo "${CUR_OVERLAY_FILESYSTEMS}" | grep "^${CUR_DIR}$" >/dev/null
        if [ $? -eq 0 ] ; then
          LogMsg "There is currently an overlay mounted for the directory \"${CUR_DIR}\""
        else
          LogMsg "There is currently no overlay mounted for the directory \"${CUR_DIR}\""
        fi

        cd  "${OVERLAY_UPPER_DIR}"
        if [ $? -ne 0 ] ; then
          LogError "Can not change the working directory to the directory \"${OVERLAY_UPPER_DIR}\" "
          THISRC=${__FALSE}
        else

          if [ ${PRINT_MORE_DETAILS} = ${__TRUE} ] ; then
            CUR_OUTPUT="$( find . ! -type c -a ! -type d -exec ls -ldZ {} + | grep -v " .$" )"
          else
            CUR_OUTPUT="$( find . ! -type c -a ! -type d -exec ls  -1d {} +  | grep -v "^.$" )"
          fi

          [ "${CUR_OUTPUT}"x = ""x ] && NO_OF_FILES_FOUND=0 || \
            NO_OF_FILES_FOUND=$( echo "${CUR_OUTPUT}" | wc -l )

          LogMsg ""
          [ ${NO_OF_FILES_FOUND} = 1 ] && \
            LogMsg "There is ${NO_OF_FILES_FOUND} modified file in the directory tree \"${CUR_DIR}\" "  || \
            LogMsg "There are ${NO_OF_FILES_FOUND} modified files in the directory tree \"${CUR_DIR}\" "
          
          if [ ${SHORT_INFOS} != ${__TRUE} -a  ${NO_OF_FILES_FOUND} -ge 1 ] ; then
            LogMsg "File modifications in the directory \"${CUR_DIR}\" :"
            LogMsg
            LogMsg "${CUR_OUTPUT}"
          fi
          
          LogMsg

          CUR_OUTPUT="$( find .  -type c -exec ls -1d {} + )"

          [ "${CUR_OUTPUT}"x = ""x ] && NO_OF_FILES_FOUND=0 || \
            NO_OF_FILES_FOUND=$( echo "${CUR_OUTPUT}" | wc -l )

          [ ${NO_OF_FILES_FOUND}  = 1 ] && \
            LogMsg "There is ${NO_OF_FILES_FOUND} deleted file in the directory tree \"${CUR_DIR}\"" || \
            LogMsg "There are ${NO_OF_FILES_FOUND} deleted files in the directory tree \"${CUR_DIR}\""
          
          if [ ${SHORT_INFOS} != ${__TRUE}  -a  ${NO_OF_FILES_FOUND} -ge 1 ] ; then
            LogMsg "Files or directories deleted in the directory \"${CUR_DIR}\" :"
            LogMsg
            LogMsg "${CUR_OUTPUT}"
          fi

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
  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__TRUE}

  typeset CUR_DIR=""

  typeset OVERLAY_UPPER_DIR=""

  if [ "${DIRS_TO_OVERLAY}"x = ""x ] ; then
    LogMsg "No directories for undo found"
    THISRC=${__FALSE}
  else
    LogMsg "Undoing the modifications in the directories"
    LogMsg "$( echo "${DIRS_TO_OVERLAY}" | tr " " "\n" )"
    LogMsg ""    
    if [ ${DIRECTORY_FOUND_IN_THE_PARAMETER} != ${__TRUE} ] ; then
      AskUser "Please confirm that all modifications in the overlay filesystems for the directories listed above should be deleted (use the parameter \"--yes\" to suppress this question) (y/N)? " "no"
      THISRC=$?
    fi
  fi

  if [ ${THISRC} = ${__TRUE} ] ; then
    LogMg ""
    for CUR_DIR in ${DIRS_TO_OVERLAY} ; do
      OVERLAY_UPPER_DIR="${BASEDIR}/upper/$( create_dir_name_for_the_overlay_filesystem "${CUR_DIR}" )"
      if [ -d "${OVERLAY_UPPER_DIR}" ] ; then
        LogMsg "Undoing the modicications for the directory \"${CUR_DIR}\" ..."
        \rm -rf "${OVERLAY_UPPER_DIR}"/*
        if [ $? -ne 0 ] ; then
          LogError "The undo for the directory \"${CUR_DIR}\" failed"
          THISRC=${__FALSE}
        fi
      else
        LogWarning "No overlay for the directory \"${CUR_DIR}\" found."
      fi
    done
  else
    LogMsg "undo canceled by the user"    
    THISRC=${__FALSE}
  fi

  return ${THISRC}
}

# ---------------------------------------------------------------------
# umount_overlay_mounts - umount the overlay mounts
#
# usage:
#   umount_overlay_mounts [all]
#
# Parameter:
#   all - umount all existing overlay mounts
#
# returns:
#   ${__TRUE}  - overlay mounts umounted
#   ${__FALSE} - umounting of one or more mounts failed
#
function umount_overlay_mounts {
  typeset __FUNCTION="umount_overlay_mounts"

  typeset THISRC=${__TRUE}

  typeset UMOUNT_ALL_OVERLAY_MOUNTS=${__FALSE}
  
  typeset CUR_DIR=""
  typeset CUR_OVERLAY_DIR_NAME=""
  typeset OVERLAY_MERGED_DIR=""

  typeset CUR_TMP_DIR=""
  
  typeset DIRECTORYS_TO_PROCESS=""

  typeset DIRECTORY_LIST=""
  typeset DIRECTORY_LIST2=""

  typeset TEMPRC=0

  typeset SUB_MOUNT_POINTS=""
  typeset CUR_SUB_MOUNT=""
  typeset CUR_SUB_MOUNT_DEVICE=""
 
  typeset CUR_OVERLAY_DIR_NAME=""

  typeset NO_OF_OTHER_MOUNTS=0
  
  [ "$1"x = "all"x ]  && UMOUNT_ALL_OVERLAY_MOUNTS=${__TRUE}

  create_list_of_mounted_overlays

# the function create_list_of_mounted_overlays sets the global variables
#   ALL_OVERLAY_MOUNTS

  LogInfoVar ALL_OVERLAY_MOUNTS

  if [ $[UMOUNT_ALL_OVERLAY_MOUNTS} = ${__TRUE} ] ; then
    DIRECTORYS_TO_PROCESS="${CUR_OVERLAY_FILESYSTEMS}"
  elif [ ${DIRECTORY_FOUND_IN_THE_PARAMETER} = ${__TRUE} ] ; then 
    DIRECTORYS_TO_PROCESS="${DIRS_TO_OVERLAY}"
  else
    DIRECTORYS_TO_PROCESS="${CUR_OVERLAY_FILESYSTEMS}"
  fi

  LogInfoVar DIRECTORYS_TO_PROCESS

  if [ "${DIRECTORYS_TO_PROCESS}"x = ""x ] ; then
    LogMsg "No directories to umount found"
    THISRC=${__TRUE}
  else

    if [ ${UMOUNT_ALL_OVERLAY_MOUNTS} = ${__TRUE} ] ; then
      DIRECTORY_LIST="${DIRECTORY_LIST} ${DIRECTORYS_TO_PROCESS}"
    else
      for CUR_DIR in ${DIRECTORYS_TO_PROCESS} ; do
        CUR_OVERLAY_DIR_NAME="/$( create_dir_name_for_the_overlay_filesystem "${CUR_DIR}" )"
        
        echo "${ALL_OVERLAY_MOUNTS}" | grep "^${BASEDIR}/merged${CUR_OVERLAY_DIR_NAME}$" >/dev/null
        if [ $? -eq 0 ] ;then
          DIRECTORY_LIST="${DIRECTORY_LIST} ${CUR_OVERLAY_DIR_NAME}"
        else
          THISRC=${__FALSE}    
            
          LogWarning "\"${CUR_DIR}\" is not mounted on an overlay filesystem for the basedir \"${BASEDIR}\""
          if [ ${PRINT_MORE_DETAILS} = ${__TRUE} ] ; then
            if [ ! -d "${CUR_DIR}" ] ; then
              LogMsg "         The directory \"${CUR_DIR}\" does not exist"      
            else
              retrieve_overlay_filesystem_backend "${CUR_DIR}"
              if [ "${CUR_BACKEND_DIR}"x != ""x ]  ;then
                LogMsg "         The backend for \"${CUR_DIR}\" is \"${CUR_BACKEND_DIR}\" "          
              else
                LogMsg "         There is no overlay filesystem configured for \"${CUR_DIR}\" "          
              fi
            fi
          fi
        fi
      done
    fi

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

# do not do this for the rootfs directory!
#
      if [ "${CUR_DIR}"x = "${BASEDIR}/rootfs"x ] ; then
        LogMsg "### Ignoring the sub mounts for \"${CUR_DIR}\" .."
        continue
      fi
      
      SUB_MOUNT_POINTS="$( mount | grep " ${CUR_DIR}/" | grep "^/dev/block/sd" | tr "\t" " " | tr -s " " | cut -f3 -d  " " | sort | uniq )"

      LogInfoVar SUB_MOUNT_POINTS

      if [ "${SUB_MOUNT_POINTS}"x != ""x ] ; then
        LogMsg "Umounting the mounted sub directories ..."

        for CUR_SUB_MOUNT in ${SUB_MOUNT_POINTS} ; do
          LogMsg "Umounting \"${CUR_SUB_MOUNT}\" ..."
#
# do nothing if the mount point is not mounted on a device
#
          CUR_SUB_MOUNT_DEVICE="$( df -h "${CUR_SUB_MOUNT}" | tail -1 | cut -f1 -d " " )"
          LogInfoVar CUR_SUB_MOUNT_DEVICE
          if [ "${CUR_SUB_MOUNT_DEVICE}"x = "overlay"x ] ; then
            LogInfo "\"${CUR_SUB_MOUNT}\" is mounted on \"${CUR_SUB_MOUNT_DEVICE}\"  -- will not umount it" 
            continue
          fi
          
          [[ ${VERBOSE} = ${__TRUE} ]] && set -x       
          ${UMOUNT} ${CUR_SUB_MOUNT}
          TEMPRC=$?
          [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x 

          if [ ${TEMPRC} != 0 ] ;then
            LogError "Error umounting \"${CUR_SUB_MOUNT}\" "
          fi
        done
      fi
      
      LogMsg "Umounting the bind mount \"${CUR_DIR}\" ..."

      [[ ${VERBOSE} = ${__TRUE} ]] && set -x 
      ${UMOUNT} /$( create_dir_name_from_the_overlay_filesystem  "${CUR_DIR}" )
      TEMPRC=$?
      [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x 

      if [ ${TEMPRC} -eq 0 ] ; then

        CUR_OVERLAY_DIR_NAME="$( create_dir_name_for_the_overlay_filesystem "${CUR_DIR}" )"

        if [ ${UMOUNT_ALL_OVERLAY_MOUNTS} = ${__TRUE} ] ; then
          OVERLAY_MERGED_DIR="$( echo "${ALL_OVERLAY_MOUNTS}" | grep "/merged/${CUR_OVERLAY_DIR_NAME}$" | cut -f3 -d " " | uniq )"
        else
          OVERLAY_MERGED_DIR="$( echo "${ALL_OVERLAY_MOUNTS}" | grep "${BASEDIR}/merged/${CUR_OVERLAY_DIR_NAME}$" | cut -f3 -d " " | uniq )"
        fi        

        DIRECTORY_LIST2="${DIRECTORY_LIST2} ${OVERLAY_MERGED_DIR}" 

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


  if [ "${DIRECTORY_LIST}"x != ""x ] ; then
    LogMsg ""

    LogMsg "Umounting the temporary mounts for the original directories ..."
    for CUR_DIR in ${DIRECTORY_LIST} ; do

      LogInfo "1: CUR_DIR is \"${CUR_DIR}\" "
         
      CUR_TMP_DIR="/$( create_dir_name_from_the_overlay_filesystem "${ROOTFS_MOUNT_POINT}${CUR_DIR}" )"
      LogInfo "2:  CUR_TMP_DIR is \"${CUR_TMP_DIR}\" "

      if [ -d "${CUR_TMP_DIR}" ] ; then
        CUR_TMP_DIR="$( df -h  "${CUR_TMP_DIR}" | tail -1 | awk '{ print $NF}'  )"
        LogInfo "3:  CUR_TMP_DIR is \"${CUR_TMP_DIR}\" "

# if the mount point used for the original directory is ${BASEDIR}/rootfs check for sub mounts and 
# try not to remount it if there are any
#
# ROOTFS_MOUNT_POINT is a global variabel
#
        if [ "${CUR_TMP_DIR}"x = "${ROOTFS_MOUNT_POINT}"x ]  ; then 
          CUR_OUTPUT="$( df -h | grep "${ROOTFS_MOUNT_POINT}/" 2>&1 )"
          if [ $? -eq 0 ] ; then
            LogInfo "There are still mounts in the rootfs directory - will not umount \"${CUR_TMP_DIR}\" " && \
              LogMsg "${CUR_OUTPUT}"
            continue
          fi
        fi

        if is_directory_mounted "${CUR_TMP_DIR}" ; then

          LogInfo "4:  CUR_DIR is \"${CUR_DIR}\" "
  
          if [[ ${CUR_DIR} == *\#* ]] ; then

            LogInfo "4:  CUR_TMP_DIR is \"${CUR_TMP_DIR}\" "

            NO_OF_OTHER_MOUNTS=$( print_list_of_mounts |  cut -f3 -d " " | grep "${CUR_TMP_DIR%%#*}/" | wc -l )

            if [ ${NO_OF_OTHER_MOUNTS} -ge 1  ] ; then
              LogInfo "The temporary mount \"${CUR_TMP_DIR}\" is used by $(( NO_OF_OTHER_MOUNTS - 1 )) other overlay mounts -- will not umount it "     
              continue
            fi
          fi         

          LogMsg "Umounting \"${CUR_TMP_DIR}\" ..."
          ${UMOUNT} "${CUR_TMP_DIR}"
        fi
      fi
    done

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
  LogInfo "*** Function ${__FUNCTION} started"

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

      OVERLAY_MERGED_DIR="$( print_list_of_mounts | grep "^overlay" | grep  " ${CUR_DIR} " | sed -e "s/.*upperdir=//g" -e "s/,workdir=.*//g" | sed "s#/upper/#/merged/#"  )"

#      OVERLAY_MERGED_DIR="${BASEDIR}/merged/$( create_dir_name_for_the_overlay_filesystem "${CUR_DIR}" )"

      LogInfo "\"${CUR_DIR}\" is mounted on \"${OVERLAY_MERGED_DIR}\" "

      [[ ${VERBOSE} = ${__TRUE} ]] && set -x
      mount_device -o remount "${OVERLAY_MERGED_DIR}"
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
# delete_overlay_filesystem - delete the directories on the virtual disk used for the overlay mounts
#
# usage:
#   delete_overlay_filesystem [directory]
#
# returns:
#   ${__TRUE}  - overlay mounts deleted
#   ${__FALSE} - deleting of one or more mounts failed
#   3 - the delete was aburted by the user
#
function delete_overlay_filesystem {
  typeset __FUNCTION="delete_overlay_filesystem"
  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__TRUE}

  typeset CUR_DIR=""
  typeset OVERLAY_DIR=""
  
  typeset DIRECTORYS_TO_PROCESS=""
  typeset DIRS_TO_DELETE=""

  typeset DIRECTORY_LIST=""

  typeset TEMPRC=0
  
# the function create_list_of_mounted_overlays sets the global variables
#   CUR_OVERLAY_FILESYSTEMS
#   ALL_OVERLAY_MOUNTS

  create_list_of_mounted_overlays

  if [ ${DIRECTORY_FOUND_IN_THE_PARAMETER} = ${__TRUE} ] ; then
    DIRECTORYS_TO_PROCESS="${DIRS_TO_OVERLAY}"
  else
    LogMsg "No directories to delete found in the script parameter"
    THISRC=${__TRUE}
  fi

  if [ "${DIRECTORYS_TO_PROCESS}"x != ""x ] ; then
    LogMsg "Now deleting the overlay filesystems for these directories:"
    
    LogMsg "$( echo "${DIRECTORYS_TO_PROCESS}" | tr " " "\n" )"
    LogMsg "" 

    AskUser "Please confirm that the overlay filesystems for the directories listed above should be deleted (use the parameter \"--yes\" to suppress this question) (y/N)? " "no"
    if [ $? -ne ${__TRUE} ] ; then
      LogMsg "Delete process aborted by the user"
      THISRC=3
    else
    
      for CUR_DIR in ${DIRECTORYS_TO_PROCESS} ; do
        OVERLAY_DIR="$( create_dir_name_for_the_overlay_filesystem "${CUR_DIR}" )"
        
        LogInfoVar OVERLAY_DIR
        
        if [ ! -d "${BASEDIR}/merged/${OVERLAY_DIR}" ] ; then
          echo "WARNING: There is no overlay directory configured for the directory \"${CUR_DIR}\" on the virtual disk mounted on \"${BASEDIR}\" "
          continue
        fi

        echo "${CUR_OVERLAY_FILESYSTEMS}" | grep "^${BASEDIR}/merged/${CUR_DIR}$" >/dev/null
        if [ $? -eq 0 ] ;then
          LogError "There is currently an overlay filesystem mounted for the directory \"${CUR_DIR}\" - please umount the filesystem before deleting it"
          THISRC=${__FALSE}
          continue
        fi

        DIRECTORY_LIST="${DIRECTORY_LIST} ${OVERLAY_DIR}"
      done
          
      if [ "${DIRECTORY_LIST}"x != ""x ] ; then

        LogMsg "Deleting the directorys for the overlay filesystems ..."
        for OVERLAY_DIR in ${DIRECTORY_LIST} ; do
        
          CUR_DIR="$( create_dir_name_from_the_overlay_filesystem "/${OVERLAY_DIR}" )"
          LogMsg ""

          LogMsg "Deleting the directories for the overlay filesystem for \"/${CUR_DIR}\" ..."


          DIRS_TO_DELETE="${BASEDIR}/merged/${OVERLAY_DIR} ${BASEDIR}/upper/${OVERLAY_DIR}  ${BASEDIR}/work/${OVERLAY_DIR} "

          for OVERLAY_DIR in ${DIRS_TO_DELETE} ; do
            if [ ! -d "${OVERLAY_DIR}" ] ; then  
              LogInfo "The directory \"${OVERLAY_DIR}\" does not exist"
            else
              LogMsg "Deleting the directory \"${OVERLAY_DIR}\" ..."
              \rm -rf "${OVERLAY_DIR}"
              if [ $? -ne 0 ] ; then
                LogError "Error deleting the directory \"${OVERLAY_DIR}\" "
                THISRC=${__FALSE}
              fi
            fi
          done
        done
        LogMsg ""
      else
        if [ ${THISRC} = ${__TRUE} ] ; then
          LogMsg 
          LogMsg "Use the script parameter \"list_disk\" to list all overlay filesystems on the virutal disks mounted on \"${BASEDIR}\" "
          LogMsg
        fi
      fi
    fi
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
  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__TRUE}

  typeset CUR_ENTRY=""
  typeset CUR_DIR=""
  typeset DIRS_TO_REMOUNT=""


  typeset MERGED_BACKEND=""
  typeset CUR_BACKEND=""
  typeset FILENAME=""

  typeset TEMPRC=0
  
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
      LogMsg "\"${CUR_ENTRY}\" is a directory with an overlay mount -- use the parameter \"undo ${CUR_ENTRY}\" to undo all modifications for this directory"
      continue
    fi

    CUR_BACKEND="$( get_file_overlay "${CUR_ENTRY}" )"
    TEMPRC=$?
    if [ ${TEMPRC} -eq 2 ] ; then
      LogMsg "The file or directory \"${CUR_ENTRY}\" has been not yet modified "
    elif [ ${TEMPRC} -ge 3 ] ; then
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
      mount_device -o remount "${CUR_DIR}" || THISRC=${__FALSE}
      [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x

    done
  fi

  return ${THISRC}
}


# ---------------------------------------------------------------------
# diff_files - diff changed files and original files
#
# usage:
#   diff_files [file|dir] [...file#|dir#]
#
# returns:
#   the result of the diff command for the last file in the parameter
#
function diff_files {
  typeset __FUNCTION="diff_files"
  LogInfo "*** Function ${__FUNCTION} started"

  typeset THISRC=${__TRUE}

  typeset TEMPRC=0

  typeset CUR_FILE=""

  typeset ORIGINAL_FILE=""
  typeset ORIGINAL_DEV=""

  typeset EXPANDED_LIST_OF_FILES_TO_DIFF=""

  typeset LIST_OF_FILES_TO_DIFF=""

  typeset FILES_WITH_CHANGES=""
  typeset NEW_FILES=""
  typeset DELETED_FILES=""
  typeset NOT_MODIFIED_FILES=""
  typeset TOUCHED_FILES=""
  
  typeset NO_OF_FILES_WITH_CHANGES=0
  typeset NO_OF_FILES_CHECKED=0
  typeset NO_OF_NEW_FILES=0
  typeset NO_OF_DELETED_FILES=0
  typeset NO_OF_NOT_MODIFIED_FILES=0
  typeset NO_OF_TOUCHED_FILES=0
  
  typeset FILES_ONLY=${__TRUE}
  typeset OUTFILE=""

  typeset NO_OF_MODIFIED_FILES=0

  typeset FIND_PARAMETER=""
  typeset REAL_CUR_FILE=""
  typeset PRINT_DOT=""

  typeset NO_OF_FILES_FOR_DIFF=0

# ${PRINT_DOT} is an empty dummy in verbose mode  
  [ ${VERBOSE} != ${__TRUE} ] && PRINT_DOT="printf . " 
  
#
# DIRS_TO_OVERLAY is a global variable
#

  LogMsg "Searching modified files ..."
#
# convert relative filenames to absolute filenames
#
  [[ ${CUR_FILE} != /* ]] && CUR_FILE="${PWD}/${CUR_FILE}"

#
# replace directories in the list with the list of files in the directory
#
  for CUR_FILE in ${DIRS_TO_OVERLAY} ; do

#
# resolve symbolic links
#
    REAL_CUR_FILE="$( readlink -f "${CUR_FILE}" )"
    if [ "${REAL_CUR_FILE}"x != "${CUR_FILE%*/}"x ] ; then
      LogMsg "\"${CUR_FILE}\" is a symbolic link to  \"${REAL_CUR_FILE}\" "
      CUR_FILE="${REAL_CUR_FILE}"
    fi

    if [ -d "${CUR_FILE}" ] ; then
#
# process directories
#
      LogInfo "Adding the files in the Directory \"${CUR_FILE}\" to the list of files to check  ..."

      get_file_overlay "${CUR_FILE%*/}" >/dev/null
      if [ $? -eq 3 -o "${GET_FILE_OVERLAY_RESULT}"x = ""x ] ; then
        LogMsg "There is no overlay configured for the directory \"${CUR_FILE%*/}\" "
        continue
      fi

      FILES_ONLY=${__FALSE}

      if [[ "${CUR_FILE}" = */ ]] ; then
# *// -> search the sub directories also      
        FIND_PARAMETER="-type f -o -type c "
        CUR_FILE="${CUR_FILE%*/}"
      else
# -> search only the current directory      
        FIND_PARAMETER=" -maxdepth 1 -type f -o -type c "
      fi

      FILE_LIST="$( cd "${GET_FILE_OVERLAY_RESULT}" 2>/dev/null && find . ${FIND_PARAMETER} | sed -e "s|^./|${CUR_FILE}/|g" )"

      [ "${FILE_LIST}"x = ""x ] && LogMsg "No modified files found in the directory \"${CUR_FILE}\" (add two trailing slashes \"//\" to search also in sub directories"
       EXPANDED_LIST_OF_FILES_TO_DIFF="${EXPANDED_LIST_OF_FILES_TO_DIFF} ${FILE_LIST}"
    else
#
# process files
#    
      LogInfo "Adding the file \"${CUR_FILE}\" to the list of files to check ..."

      EXPANDED_LIST_OF_FILES_TO_DIFF="${EXPANDED_LIST_OF_FILES_TO_DIFF} ${CUR_FILE%*/}"
    fi

  done

#
# calculate the number of modified files found 
#
  NO_OF_MODIFIED_FILES=$( echo "${EXPANDED_LIST_OF_FILES_TO_DIFF}" | grep -v "^[[:space:]]*$" | wc -l)
  
  LogMsg "Found ${NO_OF_MODIFIED_FILES} file(s) matching the script parameter."

# add a leading linefeed to log messages
#
  LOG_MSG_PREFIX="\n"

#
# check the modified files
#  
  for CUR_FILE in ${EXPANDED_LIST_OF_FILES_TO_DIFF} ; do

    
    (( NO_OF_FILES_CHECKED = NO_OF_FILES_CHECKED +1 ))

    OVERLAY_CONFIGURED=${__TRUE}


    ${PRINT_DOT}

    LogInfo "Checking the file \"${CUR_FILE}\" ..."

#   0 - there is an overlay for the directory/file configured and the directory/file has been modified
#   1 - there is an overlay for the directory/file configured and the directory/file has been deleted
#   2 - there is an overlay for the directory/file configured but the directory/file has not yet been modified or deleted
#   3 - there is no overlay for the directory/file configured
#    
    get_file_overlay "${CUR_FILE}" >/dev/null
    TEMPRC=$?

    case ${TEMPRC} in

      1 )
        LogMsg "The file \"${CUR_FILE}\" has been deleted"

        (( NO_OF_DELETED_FILES = NO_OF_DELETED_FILES + 1 ))
        DELETED_FILES="${DELETED_FILES}
${CUR_FILE}"

        continue
        ;;

      2 )
        if [  -r "${CUR_FILE}" ] ; then
          [ ${PRINT_MORE_DETAILS} = ${__TRUE} -o ${FILES_ONLY} = ${__TRUE}  ] && LogMsg "The file \"${CUR_FILE}\" has not been modified"
          
          (( NO_OF_NOT_MODIFIED_FILES = NO_OF_NOT_MODIFIED_FILES + 1 ))
          NOT_MODIFIED_FILES="${NOT_MODIFIED_FILES}
${CUR_FILE}"
          
          continue
        fi
        ;;

      3 )
        LogMsg "There is no overlay configured for \"${CUR_FILE}\" "
        continue
        ;;

    esac

    if [ ! -r "${CUR_FILE}" ] ; then
      LogMsg "The file \"${CUR_FILE}\" does not exist"
      continue
    fi

    ORIGINAL_FILE="${ROOTFS_MOUNT_POINT}/${CUR_FILE}"

    ORIGINAL_DEV="$( stat -c %m "${ORIGINAL_FILE}" 2>/dev/null )"

    LogInfo "The original file is \"${ORIGINAL_FILE}\" "
    LogInfo "The device with the filesystem for the original file is \"${ORIGINAL_DEV}\" "

    if [ "${ORIGINAL_DEV}" = "${BASEDIR}" -o "${ORIGINAL_DEV}"x = ""x ] ; then
      LogMsg "\"${CUR_FILE}\" is a new file or the original filesystem for that file is not mounted -- can not diff that file"

      (( NO_OF_NEW_FILES = NO_OF_NEW_FILES + 1 ))
      NEW_FILES="${NEW_FILES}
${CUR_FILE}"

      continue
    fi

     LIST_OF_FILES_TO_DIFF="${LIST_OF_FILES_TO_DIFF} ${CUR_FILE}"

  done

  if [ "${LIST_OF_FILES_TO_DIFF}" != ""x ] ; then
    if [ ${CREATE_PATCH_FILES} = ${__TRUE} ] ; then
      if [ ! -d "${PATCH_DIR}" ] ; then
        LogMsg "Creating the directory for the patch files \"${PATCH_DIR}\" ..."
        mkdir -p "${PATCH_DIR}" || die 55 "Error Creating the directory for the patch files \"${PATCH_DIR}\" "
      else
        LogInfo "The directory for the patch files \"${PATCH_DIR}\" already exists"
      fi
    fi
   fi

   LogMsg ""
   LOG_MSG_PREFIX=""
   

   NO_OF_FILES_FOR_DIFF=$(( NO_OF_MODIFIED_FILES - NO_OF_NEW_FILES - NO_OF_DELETED_FILES - NO_OF_NOT_MODIFIED_FILES ))
   
   [ ${NO_OF_FILES_FOR_DIFF} != 0 ] && LogMsg "Now executing \"${DIFF}\" for $(( NO_OF_MODIFIED_FILES - NO_OF_NEW_FILES - NO_OF_DELETED_FILES )) file(s) ..."

#
#
# use diff for each modified file found
#
  for CUR_FILE in ${LIST_OF_FILES_TO_DIFF} ; do

    LogMsg ""

    ORIGINAL_FILE="${ROOTFS_MOUNT_POINT}/${CUR_FILE}"

    PrintMsg "*** Executing \"${DIFF}\" \"${DIFF_OPTIONS}\" for the file \"${CUR_FILE}\" ..."

    CUR_OUTPUT="$( cd / && ${DIFF} ${DIFF_OPTIONS} "${ORIGINAL_FILE}" ".${CUR_FILE}" 2>&1 )"
    THISRC=$?
    LogMsg " RC=${THISRC}"

    if [ ${THISRC} != 0 ]; then

      if [ ${CREATE_PATCH_FILES} = ${__TRUE} ] ; then
        OUTFILE="${PATCH_DIR}/$( echo "${CUR_FILE}" | tr " /" "__" )${EXTENSION_FOR_PATCH_FILES}"
        [ -r "${OUTFILE}" ] && mv "${OUTFILE}" "${OUTFILE}.$$.bak"
        LogMsg "Creating the patch file \"${OUTFILE}\" ..."
        echo "${CUR_OUTPUT}" >"${OUTFILE}"
      else
        LogMsg "${CUR_OUTPUT}"
      fi

      (( NO_OF_FILES_WITH_CHANGES = NO_OF_FILES_WITH_CHANGES + 1 ))

      FILES_WITH_CHANGES="${FILES_WITH_CHANGES}
${CUR_FILE}"

    else

      (( NO_OF_TOUCHED_FILES  = NO_OF_TOUCHED_FILES + 1 ))
      TOUCHED_FILES="${TOUCHED_FILES}
${CUR_FILE}"
      
      LogMsg "${CUR_OUTPUT}"
    fi
  done

  if [ ${SHORT_INFOS} != ${__TRUE} -a  ${NO_OF_FILES_CHECKED} -gt 1 ] ; then

    LogMsg ""
    LogMsg " ---------------------------------------------------------------------- "
    LogMsg "*** Summary:"
    LogMsg ""
    LogMsg "${NO_OF_FILES_CHECKED} file(s) checked"
    LogMsg
    if [ ${NO_OF_NEW_FILES} != 0 ] ; then
      LogMsg "${NO_OF_NEW_FILES} new file(s) found:"
      LogMsg "${NEW_FILES}"
      LogMsg
    fi

    if [ ${NO_OF_TOUCHED_FILES} != 0 ] ; then
      if [[ $DIFF == /*/diff  ]] ; then
        LogMsg "${NO_OF_TOUCHED_FILES} file(s) with modified meta information (such as date, permissions, etc) found:"
      else
        LogMsg "The command \"${DIFF}\" ended with RC=0 for ${NO_OF_TOUCHED_FILES} file(s)"
      fi
      LogMsg "${TOUCHED_FILES}"
      LogMsg
    fi

    if [ ${NO_OF_DELETED_FILES} != 0 ] ; then
      LogMsg "${NO_OF_DELETED_FILES} deleted file(s) found:"
      LogMsg "${DELETED_FILES}"
      LogMsg
    fi


    if [ ${NO_OF_FILES_WITH_CHANGES} != 0 ] ; then
      if [[ $DIFF == /*/diff  ]] ; then
        LogMsg "${NO_OF_FILES_WITH_CHANGES} modified file(s) found:"
      else
        LogMsg "The command \"${DIFF}\" ended with RC != 0 for ${NO_OF_TOUCHED_FILES} file(s)"
      fi      
      LogMsg "${FILES_WITH_CHANGES}"
    else
      if [[ $DIFF == /*/diff  ]] ; then
        LogMsg "No modified files found"
      fi
    fi
    LogMsg ""
  fi

  return ${THISRC}
}


# ---------------------------------------------------------------------
# clean_mount_config - umount all overlay mounts and the mount for BASEDIR
#
# usage:
#   clean_mount_config 
#
# returns:
#   ${__TRUE} -- ok
#   ${__FALSE} -- error
#
function clean_mount_config {
  typeset __FUNCTION="clean_mount_config"
  LogInfo "*** Function ${__FUNCTION} started"

  THISRC=${__FALSE}

  typeset CUR_DIR=""

  typeset ORPHAN_OVERLAY_MOUNTS=""
  typeset NO_OF_ORPHAN_OVERLAY_MOUNTS=0
  
  typeset CUR_MOUNT=""

  typeset LIST_OF_BASEDIRS=""
  
  typeset LIST_OF_BASEDIRS=""
  typeset CUR_BASEDIR=""

  typeset CUR_BASEDIR_SUB_DIRS=""
  typeset CUR_SUB_DIR=""
  
  typeset FAILED_UMOUNT_COMMANDS=""
  
  LogMsg "Retrieving the list of base directories ..."
  
  LIST_OF_BASEDIRS="$(  print_list_of_mounts force | grep "/merged/" | cut -f3 -d " "| sed "s#/merged/.*##g" | sort | uniq  )"
  
  LogInfoVar LIST_OF_BASEDIRS

  LogMsg "Umounting the bind mounts for the original directories ..."
  
  for CUR_BASEDIR in ${LIST_OF_BASEDIRS} ; do
    LogMsg ""
    LogMsg "Processing the base directory \"${CUR_BASEDIR}\" ..."
    
    CUR_BASEDIR_SUB_DIRS="$( mount | cut -f3 -d" " | grep "${CUR_BASEDIR}/rootfs/" | sort | uniq | tac )"
    
    LogInfoVar CUR_BASEDIR_SUB_DIRS

    for CUR_SUB_DIR in ${CUR_BASEDIR_SUB_DIRS} ; do
      LogMsg "Umounting \"${CUR_SUB_DIR}\" ..." 
      ${UMOUNT} "${CUR_SUB_DIR}"
      if [ $? -ne 0 ] ; then
        LogError "Error umounting \"${CUR_SUB_DIR}\" "
      else
        LogMsg "... \"${CUR_SUB_DIR}\" successully umounted"
        THISRC=${__TRUE}
      fi

    done
  done

  LogMsg "Umount all overlay mounts ..."

  umount_overlay_mounts all || \
   die 100 "clean config requested but umounting the overlay filesystems failed"       

  LogMsg ""
  LogMsg "Umounting all overlay mounts ..."
#
# check for orphan overlay mounts
#
  ORPHAN_OVERLAY_MOUNTS="$( print_list_of_mounts force | grep ^overlay | tac | cut -f3 -d" " )"

  NO_OF_ORPHAN_OVERLAY_MOUNTS=$( echo "${ORPHAN_OVERLAY_MOUNTS}" | grep -v "^[[:space:]]*$" | wc -l )
  if [ ${NO_OF_ORPHAN_OVERLAY_MOUNTS} = 0 ] ; then
    LogMsg "No overlay mounts found"
  else
    LogMsg "${NO_OF_ORPHAN_OVERLAY_MOUNTS} overlay mount(s) found"
  fi
    
  LogInfoVar ORPHAN_OVERLAY_MOUNTS
  
  for CUR_MOUNT in ${ORPHAN_OVERLAY_MOUNTS} ; do
    LogMsg "Umounting \"${CUR_MOUNT}\" ..."
    ${PREFIX} umount_device "${CUR_MOUNT}"
    if [ $? -ne 0 ] ; then
      LogError "Error umounting \"${CUR_MOUNT}\" "
    else
      LogMsg "... \"${CUR_MOUNT}\" successully umounted"
      THISRC=${__TRUE}
    fi
   done
 
  LogMsg "Umouting remainng base dirs ..."
  
  for CUR_BASEDIR in ${LIST_OF_BASEDIRS} ; do
    is_directory_mounted "${CUR_BASEDIR}"
    if [ $? -eq ${__TRUE} ] ; then
      LogMsg "Umounting \"${CUR_BASEDIR}\" ..."
      ${UMOUNT} "${CUR_BASEDIR}"
      if [ $? -ne 0 ] ; then
        LogError "Error umounting \"${CUR_BASEDIR}\" "
      else
        LogMsg "... \"${CUR_BASEDIR}\" successully umounted"
        THISRC=${__TRUE}
      fi
    fi
  done
    
  if [ "${FAILED_UMOUNT_COMMANDS}"x != ""x ] ; then
    LogMsg ""
    LogWarning "Some umount commands failed:"
    LogMsg "${FAILED_UMOUNT_COMMANDS}"
    LogMsg ""
  fi
  return ${__THISRC}
}


# --------------------------------------------------------------------
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
  LogInfo "*** Function ${__FUNCTION} started"

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

  typeset MAGISK_BINARY=""
  typeset MAGISK_DIR=""

  typeset BIND_MOUNTS_ALREADY_CREATED=""

# these are global variables:
#
#  OVERLAY_MOUNTS_CREATED=""
#  NO_OF_OVERLAY_MOUNTS_CREATED=0
#
#  OVERLAY_MOUNTS_ALREADY_CREATED=""
#  NO_OF_OVERLAY_MOUNTS_ALREADY_CREATED=0
#
#  DIRECTORIES_MISSING=""
#  NO_OF_DIRECTORIES_MISSING=0
#
#  OVERLAY_MOUNTS_NOT_CREATED=""
#  NO_OF_OVERLAY_MOUNTS_NOT_CREATED=0
#

  BIND_MOUNTS_ALREADY_CREATED=""

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
        THISMSG="There is already an overlay mount for the directory \"${CUR_DIR}\" in place"
        if [ "${CUR_BACKEND_DIR}"x != ""x ] ; then
          THISMSG="${THISMSG}, the backend directory is \"${CUR_BACKEND_DIR}\""
          if [ "${CUR_BACKEND_DISK}"x != ""x ] ; then
            THISMSG="${THISMSG}, the backend disk is \"${CUR_BACKEND_DISK}\" "
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
      CUR_OVERLAY_MOUNTS="$(  print_list_of_mounts | grep "^overlay" | grep "${CUR_DIR}/" | grep -v "/merged/" | cut -f3 -d " "  | tr "\n" " "  )"
      if [ "${CUR_OVERLAY_MOUNTS}"x != ""x ] ; then
        LogError "There are already overlay mounts in place for sub directories in \"${CUR_DIR}\" : " "${CUR_OVERLAY_MOUNTS}"

        OVERLAY_ALREADY_IN_PLACE=${__TRUE}
      fi
    fi

    if [ ${OVERLAY_ALREADY_IN_PLACE} = ${__TRUE} ] ; then
      LogMsg
      LogMsg "${THISMSG}"
      LogMsg 
#
# change the global variables
#
      OVERLAY_MOUNTS_ALREADY_CREATED="${OVERLAY_MOUNTS_ALREADY_CREATED}
  ${CUR_DIR}"
      (( NO_OF_OVERLAY_MOUNTS_ALREADY_CREATED = NO_OF_OVERLAY_MOUNTS_ALREADY_CREATED + 1 ))
      continue

    fi

#
# there is no overlay mount in place for this directory --> create the overlay mount
#

#
# check if the magisk binary is in a sub directory of this directory
#
    MAGISK_BINARY="$( which magisk )"

    if [ "${MAGISK_BINARY}"x = ""x ] ; then
      LogInfo "No installed magisk binary found in the PATH"
    else
      MAGISK_DIR="${MAGISK_BINARY%/*}"

      if [[ ${MAGISK_DIR} == ${CUR_DIR}/* ]] ; then
        if [ ${IGNORE_MAGISK} = ${__TRUE} ] ; then
          LogMsg "INFO: Magisk is installed but no temporary copies of the Magisk executables created on request"
        else
#
# add the directory to the magisk executables
#
          MAGISK_BINARIES="$( echo " ${MAGISK_BINARIES}" | tr -s " " | sed "s# # ${MAGISK_DIR}/#g" )"

          LogMsg ""
          LogMsg "Magisk is installed in ${MAGISK_DIR} - creating temporary copies of the Magisk executables ..."
          FILES_TO_KEEP="${FILES_TO_KEEP} ${MAGISK_BINARIES}"
        fi
      fi
    fi
#
# check if this is an overlay mount for a directory in /
#
    if [ "$( dirname ${CUR_DIR} )"x = "/"x ] ; then
#
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
          CUR_SOURCE="/system/${CUR_PROG#./*}"
        else
          CUR_SOURCE="${CUR_PROG}"
        fi
#
# ignore files in other directories
#
        [[ ${CUR_SOURCE} != ${CUR_DIR}/* ]] && continue

#
# ignore duplicate entries
#
        [[ " ${BIND_MOUNTS_ALREADY_CREATED} " == *\ ${CUR_PROG}\ * ]] && continue

#
# add the filename to the list of directories already processed
#
        BIND_MOUNTS_ALREADY_CREATED="${BIND_MOUNTS_ALREADY_CREATED} ${CUR_PROG} "

        if [  -d "${CUR_SOURCE}" ] ; then
          LogError "\"${CUR_SOURCE}\" is a directory -- directories are not supported"
        elif [ ! -r "${CUR_SOURCE}" ] ; then
          LogWarning "The file \"${CUR_SOURCE}\" does not exist -- can not create a bind mount"
        else
          MOUNT_TARGET="${BIND_MOUNT_TARGET_DIR}${CUR_SOURCE}"

          if [ ! -r "${MOUNT_TARGET}" ] ; then
            CUR_SUB_DIR="${MOUNT_TARGET%/*}"
            [ ! -d "${CUR_SUB_DIR}" ] && mkdir -p "${CUR_SUB_DIR}"
            LogInfo "Creating the temporary file \"${MOUNT_TARGET}\" ..."

            touch "${MOUNT_TARGET}" || LogError "Can not create the tmeporary file \"${MOUNT_TARGET}\" "
          else
            LogInfo "The temporary file \"${MOUNT_TARGET}\" already exists"
          fi

          if [ ! -f "${MOUNT_TARGET}" ] ; then
            LogWarning "\"${MOUNT_TARGET}\" is not a file -- will not create a bind mount for it"
          elif [ -r "${MOUNT_TARGET}" ] ; then
            CUR_TARGET_SIZE="$(  stat -c%s "${MOUNT_TARGET}" )"
            if [ "${CUR_TARGET_SIZE}"x != "0"x ] ; then
              LogWarning "The size of the temporary flie \"${MOUNT_TARGET}\" is not zero (size=${CUR_TARGET_SIZE}) -- this is probably already a bind mount; will not create a bind mount for that file"
            else
              LogMsg "Creating the temporary file \"${MOUNT_TARGET}\" ..."
              mount_device -o bind "${CUR_SOURCE}" "${MOUNT_TARGET}" || \
                LogError "Error creating the bind mount \"${MOUNT_TARGET}\" -> \"${CUR_SOURCE}\" "
            fi
          fi
        fi
      done
      LogMsg ""

    fi

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
    SUB_MOUNT_POINTS="$( print_list_of_mounts | grep " ${CUR_DIR}/" | grep "^/dev/block/sd" | tr "\t" " " | tr -s " " | cut -f3 -d  " " | sort | uniq )"

#
# create the overlay mount
#
    [[ ${VERBOSE} = ${__TRUE} ]] && set -x
    mount_device -t overlay overlay -o "lowerdir=${CUR_DIR},upperdir=${BASEDIR}/upper${OVERLAY_SUBDIR},workdir=${BASEDIR}/work${OVERLAY_SUBDIR}" "${BASEDIR}/merged${OVERLAY_SUBDIR}"
    TEMPRC=$?
    [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x

    if [ ${TEMPRC} -ne 0 ] ; then
      LogError "Error creating the overlay mount for \"${CUR_DIR}\" "

      OVERLAY_MOUNTS_NOT_CREATED="${OVERLAY_MOUNTS_NOT_CREATED}
${CUR_DIR}"
      (( NO_OF_OVERLAY_MOUNTS_NOT_CREATED = NO_OF_OVERLAY_MOUNTS_NOT_CREATED + 1 ))

      if [ "${DIRECTORIES_CREATED}"x != ""x ] ; then
        LogInfo "Deleting the directories just created for this overlay mount"
        rmdir -f ${DIRECTORIES_CREATED}
      fi

      continue
    fi

    if [ ${MOUNT_ORIGINAL_FILESYSTEM} != ${__TRUE} ] ; then
      LogInfo "Mounting the original filesystems on \"${ROOTFS_MOUNT_POINT}/*\" disabled"
    else  
#
# create the temporary mount for the filesystem with the original directory
#
      mount_real_dir "${CUR_DIR}"
    fi
    
#
# create the bind mount
#
    LogMsg "Creating the bind mount \"${CUR_DIR}\"..."

    [[ ${VERBOSE} = ${__TRUE}  ]] && set -x
    mount_device -o bind "${BASEDIR}/merged${OVERLAY_SUBDIR}" "${CUR_DIR}"
    TEMPRC=$?
    [[ ${VERBOSE} = ${__TRUE} && "${TRACE}"x = ""x ]] && set +x

    if [ ${TEMPRC} -ne 0 ] ; then
      LogError "Error creating the bind mount for \"${CUR_DIR}\" "
#
# change the global variables
#
      OVERLAY_MOUNTS_NOT_CREATED="${OVERLAY_MOUNTS_NOT_CREATED}
${CUR_DIR}"
      (( NO_OF_OVERLAY_MOUNTS_NOT_CREATED = NO_OF_OVERLAY_MOUNTS_NOT_CREATED + 1 ))
#
# umount the temporary mount for the filesystem with the original directory
#
      umount_real_dir "${CUR_DIR}"

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

      mount_device -t "${CUR_SUB_MOUNT_FILESYSTEM_TYPE}" -o "${CUR_SUB_MOUNT_OPTIONS}" "${CUR_SUB_MOUNT_DEVICE}" "${CUR_MOUNT_POINT}"
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
      (( NO_OF_OVERLAY_MOUNTS_CREATED = NO_OF_OVERLAY_MOUNTS_CREATED + 1 ))

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
  LogInfo "*** Function ${__FUNCTION} started"

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

# THIS_OVERLAY_MOUNTS = mount points for overlay mounts only (e.g (/vendor)
#
  THIS_OVERLAY_MOUNTS="$( echo "${LIST_OF_OVERLAY_MOUNTS}" | sed -e "s#.*/##g"  -e "s/#/\//g" -e "s#^#/#g" )"

# ALL_OVERLAY_MOUJNTS = mount points for overlay mounts (e.g. /data/local/tmp/virtualfs001/merged/vendor )
#
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

  CUR_OVERLAY_FILESYSTEMS="$( echo "${CUR_OVERLAY_FILESYSTEMS}" | grep -E -v "^[[:space:]]*$" )"

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

  LogInfo "*** Function ${__FUNCTION} started"

  LogMsg
  LogMsg "Summary:"
  LogMsg "--------"

  if [ ${NO_OF_OVERLAY_MOUNTS_CREATED} != 0 ] ; then
    LogMsg
    LogMsg "${NO_OF_OVERLAY_MOUNTS_CREATED} overlay mount(s) created:"
    LogMsg "${OVERLAY_MOUNTS_CREATED}"
  fi

  if [ ${NO_OF_OVERLAY_MOUNTS_ALREADY_CREATED} != 0 ] ; then
    LogMsg
    LogMsg "${NO_OF_OVERLAY_MOUNTS_ALREADY_CREATED} directory or files are already on an overlay mount:"
    LogMsg "${OVERLAY_MOUNTS_ALREADY_CREATED}"
  fi

  if [ ${NO_OF_OVERLAY_MOUNTS_NOT_CREATED} != 0 ] ; then
    LogMsg
    LogMsg "${NO_OF_OVERLAY_MOUNTS_NOT_CREATED} overlay mount(s) not created because of an error:"
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

  LogInfo "*** Function ${__FUNCTION} started"

  typeset NAME_FIELD_LENGTH=10

  typeset DEFAULT_VALUE_FIELD_LENGTH=10

  typeset CUR_VAR=""
  typeset CUR_VALUE=""

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

  for CUR_VAR in ${CUR_ENVIRONMENT_VARIABLES} ; do
    CUR_VALUE="$( eval echo "\$DEFAULT_${CUR_VAR}" )"
    [ ${#CUR_VALUE} -gt ${DEFAULT_VALUE_FIELD_LENGTH} ] && DEFAULT_VALUE_FIELD_LENGTH="${#CUR_VALUE}"
  done
  (( DEFAULT_VALUE_FIELD_LENGTH = DEFAULT_VALUE_FIELD_LENGTH + 4 ))

  let NAME_FIELD_LENGTH=NAME_FIELD_LENGTH+5
  printf "%-${NAME_FIELD_LENGTH}s %-${DEFAULT_VALUE_FIELD_LENGTH}s %s\n" "Name" "Default Value" "Current Value"
  printf "%-${NAME_FIELD_LENGTH}s %-${DEFAULT_VALUE_FIELD_LENGTH}s %s\n" "----" "-------------" "-------------"

  for CUR_VAR in ${CUR_ENVIRONMENT_VARIABLES} ; do
    printf  "%-${NAME_FIELD_LENGTH}s %-${DEFAULT_VALUE_FIELD_LENGTH}s %s\n" "${CUR_VAR}"  "$( eval echo "\$DEFAULT_${CUR_VAR}" )"  "$( eval echo "\$${CUR_VAR}" )"
  done

  echo "
Use the value \"none\" for the environment variables \"*_OPTIONS\" do remove all options
"

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
else
  VERBOSE=${__FALSE}
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

NO_LABEL_PARAMETER_FOUND=${__FALSE}

EXECUTABLES_TO_RUN=""

IGNORE_WRONG_DIR_PARAMETER=${__FALSE}

CREATE_SPARSE_FILE=${__FALSE}

CREATE_PATCH_FILES=${__FALSE}

MOUNT_ORIGINAL_FILESYSTEM=${__TRUE}

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

     --yes | -y | ++no )
        USER_RESPONSE="yes"
        ;;

     --no | -n |  ++yes )
        USER_RESPONSE="no"
        ;;

     --no_rootfs )
        MOUNT_ORIGINAL_FILESYSTEM=${__FALSE}
        ;;

     ++no_rootfs )
        MOUNT_ORIGINAL_FILESYSTEM=${__TRUE}
        ;;

     --active )
        PROCESS_ONLY_MOUNTED_OVERLAY_FILESYSTEMS=${__TRUE}
        ;;

     ++active )
        PROCESS_ONLY_MOUNTED_OVERLAY_FILESYSTEMS=${__FALSE}
        ;;

     --nomagisk )
        IGNORE_MAGISK=${__TRUE}
        ;;

     ++nomagisk )
        IGNORE_MAGISK=${__FALSE}
        ;;

     --sparse )
        CREATE_SPARSE_FILE=${__TRUE}
        ;;

     ++sparse )
        CREATE_SPARSE_FILE=${__FALSE}
        ;;

     --details | -d )
        PRINT_MORE_DETAILS=${__TRUE}
        ;;

      ++details | +d )
        PRINT_MORE_DETAILS=${__FALSE}
        ;;

      --short )
        SHORT_INFOS=${__TRUE}
        ;;

      ++short )
        SHORT_INFOS=${__FALSE}
        ;;

      --no_relabel | --norelabel )
        RELABEL_UNLABELED_FILES=${__FALSE}
        NO_LABEL_PARAMETER_FOUND=${__TRUE}
        ;;

      --relabel )
        RELABEL_UNLABELED_FILES=${__TRUE}
        NO_LABEL_PARAMETER_FOUND=${__FALSE}
        ;;

      --run=* | --script=* )
        CUR_VAL="${CUR_PARAMETER#*=}"
        EXECUTABLES_TO_RUN="${EXECUTABLES_TO_RUN} $( echo "${CUR_VAL}" | tr "," " " )"
        ;;

      --patch )
        CREATE_PATCH_FILES=${__TRUE}
        ;;

      ++patch )
        CREATE_PATCH_FILES=${__FALSE}
        ;;

      *=* )
        LogInfo "Executing now \"${CUR_PARAMETER}\" ..."
        CUR_VAR="${CUR_PARAMETER%%=*}"
        CUR_VAL="${CUR_PARAMETER#*=}"
        eval ${CUR_VAR}=\"${CUR_VAL}\"
        if [ $? -ne 0 ] ; then
          die 70 "Error executing \"${CUR_PARAMETER}\" "
        fi

        if [[ " ${ENVIRONMENT_VARIABLES_LIST} "  != *\ ${CUR_VAR}\ * ]] ; then
          LogWarning " \"${CUR_VAR}\" is not a known variable"
        fi
        ;;

      -V | --version )
        ACTION="version"
         ;;

      list )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="list"
        ;;

      list_disk )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="list_disk"
        ;;

      delete )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="delete"
        ;;
      
      clean | cleanup )
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

      diff_file | diff_files )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
         ACTION="diff_file"
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

      mount_existing )
        [ "${ACTION}"x != ""x ] && die 101 "Duplicate action parameter found (\"${ACTION}\" and \"${CUR_PARAMETER}\") "
        ACTION="mount_existing"
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
        VERBOSE="${__FALSE}"
        ;;

      --noselinux | --no_selinux | --disable_selinux )
        NEW_SELINUX_MODE="Permissive"
        ;;

      --selinux | --selinux | --enable_selinux )
        NEW_SELINUX_MODE="Enforcing"
        ;;

      --no_su | --no-su )
         :  # the parameter is already prcoessed (++no-su is not usefull)
         ;;

      --relax | -r )
         IGNORE_WRONG_DIR_PARAMETER=${__TRUE}
         ;;

      ++relax  | +v )
         IGNORE_WRONG_DIR_PARAMETER=${__FALSE}
         ;;

      "" )
        :   # ignore empty parameter
        ;;

      --* | -* )
        die 80 "Unknown parameter found: ${CUR_PARAMETER}"
        ;;

      * )


        DIRECTORY_FOUND_IN_THE_PARAMETER=${__TRUE}

        if [[ " get restore diff_file diff_files" == *\ ${ACTION}\ * ]] ; then
#
# file parameter are allowed for these actions
#
          [[ ${CUR_PARAMETER} = ./*  ]] && CUR_PARAMETER="${PWD}/${CUR_PARAMETER#./*}"
          [[ ${CUR_PARAMETER} != /*  ]] && CUR_PARAMETER="${PWD}/${CUR_PARAMETER}"

          DIRS_TO_OVERLAY="${DIRS_TO_OVERLAY} ${CUR_PARAMETER}"

        else

          case ${CUR_PARAMETER} in

            default )
              DIRS_TO_OVERLAY="${DIRS_TO_OVERLAY} ${DEFAULT_DIRS_TO_OVERLAY}"
              ;;

            none )
              DIRS_TO_OVERLAY=""
              ;;

            /* )
              if [[ ${CUR_PARAMETER} == *'#'* ]] ; then
                die 81 "Directory names with a hash \"#\" are not supported (${CUR_PARAMETER})  -- use \"IMAGE_FILE=${CUR_PARAMETER}\" to define the image file to use "
              fi
             DIRS_TO_OVERLAY="${DIRS_TO_OVERLAY} ${CUR_PARAMETER}"

              ;;

            * )
              if [ ! -d "${CUR_PARAMETER}" ] ; then
                if [ ${IGNORE_WRONG_DIR_PARAMETER} = ${__TRUE} ] ; then
                  LogWarning "The parameter \"${CUR_PARAMETER}\" is not a directory - the parameter will be ignored"
                else
                  die 82 "The parameter \"${CUR_PARAMETER}\" is not a directory (use the parameter \"--relax\" to ignore this parameter"
                fi
              else
                DIRS_TO_OVERLAY="${DIRS_TO_OVERLAY} ${CUR_PARAMETER}"
              fi
#             die 90 "Unknown parameter found: \"${CUR_PARAMETER}\" "
              ;;

          esac
        fi
        ;;

    esac
  done
fi

if [ "${FILES_TO_KEEP}"x = "none"x ] ;then
  FILES_TO_KEEP=""
elif [ "${FILES_TO_KEEP}"x = ""x ] ;then
#
# FILES_TO_KEEP is empty - use the default files to keep
#
  FILES_TO_KEEP="${DEFAULT_FILES_TO_KEEP}"

elif [[ " ${FILES_TO_KEEP} " = *\ default\ * ]] ; then
#
# default used in the variable FILES_TO_KEEP -- add the default files to keep
#
  FILES_TO_KEEP=" ${FILES_TO_KEEP} "
  FILES_TO_KEEP="${FILES_TO_KEEP/ default /${DEFAULT_FILES_TO_KEEP} }"
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
# replace LogInfoVar with an empty dummy function if not used
#

[ ${VERBOSE} != ${__TRUE} ] && function LogInfoVar { return 0  ; }

# ----------------------------------------------------------------------
# use user defined binaries only if the variables are defined
#
[ "${LOSETUP}"x = ""x ] && LOSETUP="${DEFAULT_LOSETUP}"
[ "${MOUNT}"x = ""x ]   && MOUNT="${DEFAULT_MOUNT}"
[ "${UMOUNT}"x = ""x ]  && UMOUNT="${DEFAULT_UMOUNT}"
[ "${MKFS}"x = ""x ]    && MKFS="${DEFAULT_MKFS}"
[ "${DD}"x = ""x ]      && DD="${DEFAULT_DD}"

[ "${DIFF}"x = ""x ]      && DIFF="${DEFAULT_DIFF}"

LogInfoVar LOSETUP
LogInfoVar MOUNT
LogInfoVar UMOUNT
LogInfoVar MKFS
LogInfoVar DD
LogInfoVar DIFF
LogInfoVar DIFF_OPTIONS


# ----------------------------------------------------------------------
# get the list of mounts
#
print_list_of_mounts force quiet

# ----------------------------------------------------------------------
# default target directory for the bind mounts for the files listed in the variable FILES_TO_KEEP
#
[ "${BIND_MOUNT_TARGET_DIR}"x = ""x ] && BIND_MOUNT_TARGET_DIR="${DEFAULT_BIND_MOUNT_TARGET_DIR}"

# ----------------------------------------------------------------------
# default directory for patch files
#
PATCH_DIR="${PATCH_DIR:=${DEFAULT_PATCH_DIR}}"

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

# directory to mount the original filesystems
#
ROOTFS_MOUNT_POINT="${BASEDIR}/rootfs"

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
elif [ "${MKFS_OPTIONS}"x = "none"x ] ; then
  LogInfo "Using no options for the mkfs* command to create the filesystem on the loop device \"${MKFS_OPTIONS}\" (variable MKFS_OPTIONS)"
  MKFS_OPTIONS=""
else
  LogInfo "Using the options \"${MKFS_OPTIONS}\" for the mkfs* command to create the filesystem on the loop device (variable MKFS_OPTIONS)"
fi

if [ "${MOUNT_OPTIONS}"x = ""x ] ; then
  MOUNT_OPTIONS="${DEFAULT_MOUNT_OPTIONS}"

  LogInfo "Using the default mount options to mount the loop device \"${MOUNT_OPTIONS}\" (variable MOUNT_OPTIONS)"
elif [ "${MOUNT_OPTIONS}"x = "none"x ] ; then
  LogInfo "Using no mount options to mount the loop device \"${MOUNT_OPTIONS}\" (variable MOUNT_OPTIONS)"
  MOUNT_OPTIONS=""
else
  LogInfo "Using the mount options \"${MOUNT_OPTIONS}\" to mount the loop device (variable MOUNT_OPTIONS)"
fi


if [ "${TMP_MOUNT_OPTIONS}"x = ""x ] ; then
  TMP_MOUNT_OPTIONS="${DEFAULT_TMP_MOUNT_OPTIONS}"

  LogInfo "Using the default mount options for the temporary mounts of the original filesystems  \"${TMP_MOUNT_OPTIONS}\" (variable TMP_MOUNT_OPTIONS)"
elif [ "${TMP_MOUNT_OPTIONS}"x = "none"x ] ; then
  LogInfo "Using no mount options for the temporary mountss of the original filesystms"
  TMP_MOUNT_OPTIONS=""
else
  LogInfo "Using the mount options \"${TMP_MOUNT_OPTIONS}\" for the temporary mounts of the original filesystems  (variable TMP_MOUNT_OPTIONS)"
fi


if [ "${DIFF_OPTIONS}"x = ""x ] ; then
  DIFF_OPTIONS="${DEFAULT_DIFF_OPTIONS}"

  LogInfo "Using the default diff options  \"${DIFF_OPTIONS}\" (variable DIFF_OPTIONS)"
elif [ "${DIFF_OPTIONS}"x = "none"x ] ; then
  LogInfo "Using no diff options"
  DIFF_OPTIONS=""
else
  LogInfo "Using the diff options \"${DIFF_OPTIONS}\"  (variable DIFF_OPTIONS)"
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

if [ "${EXTENSION_FOR_PATCH_FILES}"x = ""x ] ; then
  EXTENSION_FOR_PATCH_FILES="${DEFAULT_EXTENSION_FOR_PATCH_FILES}"

  LogInfo "Using the default extension for patch files \"${EXTENSION_FOR_PATCH_FILES}\" (variable EXTENSION_FOR_PATCH_FILES)"
else
  LogInfo "Using the extension for patch files \"${EXTENSION_FOR_PATCH_FILES}\" (variable EXTENSION_FOR_PATCH_FILES)"
fi


if [ "${USER_RESPONSE}"x = ""x ] ; then
  USER_RESPONSE="${DEFAULT_USER_RESPONSE}"

  LogInfo "Using the default user response \"${USER_RESPONSE}\" (variable USER_RESPONSE)"
else
  LogInfo "Using the user response \"${USER_RESPONSE}\" (variable USER_RESPONSE)"
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

case ${ACTION} in

  mount_only | mount_existing | clean | list )
    if [ ${DIRECTORY_FOUND_IN_THE_PARAMETER} = ${__TRUE}  ] ;then
      if [ ${IGNORE_WRONG_DIR_PARAMETER} != ${__TRUE} ] ; then
        die 75 "Directory parameter are not allowed for the action \"${ACTION}\" "
      else
        LogWarning "Directory parameter are not used for the action \"${ACTION}\" "
      fi
    fi
    ;;

esac

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

# ---------------------------------------------------------------------

# check the prerequisites for the other actions

CUR_USER="$( id -un )"

if [ "${CUR_USER}"x != "root"x ] ; then

  if [ "${SU_ERROR_MESSAGE}"x != ""x ] ; then
     LogMsg
     LogMsg "${SU_ERROR_MESSAGE}"
     LogMsg
  fi
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

case ${ACTION} in

  list_disk )
    list_virtual_disk_contents
    die $?
    ;;

  delete )
    delete_overlay_filesystem
    die $?
    ;;

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

  diff_file )
    if [ ${DIRECTORY_FOUND_IN_THE_PARAMETER} = ${__FALSE} ] ; then
      LogWarning "No files to diff found in the parameter"
    else
      diff_files
    fi
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
    clean_mount_config
    MAIN_RC=$?
    ;;

  mount | mount_only | mount_existing )
    if [ ${INIT_DISK} = ${__TRUE} ] ; then
      LogMsg "Initializing the virtual disk requested -- now umounting all overlay filesystems ..."
      umount_overlay_mounts || \
        die 100 "init disk requested but umounting the overlay filesystems failed"
    fi

    LogInfo "### Now the action starts ..."

# get the image file used if BASEDIR is already mounted    
    is_directory_mounted "${BASEDIR}"
    if [ $? -eq ${__TRUE} ] ; then
      IMAGE_FILE="$( losetup -a | grep $( df -h "${BASEDIR}" | tail -1  | cut -f1 -d " " ) | tr "()" "||" | cut -f2 -d "|"  )"
    fi
    
#
# create the image file
#
    mount_virtual_disk

#
# get the list of overlay directories in the virtual disk
#

# add a leading "/" to the directory names
#
    DIR_LIST="$( cd "${BASEDIR}/upper" 2>/dev/null && ls | sed "s#^#/#g" | tr "\n" " "   )"

    if [ "${ACTION}"x = "mount_existing"x ] ; then

#
# search for conflicing directories on the virtual disk
#
      DUPLICATE_DIRS=""
      
      for CUR_DIR in ${DIR_LIST} ; do 
        [[ ${DIR_LIST} == *${CUR_DIR}#* ]] && DUPLICATE_DIRS="${DUPLICATE_DIRS} 
${CUR_DIR}"
      done  

      if [ "${DUPLICATE_DIRS}"x != ""x ] ; then
        LogMsg ""
        LogError "There are conflicting entries for these directories on the virtual disk"
        LogMsg "${DUPLICATE_DIRS}"
        LogMsg ""
        die 94 "The action \"mount_existing\" is not possible with this configuration; use the action parameter \"list_disk\" to list the directories on the virtual disk"
      fi

      LogInfo "Only mount the existing overlay directories on the virtual disk .."
      DIRS_TO_OVERLAY="$( echo "${DIR_LIST}" | tr "#" "/" )"
      LogInfo "Now mounting the overlay directories for the directories \"${DIRS_TO_OVERLAY}\" ..."

      if [ "${DIRS_TO_OVERLAY}"x = ""x ] ; then
        die 95 "There are no overlay directories on the virtual disk"
      fi
    fi

#
# correct the SELinux context for the files and directories in the ./upper dir with unlabeled SELinux context
#
    create_overlay_directory_tree

    LogInfo "Checking for overlay directories that should be relabeled ..."

    LogInfo "DIRS_TO_OVERLAY is \"${DIRS_TO_OVERLAY}\" "

    DIRS_TO_RELABEL=""

    if [ "${ACTION}"x = "mount_only"x ] ; then
#
# option "--relabel" and action "mount_only" --> relabel all overlay filesystems on the virtual disk
#
      if [ ${RELABEL_UNLABELED_FILES} = ${__TRUE} ] ; then
        DIRS_TO_RELABEL="${DIR_LIST}"
      fi
    else
#
# relabel all the overlay mounts for all filesystem found in the parameter
#
      DIRS_TO_RELABEL="${DIRS_TO_OVERLAY}"
    fi

    LogInfo "The list of overlay directories to check for relableing is \"${DIRS_TO_RELABEL}\"  "

    for CUR_DIR in ${DIR_LIST} ; do
      LogInfo "Checking the directory \"${CUR_DIR}\" ...."

      if [[ ${CUR_DIR} = *\#* ]] ; then
        LogInfo "relabeling is not yet implemented for the directory \"${CUR_DIR}\" "
        continue
      fi

      if [ "${DIRS_TO_RELABEL}"x != ""x ] ; then
        if [[ " ${DIRS_TO_RELABEL} " != *\ ${CUR_DIR}\ * ]] ; then
          LogInfo "The directory \"${CUR_DIR}\" is not in the list of overlays - skipping this directory"
          continue
        fi
      fi

      RELABEL_THIS_DIR=${__FALSE}

      RELABEL_FILE_NAME="${CUR_DIR}/relabel"
      RELABEL_FILE="${BASEDIR}/upper${RELABEL_FILE_NAME}"

      if [  -r "${RELABEL_FILE}" ] ; then
        if [ "${ACTION}"x = "mount_only"x ] ; then
#
# action "mount_only" without the option "--relabel" -> do not relabel any file
#
          :
        elif [ ${NO_LABEL_PARAMETER_FOUND} = ${__TRUE} ] ; then
          LogInfo "File \"${RELABEL_FILE_NAME}\" found but parameter \"--no_relabel\" found -- skipping this directory "
        else
          LogMsg "File \"${RELABEL_FILE_NAME}\" found - will relabel this directory "
          RELABEL_THIS_DIR=${__TRUE}
        fi
      fi

      if [ ${RELABEL_UNLABELED_FILES} = ${__TRUE}  ] ; then
        LogInfo "Option \"--relabel\" was used  -- will relabel this directory"
        RELABEL_THIS_DIR=${__TRUE}
      fi

      if [ ${RELABEL_THIS_DIR} = ${__TRUE} ] ;then
        set_selinux_context_for_files "${BASEDIR}/upper${CUR_DIR}" "${CUR_DIR}"
      fi

    done


    if [ "${ACTION}"x != "mount_only"x ] ; then
      create_overlay_mounts

#
# execute the post installation commands if there are any defined
#
      if [ "${EXECUTABLES_TO_RUN}"x != ""x ] ; then
        for CUR_EXECUTABLE in ${EXECUTABLES_TO_RUN} ; do
          LogMsg "-"
          LogMsg "Now executing the post installation commands ..."
          if [ ! -x "${CUR_EXECUTABLE}" ] ; then
            LogWarning "The executable \"${CUR_EXECUTABLE}\" does not exist or is not executable"
            continue
          else
            LogMsg "+++ Now executing \"${CUR_EXECUTABLE}\" ..."
            LogMsg "-"
            ${CUR_EXECUTABLE}
            TEMPRC=$?
            LogMsg "-"
            LogMsg "+++ The command \"${CUR_EXECUTABLE}\" ended with RC=${TEMPRC}"
            LogMsg "-"
          fi
        done
      fi

      print_summary
    else
      LogMsg ""
      LogMsg "The virtual disk is mounted to \"${BASEDIR}\" "
    fi
    ;;

esac

LogMsg ""

die ${MAIN_RC}

