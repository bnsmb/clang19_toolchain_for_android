#!/bin/sh
#
# The first part of the script is the runtime system. 
# The main function starts after the comment
#
#   # main code starts here
#

# ----------------------------------------------------------------------

# define constants
#
__TRUE=0
__FALSE=1

__TRUE_FALSE[0]="true"
__TRUE_FALSE[1]="false"


# ----------------------------------------------------------------------
# search a directory for temporary files; abort the script if no directory for temporary files is found
#
if [ "${TMPDIR}"x = ""x ] ; then
  if [ -d "/sdcard/Download" ] ; then
    TMPDIR="/sdcard/Download"
  elif [ -d "/data/local/tmp" ] ; then
    TMPDIR="/data/local/tmp"
  elif [ -d "/tmp" ] ; then
    TMPDIR="/tmp"
  else
    echo "ERROR: No directory for temporary files found (set the variable TMPDIR to avoid this error)"
    exit 204
  fi
fi

if [ ! -d "${TMPDIR}" ] ; then
  echo "ERROR: The directory for temporary files \"${TMPDIR}\" does not exist (correct the variable TMPDIR to avoid this error)"
  exit 204
fi

if ! touch "${TMPDIR}/testfile.$$" 2>/dev/null  ; then
  echo "ERROR: Can not write to the directory for temporary files \"${TMPDIR}\" (correct the variable TMPDIR to avoid this error)"
  exit 204
else
  \rm -f "${TMPDIR}/testfile.$$" 2>/dev/null
fi

# ----------------------------------------------------------------------
# check if we're running in a shell in Android
#
RUNNING_IN_ANDROID=${__FALSE}

if [ "${GETPROP}"x = ""x ] ; then
  GETPROP="$( which getprop )"
  if [ "${GETPROP}"x = ""x -a -x /system/bin/getprop ] ; then
    GETPROP="/system/bin/getprop"
  elif [ "${GETPROP}"x = ""x -a -x /bin/getprop ] ; then
    GETPROP="/bin/getprop"
  fi
fi

if [ "${GETPROP}"x != ""x ] ; then
  CUR_OUTPUT="$( "${GETPROP}" 2>&1 )"
  if [ $? -eq 0 ] ; then
    RUNNING_IN_ANDROID=${__TRUE}  
  fi
fi

# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
# internal variable with the list of supported environment variables
#
# one entry per line; format for each entry
#
# name # type # comment
#
# type and comment are optional
#
# sample entry:
#
# PREFIX                     # string   # prefix used in dry-run-mode
#
ADDITIONAL_ENV_VARIABLES="
"

# Script Usage (lines starting with "#h#" are printed if the parameter -h or -H is used; lines starting with "#H#" are only printed if the parameter -H is used
#
# ----------------------------------------------------------------------
# android_explorer.sh
#
# Function: Collect logs, config files, and command output in Android for trouble shooting
#H# 
#h# android_explorer #VERSION# - collect logs and configuration infos from a running Android OS
#h#
#h# Usage:    android_explorer.sh [-h|--help] [-v|--verbose] [-v:fn|--verbose:fn] [-q|--quiet] [-f|--force] [-o|--overwrite] [-y|--yes] [-n|--no]
#h#               [-l|--logfile [filename[:n]|:n] [-d{:dryrun_prefix}|--dryrun{:dryrun_prefix}] [-D|--debugshell] [-t fn|--tracefunc fn] [-L]
#h#               [-T|--tee] [-V|--version] [--var name=value] [--appendlog] [--nologrotate] [--noSTDOUTlog] [--print_runtime_vars]
#h#               [--nocleanup] [--nobackups] [--disable_tty_check] [--noroot] [-I|--include includefile]
#h#               [-x|--disable module] [-i|--enable module] [-O|--outputfile outputfile] [-w|--workdir workdir] [--keep] [--list] [module1 ... module#]
#h#
#H# Parameter:
#H#   -h - print the script usage; use \"-h\" and \"-v\" one or more times to print more help text
#H#        
#H#   -v - verbose mode; use \"-v\" \"-v\" to also print the runtime system messages 
#H#        (or set the environment variables VERBOSE to 0 and VERBOSE_LEVEL to the level)
#H#   -v:fn
#H#        enable verbose mode for the function \"fn\"; use the comma \",\" to separate multiple functions
#H#        or use the parameter more than once. The format \"-v fn\" is NOT supported for this parameter.
#U#        Note that this only works for functions using the code from the function \"function_template\"
#U#        Also note that the script will create an alias for return if this parameter is used
#H#   -q - quiet mode (or set the environment variable QUIET to 0)
#H#   -f - force execution (or set the environment variable FORCE to 0 )
#H#   -o - enable overwrite mode (or set the environment variable OVERWRITE to 0 )
#H#   -y - answer yes to all questions
#H#   -n - answer no to all questions
#H#   -l - logfile to use; use \"-l none\" or \"-l -\" to not use a logfile at all
#H#        the default logfile is ${TMPDIR}/${SCRIPTNAME}.log
#H#        also supported is the format \"-l:filename\"
#H#        The build-in logrotate will keep ${NO_OF_LOGFILES_TO_KEEP} versions of the log file
#H#        Use the prefix \":n\" for the filename to change the number of logfiles to keep
#H#        Use the syntax \"-l :n\" or \"-l default:n\" to use the default logfile and only change the number of logfiles to keep 
#U#        Alternative:  
#U#          Set the environment variable NO_OF_LOGFILES_TO_KEEP to change this value either before
#U#          starting the script or using the parameter \"--var NO_OF_LOGFILES_TO_KEEP=n\"
#H#   -d - dryrun mode, default dryrun_prefix is: \"${DEFAULT_DRYRUN_PREFIX} \"
#H#        Use the parameter \"-d:<dryrun_prefix>\" or the syntax
#H#        \"PREFIX=<new dryrun_prefix> ${REAL_SCRIPTNAME}\" 
#H#        to change the dryrun prefix
#H#        The script will run in dryrun mode if the environment variable PREFIX
#H#        is set. To disable that behaviour use the parameter \"+d\"
#H#        If the parameter \"-d\" is used without a value and there are other
#H#        parameter following that do NOT start with a hyphen (-) use the format \"-d - [other_parameter]\"
#H#        $( [ ${DRYRUN_MODE_DISABLED} = ${__TRUE} ] && echo "Note: dryrun mode is not supported in this script" ) 
#H#        
#H#   -D - start a debug shell and continue the script afterwards
#H#        Note that the debug shell will be executed while processing the parameter; the parameter can be used
#H#        multiple times
#H#        
#H#   -t - trace the function fn; the parameter can be used multiple times.
#H#        also supported is the format \"-t:fn[,...,fn#]\"
#H#        This functionality does not work for a few internal functions used by the runtime system.
#H#   -L - list all defined functions and end the script
#H#   -T - copy STDOUT and STDERR to the file ${TMPDIR}/${SCRIPTNAME}.$$.tee.log 
#H#        using tee; set the environment variable __TEE_OUTPUT_FILE before 
#H#        calling the script to change the file used for the output of tee
#H#        Note that you can NOT set the variable __TEE_OUTPUT_FILE using the parameter \"--var var=value\"
#H#   -V - print the script version and exit; use \"-v -V\" to print the 
#H#        template version also
#H#   --var 
#H#      - set the variable \"name\" to the value \"value\"
#H#        also supported is the format \"--var:<varname>=<value>\"
#H#   --appendlog
#H#      - append the messages to the logfile (default: overwrite an existing logfile)
#H#        This parameter also sets \"--nologrotate\"
#H#   --nologrotate
#H#      - do not create a backup of an existing logfile
#H#   --noSTDOUTlog
#H#      - do not write STDOUT/STDERR to a file if /dev/tty is not a a device
#H#   --nocleanup
#H#      - do no house keeping at script end
#H#   --nobackups
#H#      - do not create backups
#H#   --disable_tty_check
#H#      - disable the check if we do have a tty
#H#   --print_runtime_vars
#H#      - print the runtime variables defined and exit the script
#H#   --noroot 
#H#      - do not execute commands as root user
#H#   -I - include files with additional module definitions; 
#H#        "includefile" can be either a file or a directory; if the value is a directory the scripts reads
#H#        all file matching the regular expression "*.include" in that directory.
#H#        Use "none" to disable all include files; use "default" to add the default include files.
#H#        Default include files are all files matching the regular expression "*.include" in the directory
#H#        with this scripts and the current directory (in this order). The default include files are not
#H#        used by default if the parameter \"-I\" is used
#H#   -x 
#H#      - do not execute the module \"module\"
#H#        The parameter can be used multiple times; use \"none\" to clear the list of modules to exclude
#H#        use a comma "," to separate modules
#H#   -i 
#H#      - execute the module \"module\"
#H#        The parameter can be used multiple times; use \"none\" to clear the list of modules to execute
#H#        use a comma "," to separate modules
#H#        use \"all\" to execute all modules (this is the default)
#H#        If a module is in the list of modules to execute and in the list of modules to exclude it is not executed
#H#   -O 
#H#      - create the ZIP file \"outputfile\" with the collected files
#H#   -w   
#H#      - use the working directory \"workdir\"
#H#   --keep
#H#      - do not delete the working directory
#H#   --list 
#H#      - list the defined modules and exit
#H#
#H#
#U# Parameter that toggle a switch from true to false or vice versa can
#U# be used with the plus sign (+) instead of minus (-) to invert the usage, e.g.
#U# 
#U# The parameter \"-v\" enables the verbose mode; the parameter \"+v\" disables the verbose mode.
#U# The parameter \"--quiet\" enables the quiet mode; the parameter \"++quiet\" disables the quiet mode.
#U#
#U# All parameter are processed in the given order, e.g.
#U#
#U#  android_explorer.sh -v +v
#U#    -> verbose mode is now off
#U#
#U#  android_explorer.sh +v -v
#U#    -> verbose mode is now on
#U#
#U# Parameter are evaluated after the evaluation of environment variables, e.g
#U#
#U# VERBOSE=0  android_explorer.sh
#U#     -> verbose mode is now on
#U#
#U# VERBOSE=0  android_explorer.sh +v
#U#     -> verbose mode is now off
#U#
#U# 
#U# To disable one or more of the house keeping tasks you might set some variables
#U# either before starting the script or via the parameter \"--var name=value\"
#U# 
#U# The defined variables are
#U# 
#U#  NO_EXIT_ROUTINES=0       # do not execute the exit routines if set to 0
#U#  NO_TEMPFILES_DELETE=0    # do not delete temporary files if set to 0
#U#  NO_TEMPDIR_DELETE=0      # do not delete temporary directories if set to 0
#U#  NO_FINISH_ROUTINES=0     # do not execute the finish routines if set to 0
#U#  NO_UMOUNT_MOUNTPOINTS=0  # do not umount temporary mount points if set to 0
#U#  NO_KILL_PROCS=0          # do not kill the processes if set to 0
#U#  
### Predefined Return codes:
###
###   2     Invalid parameter found
### 200     Script aborted for unknown reason; EXIST signal received
### 201     Script aborted for unknown reason, QUIT signal received
### 202     This script must be executed by root only
### 203     internal error
### 204     No temporary directory found
### 205     The script is not running in Android 
### 206     Function not supported in Android
### 250     ${SCRIPTNAME} aborted by CTRL-C
### 253     Can not create backups of the log files
### 254     ${SCRIPTNAME} aborted by the user
###
### ---------------------------------

### Note: The format of the entries for the history list should be
### 
###       #V#   <date> v<version> <comment>
#V#
#V# History:  
#V#   04.05.2026 v0.0.1 /bs
#V#     initial release 
#V#
#V#   20.05.2026 v0.0.2 /bs
#V#     added more dmctl commands to print the config of the dynamic partitions to the storage module
#V#     added mount_dynamic_partition commands to the storage module
#V#     added a command to retrieve the size of the privapps to the module privapp
#V#     added the module apps
#V#
#V#   08.08.2026 v0.0.3 /bs
#V#     the script now searches the binaries and scripts also in /system/usr/bin
#V#     added the module for collecting infos about overlay mounts
#V#
#T# ----------------------------------------------------------------------
#T#

# To temporary enable "set -x" use
#
# # set -x if VERBOSE is on
#      [[ ${VERBOSE} = ${__TRUE} ]] && set -x 
#      ${MOUNT} -o remount "${OVERLAY_MERGED_DIR}" 
#      TEMPRC=$?
#
# # set +x if TRACE is not enabled
#      [[ ${VERBOSE} = ${__TRUE} && "${__TRACE}"x = ""x ]] && set +x 
#      if [ ${TEMPRC} -ne 0 ] ; then
#        :
#      fi
#

# ----------------------------------------------------------------------
#
#
# use "grep -E" instead of "egrep" if supported (this is OS independent)
#
echo test | grep -E test 2>/dev/null >/dev/null && EGREP="grep -E " || EGREP="egrep"

# enable aliase if running in bash
#
if [ "${BASH_VERSION}"x != ""x ] ; then
  shopt -s expand_aliases
fi

# read the template version from the source file
#
__TEMPLATE_VERSION="$(  grep "^#T#" $0 | grep " v[0-9]" | tail -1 | awk '{ print $3};' )"
: ${__TEMPLATE_VERSION:=can not find the template version -- please check the source code of $0}

# read the script version from the source file
#
SCRIPT_VERSION="$( grep "^#V#" $0 | grep " v[0-9]" | tail -1 | awk '{ print $3};' )"
: ${SCRIPT_VERSION:=can not find the script version -- please check the source code of $0}

# hardcoded script / template versions (not used anymore)
#

# __TEMPLATE_VERSION="3.0.0"

# SCRIPT_VERSION="1.0.0"


# USAGE_HELP contains additional text that is written by the script if 
# executed with the parameter -h
#
USAGE_HELP=""

# enviroment variables used by the script
#
# format:
# name # type # comment
#
# type and comment are optional
#
ENV_VARIABLES="#
PREFIX                     # string   # prefix used in dry-run-mode
__DEBUG_CODE               # string   # debug code for the functions
__TEE_OUTPUT_FILE          # filename # log file used for  --tee
USE_ONLY_KSH88_FEATURES    # boolean  #
DISABLE_TTY_CHECK          # boolean  # paramaeter disable_tty_check
BREAK_ALLOWED              # string   # 0 / 1 / DebugShell
EDITOR                     # filename # editor to use
PAGER                      # filename # pager to use
LOGFILE                    # filename # log file
NO_OF_LOGFILES_TO_KEEP     # integer  # number of log files to keep
NOHUP_STDOUT_STDERR_FILE   # filename # log file used in the function switch_to_background
#
FORCE                      # boolean  # parameter --force
QUIET                      # boolean  # parameter --quiet
VERBOSE                    # boolean  # parameter --verbose
VERBOSE_LEVEL              # boolean  # 
OVERWRITE                  # boolean  # parameter --overwrite
#

${ADDITIONAL_ENV_VARIABLES}
"


# save the shell options
#
__SHELL_OPTIONS="$-"

# check if we're running with "set -x"
#
if [[  ${__SHELL_OPTIONS} == *x* ]] ; then
#
# tracing is already enabled 
#
  __TRACE=${__TRUE}
else
  __TRACE=${__FALSE}
fi  

# dryrun mode disabled?
# To enable dryrun mode set DRYRUN_MODE_DISABLED to ${__FALSE}
#
# dryrun mode only works if you prefix all commands that change something whith ${PREFIX}!
#
DRYRUN_MODE_DISABLED=${__TRUE}
#DRYRUN_MODE_DISABLED=${__FALSE}

# dryrun prefix (parameter -d)   
#
DEFAULT_DRYRUN_PREFIX="echo "

# : ${PREFIX:=${DEFAULT_DRYRUN_PREFIX} }
: ${PREFIX:=}

# procecss all variables beginning with "__DEFAULT_" if this variable is ${__TRUE}
#
SET_DEFAULT_VALUES=${__FALSE}

# allow parameter "var=value" if this variable is ${__TRUE}
#
VAR_VALUE_PARAMETER_ENABLED=${__FALSE}

# DebugShell will do nothing, and the parameter -D and --var are not usable if ENABLE_DEBUG is ${__FALSE} 
#
ENABLE_DEBUG=${__TRUE}
#ENABLE_DEBUG=${__FALSE}

# variable for debugging
#
# use "eval ... >&2" for your debug code and use STDERR for all output!
#
# e.g. 
#
#   __DEBUG_CODE="eval echo \*\*\*  Starting the function \$0, parameter are: \'\$*\'>&2" ./scriptt_mini.sh
#
if [ ${ENABLE_DEBUG} = ${__TRUE} ] ; then
: ${__DEBUG_CODE:=}
else
  __DEBUG_CODE=""
fi
__USER_DEBUG_CODE="${__DEBUG_CODE}"


[[ "${__USER_DEBUG_CODE}" != *\;[[:space:]]* ]] &&__USER_DEBUG_CODE="${__USER_DEBUG_CODE} ;"

__CODE_TO_ENABLE_VERBOSE_MODE=""

# list of functions with enabled debug code
#
__FUNCTIONS_WITH_DEBUG_CODE=""

# list of functions with enabled verbose mode
#
__FUNCTIONS_IN_VERBOSE_MODE=""

# list of saved functions
#
__LIST_OF_SAVED_FUNCTIONS=""

# set this variable to ${__TRUE} to change the default to "tty check is disabled"
#

DISABLE_TTY_CHECK=${DISABLE_TTY_CHECK:=${__FALSE}}

RUNNING_IN_TERMINAL_SESSION=${__TRUE}

# check tty
#
if [ ${DISABLE_TTY_CHECK} = ${__FALSE} ] ; then
  tty -s && RUNNING_IN_TERMINAL_SESSION=${__TRUE} || RUNNING_IN_TERMINAL_SESSION=${__FALSE}
fi


# disable the tty check if the parameter --disable_tty_check is used
#
# Note: The parameter ++disable_tty_check is not supported
#
if [[  \ $*\  == *\ --disable_tty_check\ * ]] ; then
  RUNNING_IN_TERMINAL_SESSION=${__TRUE}
  DISABLE_TTY_CHECK=${__TRUE}
fi

# file for STDOUT and STDERR if the parameter -t/--tee is used
#
: ${__TEE_OUTPUT_FILE:=${TMPDIR}/${0##*/}.$$.tee.log}

# -----------------------------------------------------------------------------
# use the parameter -T or --tee to automatically call the script and pipe
# all output into a file using tee

if [ "${__PPID}"x = ""x ] ; then
  __PPID=$PPID ; export __PPID  
  if [[ \ $*\  == *\ -T* || \ $*\  == *\ --tee\ * ]] ; then
    echo "Saving STDOUT and STDERR to \"${__TEE_OUTPUT_FILE}\" ..." 
    exec  $0 $@ 2>&1 | tee -a "${__TEE_OUTPUT_FILE}"
    __MAINRC=$?
    echo "STDOUT and STDERR saved in \"${__TEE_OUTPUT_FILE}\"." 
    exit ${__MAINRC}
  fi
fi

: ${__PPID:=$PPID} ; export __PPID


# -----------------------------------------------------------------------------
# check for the parameter -q / --quiet
#
if [[ \ $*\  == *\ -q* || \ $*\  == *\ --quiet\ * ]] ; then
  QUIET=${__TRUE}
fi
  
# -----------------------------------------------------------------------------
#### __KSH_VERSION - ksh version (either 88 or 93)
####   If the script is not executed by ksh the shell is compatible to
###    ksh version ${__KSH_VERSION}
####
__KSH_VERSION=88 ; f() { typeset __KSH_VERSION=93 ; } ; f ;

# check if "typeset -f" is supported
#
typeset -f f | grep __KSH_VERSION >/dev/null && TYPESET_F_SUPPORTED="yes" || TYPESET_F_SUPPORTED="no"

unset -f f

# check if $0 in a function defined with "function f { ... }" is the function name
#
function f {
  echo $0
}

[ "$( f )"x = "f"x ] && TRACE_FEATURE_SUPPORTED="yes" || TRACE_FEATURE_SUPPORTED="no"

unset -f f

# use ksh93 features?
#
if [ "${__KSH_VERSION}"x = "93"x ] ; then
  USE_ONLY_KSH88_FEATURES=${USE_ONLY_KSH88_FEATURES:=${__FALSE}}
else
  USE_ONLY_KSH88_FEATURES=${USE_ONLY_KSH88_FEATURES:=${__TRUE}}
fi

# get the real KSH version
#
if [ "${KSH_VERSION}"x = ".sh.version"x ] ; then
  REAL_KSH_VERSION="${.sh.version}"
else  
  REAL_KSH_VERSION="${KSH_VERSION}"
fi

# alias to install the trap handler
#

# supported signals
#

#  Number   KSH name    Comments
#  0        EXIT        This number does not correspond to a real signal, but the corresponding trap is executed before script termination.
#  1        HUP         hangup
#  2        INT         The interrupt signal typically is generated using the DEL or the ^C key
#  3        QUIT        The quit signal is typically generated using the ^[ key. It is used like the INT signal but explicitly requests a core dump.
#  9        KILL        cannot be caught or ignored
#  10       BUS         bus error
#  11       SEGV        segmentation violation
#  13       PIPE        generated if there is a pipeline without reader to terminate the writing process(es)
#  15       TERM        generated to terminate the process gracefully
#  -        DEBUG       KSH93 only: This is no signal, but the corresponding trap code is executed before each statement of the script.
#
# signals in Solaris
#  16       USR1        user defined signal 1, this value is different in other Unix OS!
#  17       USR2        user defined signal 2, this value is different in other Unix OS!
#
#  24       SIGTSTP     stop a running process (like CTRL-Z)
#  25       SIGCONT     continue a stopped process in the background
#
# signals in Linux
#  16       USR1        user defined signal 1, this value is different in other Unix OS!
#  17       USR2        user defined signal 2, this value is different in other Unix OS!
#
#  20       SIGTSTP     stop a running process (like CTRL-Z)
#  18       SIGCONT     continue a stopped process in the background
#
# signals in AIX
#  30       USR1        user defined signal 1, this value is different in other Unix OS!
#  31       USR2        user defined signal 2, this value is different in other Unix OS!
#
#  18       SIGTSTP     stop a running process (like CTRL-Z)
#  19       SIGCONT     continue a stopped process in the background
#
# signals in MacOS (Darwin)
#  30       USR1        user defined signal 1, this value is different in other Unix OS!
#  31       USR2        user defined signal 2, this value is different in other Unix OS!
#
#  18       SIGTSTP     stop a running process (like CTRL-Z)
#  19       SIGCONT     continue a stopped process in the background
#
# 

#
# Note: The usage of the variable LINENO is different in the various ksh versions
#

alias __settraps="
  trap 'signal_hup_handler    \${LINENO}' 1 ;\
  trap 'signal_break_handler  \${LINENO}' 2 ;\
  trap 'signal_quit_handler   \${LINENO}' 3 ;\
  trap 'signal_exit_handler   \${LINENO}' 15 ;\
  trap 'signal_usr1_handler   \${LINENO}' USR1 ;\
  trap 'signal_usr2_handler   \${LINENO}' USR2  ;\
"


# alias to reset all traps to the defaults
#
alias __unsettraps="
  trap - 1 ;\
  trap - 2 ;\
  trap - 3 ;\
  trap - 15 ;\
  trap - USR1 ;\
  trap - USR2 ;\
"

__FUNCTION_INIT="eval __settraps"

# variables used for the logfile handling
#
# the log functions save all messages in the variable LOG_MESSAGE_CACHE until the logfile to use is known
#
LOGFILE_FOUND=${__FALSE}
LOG_MESSAGE_CACHE=""

# variables for the function create_lock_file
#
# these two variables are set by the function create_lock_file
#
WAIT_TIME_FOR_THE_LOCKFILE_IN_SECONDS="0"
PID_OF_PROCESS_HOLDING_THE_LOCKFILE=""

# default values for the parameter of the function create_lock_file
#
DEFAULT_LOCK_FILE="${TMPDIR}/${0##*/}_is_running"
DEFAULT_LOCK_FILE_WAIT_TIME=120
DEFAULT_STEP_COUNT=10

# variables for the trap handler
#
# The INSIDE_* variables are set to ${__TRUE} while the handler is active and 
# then back to ${__FALSE} after the handler is done
#
INSIDE_DIE=${__FALSE}
INSIDE_DEBUG_SHELL=${__FALSE}
INSIDE_CLEANUP_ROUTINE=${__FALSE}
INSIDE_FINISH_ROUTINE=${__FALSE}
#
INSIDE_USR1_HANDLER=${__FALSE}
INSIDE_USR2_HANDLER=${__FALSE}
INSIDE_BREAK_HANDLER=${__FALSE}
INSIDE_HUP_HANDLER=${__FALSE}
INSIDE_EXIT_HANDLER=${__FALSE}
INSIDE_QUIT_HANDLER=${__FALSE}

# the variable DEBUG_SHELL_CALLED is set to TRUE everytime the function DebugShell is executed
#
DEBUG_SHELL_CALLED=${__FALSE}

# set the variable PRINT_COMMAND_TO_EXECUTE to ${__TRUE} to print all commands executed by the function
# executeCommandAndLog
#
PRINT_COMMAND_TO_EXECUTE=${__FALSE}

# set BREAK_ALLOWED to ${__FALSE} to disable CTRL-C, to ${__TRUE} to abort the script with CTRL-C
# and to "DebugShell" to call the DebugShell if the CTRL-C signal is catched
#
BREAK_ALLOWED="${BREAK_ALLOWED:=DebugShell}"
# BREAK_ALLOWED=${__FALSE}
# BREAK_ALLOWED=${__TRUE}

# current hostname
#
CUR_HOST="$( hostname )"
CUR_SHORT_HOST="${CUR_HOST%%.*}"

CUR_OS="$( uname -s )"

CUR_OS_VERSION="$( uname -r )"

# script name and directory
#
typeset -r SCRIPTNAME="${0##*/}"
typeset SCRIPTDIR="${0%/*}"
if [ "${SCRIPTNAME}"x = "${SCRIPTDIR}"x ] ; then
  SCRIPTDIR="$( whence ${SCRIPTNAME} )"
  SCRIPTDIR="${SCRIPTDIR%/*}"
fi  
REAL_SCRIPTDIR="$( cd -P ${SCRIPTDIR} ; pwd )"
REAL_SCRIPTNAME="${REAL_SCRIPTDIR}/${SCRIPTNAME}"

CUR_SHELL="$( head -1 "${REAL_SCRIPTNAME}" | cut -f1 -d " " | cut -c3- )"

WORKING_DIR="$( pwd )"

LOGDIR="${TMPDIR}"

if [ "${LOGDIR}"x != ""x ] ; then
  DEFAULT_LOGFILE="${LOGDIR}/${SCRIPTNAME}.log"
else
  DEFAULT_LOGFILE=""
fi

LOGFILE="${LOGFILE:=${DEFAULT_LOGFILE}}"

#
# number of  old logfiles to keep
#
NO_OF_LOGFILES_TO_KEEP=${NO_OF_LOGFILES_TO_KEEP:=10}

# use either vim, vi or nano as editor if no default editor is set
#
: ${EDITOR:=$( which vim 2>/dev/null )}
: ${EDITOR:=$( which vi 2>/dev/null )}
: ${EDITOR:=$( which nano 2>/dev/null )}

# use less or more as pager if no default pager is set
#
: ${PAGER:=$( which less 2>/dev/null )}
: ${PAGER:=$( which more 2>/dev/null )}

SYSTEMD_IS_USED=${__FALSE}

READLINK=""

#
# if either STDIN, STDOUT, or STDERR goes to a real tty
# device this variable will be true
#
# So this is not really a bullet proof solution!
#
RUNNING_IN_A_CONSOLE_SESSION="unknown"

STDOUT_IS_A_PIPE="unknown"
STDIN_IS_A_PIPE="unknown"

[ -t 0 ] &&  STDIN_IS_TTY=${__TRUE} ||  STDIN_IS_TTY=${__FALSE}
[ -t 1 ] && STDOUT_IS_TTY=${__TRUE} || STDOUT_IS_TTY=${__FALSE}
[ -t 2 ] && STDERR_IS_TTY=${__TRUE} || STDERR_IS_TTY=${__FALSE}
 
STDIN_DEVICE="unknown"
STDOUT_DEVICE="unknown"
STDERR_DEVICE="unknown"

PARENT_PROCECSS_EXECUTABLE=""

TMPFILE1="${TMPDIR}/${SCRIPTNAME}.1.$$"
TMPFILE2="${TMPDIR}/${SCRIPTNAME}.2.$$"

case "${CUR_OS}" in

  CYGWIN* )
    set +o noclobber

# Note: The variable __SHELL_FIELD is not used anymore
    __SHELL_FIELD=9
    AWK="awk"
    ;;

  Linux )
# Note: The variable __SHELL_FIELD is not used anymore
    __SHELL_FIELD=8  
    ID="id"
    AWK="awk"
    TAR="tar"
    SED="sed"
    ps -p 1 | grep systemd >/dev/null && SYSTEMD_IS_USED=${__TRUE} || SYSTEMD_IS_USED=${__FALSE}

    READLINK="$( which readlink 2>/dev/null )"

    [ -p /proc/$$/fd/1 ] && STDOUT_IS_A_PIPE=${__TRUE} || STDOUT_IS_A_PIPE=${__FALSE}
    [ -p /proc/$$/fd/0 ] &&  STDIN_IS_A_PIPE=${__TRUE} ||  STDIN_IS_A_PIPE=${__FALSE}


#
# a workaround is neccessary to get the device/file used for STDOUT and STDIN in some circumstances
#        
    echo "( ls -l /proc/$$/fd/0 2>/dev/null || echo unknown  ; ls -l /proc/$$/fd/1 2>/dev/null || echo unknown ) >${TMPFILE1}"  >"${TMPFILE2}"
    if [ $? -eq 0 ] ; then
      chmod 755 "${TMPFILE2}"
      ksh -c "${TMPFILE2}" 2>/dev/null
      if [ $? -eq 0 -a -r "${TMPFILE1}" ] ; then
        STDIN_DEVICE="$(  head -1 "${TMPFILE1}" 2>/dev/null | awk '{ print $NF }' )"
        STDOUT_DEVICE="$( tail -1 "${TMPFILE1}" 2>/dev/null | awk '{ print $NF }' )"
      fi      
      \rm -f "${TMPFILE1}" "${TMPFILE2}"  2>/dev/null
    fi

    STDERR_DEVICE="$( ls -l /proc/$$/fd/2 | awk '{ print $NF }' )"
    
    [[ ${STDIN_DEVICE} == /dev/tty* ]] &&  RUNNING_IN_A_CONSOLE_SESSION=${__TRUE} ||  RUNNING_IN_A_CONSOLE_SESSION=${__FALSE}

    [[ ${STDIN_DEVICE} == /dev/pts/* || ${STDIN_DEVICE} == /dev/tty* ]] &&  STDIN_IS_TTY=${__TRUE} ||  STDIN_IS_TTY=${__FALSE}
    
    [[ ${STDOUT_DEVICE} == /dev/pts/* || ${STDOUT_DEVICE} == /dev/tty* ]] && STDOUT_IS_TTY=${__TRUE} || STDOUT_IS_TTY=${__FALSE}
    [[ ${STDOUT_DEVICE} == /dev/tty* ]] &&  RUNNING_IN_A_CONSOLE_SESSION=${__TRUE} 

    [[ ${STDERR_DEVICE} == /dev/pts/* || ${STDERR_DEVICE} == /dev/tty* ]] && STDERR_IS_TTY=${__TRUE} || STDERR_IS_TTY=${__FALSE}
    [[ ${STDERR_DEVICE} == /dev/tty* ]] &&  RUNNING_IN_A_CONSOLE_SESSION=${__TRUE} 

    PARENT_PROCECSS_EXECUTABLE="$( readlink -f /proc/$(ps -o ppid:1= -p $$)/exe )"
    ;;
      
  SunOS )
# Note: The variable __SHELL_FIELD is not used anymore
    __SHELL_FIELD=9
    if [ "${CUR_OS_VERSION}"x != "5.11"x ] ; then
      AWK="nawk"
     
      ID="/usr/xpg4/bin/id"

      SED="$( whence gsed )"
      [ "${SED}"x = ""x -a -x "/opt/csw/bin/gsed" ] && SED="/opt/csw/bin/gsed"
      [ "${SED}"x = ""x -a -x "/usr/xpg4/bin/sed" ] && SED="/usr/xpg4/bin/sed"
      [ "${SED}"x = ""x ] && SED="$( whence sed )"

      TAR="$( whence gsed )"
      [ "${TAR}"x = ""x -a -x "/opt/csw/bin/gtar" ] && TAR="/opt/csw/bin/gtar"
      [ "${TAR}"x = ""x -a -x "/usr/sfw/bin/gtar" ] && TAR="/usr/sfw/bin/gtar"
      [ "${TAR}"x = ""x -a -x "/usr/xpg4/bin/star" ] && TAR="/usr/xpg4/bin/gtar"
      [ "${TAR}"x = ""x ] && TAR="$( whence tar )"
      
    else
      ID="id"
      AWK="awk"
      TAR="tar"
      SED="sed"
    fi
 
    READLINK="$( whence readlink )" || \
      [ -x /opt/csw/gnu/readlink ] && READLINK="/opt/csw/gnu/readlink"

    RUNNING_IN_A_CONSOLE_SESSION=${__FALSE} 

    [ -p /proc/$$/fd/1 ] && STDOUT_IS_A_PIPE=${__TRUE} || STDOUT_IS_A_PIPE=${__FALSE}
    [ -p /proc/$$/fd/0 ]  && STDIN_IS_A_PIPE=${__TRUE}  || STDIN_IS_A_PIPE=${__FALSE}

    CUR_MAJOR_DEV="$( ls -ld /proc/$$/fd/0 | awk '{ print $5 }' )"    
    [ "${CUR_MAJOR_DEV}"x = "0,"x ] && RUNNING_IN_A_CONSOLE_SESSION=${__TRUE} 

    CUR_MAJOR_DEV="$( ls -ld /proc/$$/fd/1 | awk '{ print $5 }' )"    
    [ "${CUR_MAJOR_DEV}"x = "0,"x ] && RUNNING_IN_A_CONSOLE_SESSION=${__TRUE} 
 
    CUR_MAJOR_DEV="$( ls -ld /proc/$$/fd/2 | awk '{ print $5 }' )"    
    [ "${CUR_MAJOR_DEV}"x = "0,"x ] && RUNNING_IN_A_CONSOLE_SESSION=${__TRUE} 
    ;;

  AIX )
# Note: The variable __SHELL_FIELD is not used anymore
    __SHELL_FIELD=9
    AWK="awk"
    ID="id"
    TAR="tar" 
    SED="sed"
    ;;

  Darwin )
# Note: The variable __SHELL_FIELD is not used anymore
    __SHELL_FIELD=8
    AWK="awk"
    ID="id"
    TAR="tar"    
    SED="sed"
    ;;

  * )
# Note: The variable __SHELL_FIELD is not used anymore
    __SHELL_FIELD=8
    AWK="awk"
    ID="id"
    TAR="tar"    
    SED="sed"
    ;;

esac


#### __SHELL - name of the current shell executing this script
####

# old code:
# __SHELL="$( ps -f -p $$ | grep -v PID | tr -s " " | cut -f${__SHELL_FIELD} -d " " )"
#__SHELL="$( ps  -p $$ -o comm= | tail -1 )"

__SHELL="$( ps -f -p $( ps -f -p $$ -o ppid= ) -o comm= | tail -1 )"

__SHELL=${__SHELL##*/}

: ${__SHELL:=ksh}

CUR_USER_ID="$( ${ID} -u )"
CUR_USER_NAME="$( ${ID} -un )"

CUR_GROUP_ID="$( ${ID} -g )"
CUR_GROUP_NAME="$( ${ID} -gn )"

# parameter -f
#
: ${FORCE:=${__FALSE}}

# parameter -q
#
: ${QUIET:=${__FALSE}}

# parameter -v
#
: ${VERBOSE:=${__FALSE}}

# VERBOSE_LEVEL is increased by one for every -v found in the parameter
#
: ${VERBOSE_LEVEL:=0}

# parameter -o
#
: ${OVERWRITE:=${__FALSE}}


# parameter -L
#
LIST_FUNCTIONS_AND_EXIT=${__FALSE}

# parameter --nologrotate
#
ROTATE_LOG=${__TRUE}

# for Logrotating once each month for scripts running each day use
#
# [ $( date "+%d" ) = 1 ] && ROTATE_LOG=${__TRUE} || ROTATE_LOG=${__FALSE}

# for Logrotating once a week (1 = monday) for scripts running each day use
#
# [ $( date "+%u" ) = 1 ] && ROTATE_LOG=${__TRUE} || ROTATE_LOG=${__FALSE}

# parameter --nocleanup
#
NO_CLEANUP=${__FALSE}

# parameter --nobackups
#
NO_BACKUPS=${__FALSE}

# parameter --appendlog
#
APPEND_LOG=${__FALSE}

# parameter --noSTDOUTlog
#
LOG_STDOUT=${__TRUE}

# parameter -y and -n (used in the function AskUser)
#
# answer all questions with Yes (if "y") or No (if "n") else ask the user
#
__USER_RESPONSE_IS=""

# user input in the function AskUser
#
USER_INPUT=""
LAST_USER_INPUT=""

# do not print the user input in the function AskUser
#
__NOECHO=${__FALSE}

# use /dev/tty instead of STDIN and STDOUT in the function AskUser
#
__USE_TTY=${__FALSE}

# stty settings (used in die to reset the stty settings if neccessary)
#
__STTY_SETTINGS=""

# allow a debug shell in the function AskUser
#
__DEBUG_SHELL_IN_ASKUSER=${__TRUE}

# variables for the house keeping
#
# directories to remove at script end
#
DIRS_TO_REMOVE=""

# files to remove at script end
#
#FILES_TO_REMOVE=""
FILES_TO_REMOVE="${TMPFILE1} ${TMPFILE2}"

# processes to kill at script end
#
PROCS_TO_KILL=""

# timeout in seconds to wait after "kill" before issueing a "kill -9" for a 
# still running process, use -1 for the KILL_PROC_TIMEOUT to disable "kill -9"
#
KILL_PROC_TIMEOUT=0

# cleanup functions to execute at script end
# Use "function_name:parameter1[[...]:parameter#] to add parameter for a function
# blanks or tabs in the parameter are NOT allowed
#
CLEANUP_FUNCTIONS=""

# mount points to umount at script end
#
MOUNTS_TO_UMOUNT=""

# finish functions to execute at script end
# Use "function_name:parameter1[[...]:parameter#] to add parameter for a function
# blanks or tabs in the parameter are NOT allowed
#
FINISH_FUNCTIONS=""

# ----------------------------------------------------------------------
# variable for print_runtime_variables
#
# format:
#
#  #msg  - message to print (replacing "_" with " "; 
#          do NOT use blanks in the lines starting with #)
#  else  - variablename, print the name and value
#
RUNTIME_VARIABLES="
#
#constants
__TRUE
__FALSE
#
#signal_handling:
BREAK_ALLOWED
INSIDE_DIE
INSIDE_DEBUG_SHELL
INSIDE_CLEANUP_ROUTINE
INSIDE_FINISH_ROUTINE
INSIDE_USR1_HANDLER
INSIDE_USR2_HANDLER
INSIDE_BREAK_HANDLER
INSIDE_HUP_HANDLER
INSIDE_EXIT_HANDLER
INSIDE_QUIT_HANDLER
DEBUG_SHELL_CALLED

#Parameter:
ALL_PARAMETER
NOT_USED_PARAMETER
FORCE
QUIET
VERBOSE
VERBOSE_LEVEL
OVERWRITE
USAGE_HELP
LIST_FUNCTIONS_AND_EXIT
APPEND_LOG
LOG_STDOUT
NO_BACKUPS
__USER_RESPONSE_IS
DISABLE_TTY_CHECK

#Hostname_variables:
CUR_HOST
CUR_SHORT_HOST
CUR_OS
CUR_OS_VERSION

#Scriptname_and_directory:
SCRIPTNAME
SCRIPTDIR
REAL_SCRIPTDIR
REAL_SCRIPTNAME

#Current_environment:
CUR_SHELL
EDITOR
PAGER
WORKING_DIR
LOGFILE
LOGFILE_FOUND
LOG_MESSAGE_CACHE
ROTATE_LOG
RUNNING_IN_TERMINAL_SESSION
__KSH_VERSION
USE_ONLY_KSH88_FEATURES
TYPESET_F_SUPPORTED
TRACE_FEATURE_SUPPORTED
AWK
ID
__PPID
NOHUP_STDOUT_STDERR_FILE
__SHELL
RUNNING_IN_A_CONSOLE_SESSION
SYSTEMD_IS_USED
STDERR_DEVICE
STDERR_IS_TTY
STDIN_DEVICE
STDIN_IS_A_PIPE
STDIN_IS_TTY
STDOUT_DEVICE
STDOUT_IS_A_PIPE
STDOUT_IS_TTY


#Hardware_related_variables
#
RUNNING_ON_A_VIRTUAL_MACHINE
HPYERVISOR_VENDOR
SYSTEM_PRODUCT_NAME
SYSTEM_PRODUCT_VENDOR

#Variables_for_the_function_AskUser:
USER_INPUT
LAST_USER_INPUT
__NOECHO
__USE_TTY
__STTY_SETTINGS
__DEBUG_SHELL_IN_ASKUSER
__USER_RESPONSE_IS

#User_and_group:
CUR_USER_ID
CUR_USER_NAME
CUR_GROUP_ID
CUR_GROUP_NAME

#Housekeeping:
CLEANUP_FUNCTIONS
FILES_TO_REMOVE
DIRS_TO_REMOVE
PROCS_TO_KILL
KILL_PROC_TIMEOUT
FINISH_FUNCTIONS
MOUNTS_TO_UMOUNT
NO_CLEANUP
NO_EXIT_ROUTINES
NO_TEMPFILES_DELETE
NO_TEMPDIR_DELETE
NO_FINISH_ROUTINES
NO_KILL_PROCS
NO_UMOUNT_MOUNTPOINTS

#Debugging
__DEBUG_CODE
__USER_DEBUG_CODE
__FUNCTION_INIT
DEFAULT_DRYRUN_PREFIX
PREFIX
ENABLE_DEBUG
__TEE_OUTPUT_FILE
__LIST_OF_SAVED_FUNCTIONS
FUNCTIONS_TO_TRACE
__FUNCTIONS_WITH_DEBUG_CODE
__FUNCTIONS_IN_VERBOSE_MODE
"


# ----------------------------------------------------------------------
# add variables for print_runtime_variables
#
# format:
#
#  #msg  - message to print (replacing "_" with " ")
#  else  - variablename, print the name and value
#
APPLICATION_VARIABLES="
"

# ----------------------------------------------------------------------

[ -r /sys/class/dmi/id/product_name ] && SYSTEM_PRODUCT_NAME="$( < /sys/class/dmi/id/product_name )" || SYSTEM_PRODUCT_NAME=""
[ -r /sys/class/dmi/id/sys_vendor ] && SYSTEM_PRODUCT_VENDOR="$( < /sys/class/dmi/id/sys_vendor )" || SYSTEM_PRODUCT_VENDOR=""

if [[ ${SYSTEM_PRODUCT_NAME} == VMware* || ${SYSTEM_PRODUCT_VENDOR} == VMware* ]] ; then

    HPYERVISOR_VENDOR="VMware"
    RUNNING_ON_A_VIRTUAL_MACHINE=${__TRUE}
    THIS_IS_A_VMWARE_MACHINE=${__TRUE}

elif [[ ${SYSTEM_PRODUCT_NAME} == VirtualBox* || ${SYSTEM_PRODUCT_VENDOR} == innotek* ]] ; then

    HPYERVISOR_VENDOR="VirtualBox"
    RUNNING_ON_A_VIRTUAL_MACHINE=${__TRUE}
    THIS_IS_A_VMWARE_MACHINE=${__FALSE}

elif [[ ${SYSTEM_PRODUCT_VENDOR} == QEMU* ]] ; then

    HPYERVISOR_VENDOR="qemu"
    RUNNING_ON_A_VIRTUAL_MACHINE=${__TRUE}
    THIS_IS_A_VMWARE_MACHINE=${__FALSE}

else
    HPYERVISOR_VENDOR=""
    RUNNING_ON_A_VIRTUAL_MACHINE=${__FALSE}
    THIS_IS_A_VMWARE_MACHINE=${__FALSE}
fi

# ----------------------------------------------------------------------
# internal functions
#

# ----------------------------------------------------------------------
# RotateLog
#
# create up to n backups of one or more files
#
# usage: RotateLog [file1 [... [file#]]]
#
# returns: ${__TRUE} - a new backup was created
#
# The number of log files to keep are read from the variable 
# CUR_NO_OF_LOGFILES_TO_KEEP
#
function RotateLog {
  typeset __FUNCTION="RotateLog"
  ${__DEBUG_CODE} 
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  typeset THIS_LOGFILES="${LOGFILE}"
  typeset THIS_LOGFILE=""
  typeset i=0
  typeset CUR_NO_OF_LOGFILES_TO_KEEP=10
  
  if ! isNumber ${NO_OF_LOGFILES_TO_KEEP} ; then
    LogError "The value of the variable \"NO_OF_LOGFILES_TO_KEEP\" is not numeric: \"${NO_OF_LOGFILES_TO_KEEP}\" - using the hardcoded value now (${CUR_NO_OF_LOGFILES_TO_KEEP}) "
  else
    CUR_NO_OF_LOGFILES_TO_KEEP=${NO_OF_LOGFILES_TO_KEEP}  
  fi
  
  [ $# -ne 0 ] && THIS_LOGFILES="$*"
  if [ "${THIS_LOGFILES}"x != ""x ] ; then
    i=${CUR_NO_OF_LOGFILES_TO_KEEP}

    for THIS_LOGFILE in "${THIS_LOGFILES}" ; do

      (( i = i - 1 ))
      while [ $i -ge 0 ] ; do
       (( i = i - 1 ))
    
        if [ -r "${THIS_LOGFILE}.${i}" ] ; then
          \mv -f "${THIS_LOGFILE}.${i}" "${THIS_LOGFILE}.$(( i + 1 ))" || THISRC=${__FALSE}
        fi
      done
      if [ -r "${THIS_LOGFILE}" ] ; then
        \mv -f "${THIS_LOGFILE}" "${THIS_LOGFILE}.0"  || THISRC=${__FALSE}
      fi
    done
  fi

  return ${THISRC}
}


# ----------------------------------------------------------------------
# general functions
#


# ----------------------------------------------------------------------
# LogMsg
#
# write a message to STDOUT without trailing LF and to the log file if the variable QUIET is not ${__TRUE}
#
# usage: LogMsg [-] [.] [msg1] [...] [msg#]
#
#  "-"  -> do not print the message prefix
#  "."  -> do not print an LF
#
# returns: ${__TRUE} - the message was written
#
# notes:
#
# - the messages will be stored in the variable LOG_MESSAGE_CACHE until the log file name is fixed
# - LogMsg calls the function RotateLog if neccessary
#
function LogMsg {
  typeset __FUNCTION="LogMsg"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}
  
  [[ ${QUIET} = ${__TRUE} ]] && return ${__FALSE}

  typeset THISMSG=""
  typeset TEMPVAR="${LOGFILE}"

  typeset MESSAGE_PREFIX=""
  typeset LOG_COMMAND="echo"


  if [ ${LOGFILE_FOUND}x = ${__TRUE}x -a "${LOGFILE}"x != ""x ] ; then 
    if [ ${ROTATE_LOG}x = ${__TRUE}x  ] ; then
      ROTATE_LOG=${__FALSE}
      RotateLog 
      if [ $? -ne 0 ] ; then
        LOGFILE=""
        LogError "Existing logfile(s) are:"
        LogMsg "-" "$( ls -l "${TEMPVAR}"* )"
        die 253 "Can not create backups of the log files"
      fi
    fi
    if [ ${APPEND_LOG}x = ${__FALSE}x ] ; then
      echo >"${LOGFILE}"
      APPEND_LOG=${__TRUE}
    fi
  fi
 
  if [ "$1"x = "-"x ] ; then
    shift
    MESSAGE_PREFIX=""
  else
    MESSAGE_PREFIX="[$( date +"%d.%m.%Y %H:%M" )] "
  fi

  if [ "$1"x = "."x ] ; then
    shift
    LOG_COMMAND="printf"
  else
    LOG_COMMAND="echo"
  fi
  
  THISMSG="${MESSAGE_PREFIX}$*"

  ${LOG_COMMAND} "${THISMSG}"  

# make sure all messages go to the correct log file if the parameter -l is used
#
  if [ "${LOGFILE}"x != ""x ] ; then
    if [ ${LOGFILE_FOUND}x = ${__TRUE}x ] ; then
      if [ "${LOG_MESSAGE_CACHE}"x != ""x ] ; then
        echo "${LOG_MESSAGE_CACHE}" >>"${LOGFILE}"
        LOG_MESSAGE_CACHE=""
      fi  
      [ "${LOGFILE}"x != ""x ] && ${LOG_COMMAND} "${THISMSG}" >>"${LOGFILE}"
    else
      LOG_MESSAGE_CACHE="${LOG_MESSAGE_CACHE}
${THISMSG}"
    fi
  fi
}



# ----------------------------------------------------------------------
# LogOnly
#
# write a message only to the log file if the variable QUIET is not ${__TRUE}
#
# usage: LogOnly [msg1] [...] [msg#]
#
# returns: ${__TRUE} - the message was written
#
# note: the message is written using the function LogMsg
#
function LogOnly {
  typeset __FUNCTION="LogOnly"    
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  LogMsg "$*" >/dev/null  

  return $?
}

# ----------------------------------------------------------------------
# LogInfo
#
# write an INFO: message to STDERR and the logfile if the variable VERBOSE is ${__TRUE}
# and if the variable QUIET is not ${__TRUE}
#
# usage: LogInfo [msg1] [...] [msg#]
#
# returns: ${__TRUE} - the message was written
#
# note: the message is written using the function LogMsg
#
function LogInfo {
  typeset __FUNCTION="LogInfo"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__FALSE}
  
  if [ ${VERBOSE} = ${__TRUE} ] ; then
    if [ "$1"x = "-"x ] ; then    
      shift
      LogMsg "-" "INFO: $*" >&2
      THISRC=$?
    else
      LogMsg "INFO: $*" >&2
      THISRC=$?
    fi
  fi

  return ${THISRC}
}

# ----------------------------------------------------------------------
# LogMoreInfo
#
# write an INFO: message to STDERR and the logfile if the variable VERBOSE is ${__TRUE}
# and if the variable QUIET is not ${__TRUE}
#
# usage: LogMoreInfo {loglevel} [msg1] [...] [msg#]
#
# returns: ${__TRUE} - the message was written
#
# default for "loglevel" is "1" (-> print the message if the parameter -v is used at least two times)
#
# note: the message is written using the function LogMsg
#
function LogMoreInfo {
  typeset __FUNCTION="LogMoreInfo"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset CUR_LEVEL=""
  
  if [[ $1 == [0-9]* ]] ; then
    CUR_LEVEL="$1"
    shift
  else
    CUR_LEVEL="1"
  fi
    
  [ ${VERBOSE_LEVEL} -gt ${CUR_LEVEL} ] && LogMsg "INFO: $*" >&2

  return $?
}


# ----------------------------------------------------------------------
# LogRuntimeInfo
#
# internal sub routine for info messages from the runtime system
#
# returns: ${__TRUE} - message printed
#          ${__FALSE} - message not printed
#
function LogRuntimeInfo {
  typeset __FUNCTION="LogRuntimeInfo"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__FALSE}

  if [ ${VERBOSE_LEVEL} -gt 1 ] ; then
    LogInfo "$*"
    THISRC=$?
  fi

  return ${THISRC}
}

# ----------------------------------------------------------------------
# LogError
#
# write an ERROR: message to STDERR and the logfile if the variable QUIET is not ${__TRUE}
#
# usage: LogError [msg1] [...] [msg#]
#
# returns: ${__TRUE} - the message was written
#
# note: the message is written using the function LogMsg
#
function LogError {
  typeset __FUNCTION="LogError"    
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  if [ "$1"x = "-"x ] ; then    
    shift
    LogMsg "-" "ERROR: $*" >&2
    THISRC=$?
  else
    LogMsg "ERROR: $*" >&2
    THISRC=$?
  fi
  
  return ${THISRC}
}

# ----------------------------------------------------------------------
# LogWarning
#
# write an WARNING: message to STDOUT and the logfile if the variable QUIET is not ${__TRUE}
#
# usage: LogWarning [msg1] [...] [msg#]
#
# returns: ${__TRUE} - the message was written
#
# note: the message is written using the function LogMsg
#
function LogWarning  {
  typeset __FUNCTION="LogWarning"    
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  if [ "$1"x = "-"x ] ; then    
    shift
    LogMsg "-" "WARNING: $*" >&2
    THISRC=$?
  else
    LogMsg "WARNING: $*" >&2
    THISRC=$?
  fi
  
  return ${THISRC}
}

# ----------------------------------------------------------------------
# LogInfoVar -- alias to print the name and value of a variable
#
alias LogInfoVar='f() { varname="$1"; eval "LogInfo \"\$varname ist \${$varname}\""; unset -f f; } ; f'

# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
# __activate_logfile
#
# activate the logfile 
# set the semaphor for LogMsg to flush all messages to the logfile
#
# usage: __activate_logfile
#
# returns: ${__TRUE} - logfile activated
#          ${__FALSE} - error creating the log file
#
function __activate_logfile  {
  typeset __FUNCTION="__activate_logfile"    
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  typeset OLOGFILE=""
  typeset TEMPVAR=""

#
# check for "-l :n"
#
  [[ ${LOGFILE} == :* ]] && LOGFILE="${DEFAULT_LOGFILE}${LOGFILE}" && LogInfo "The expanded value for the parameter \"-l\" is  \"${LOGFILE}\""
  [[ ${LOGFILE} == default:* ]] && LOGFILE="${DEFAULT_LOGFILE}:${LOGFILE##*:}" && LogInfo "The expanded value for the parameter \"-l\" is  \"${LOGFILE}\""
  
  if [ "${LOGFILE}"x != ""x  ] ; then
#
# check for "-l filename:n"
#    
    TEMPVAR="${LOGFILE##*:}"
    LOGFILE="${LOGFILE%:*}"
    if [ "${LOGFILE}"x != "${TEMPVAR}"x ] ; then
      if isNumber ${TEMPVAR} ; then
        LogInfo "The number of log files to keep found in the parameter is ${TEMPVAR}"
        LogInfo "The logfile found in the  parameter is \"${LOGFILE}\" "
        NO_OF_LOGFILES_TO_KEEP=${TEMPVAR}
      else
        LogError "The value for the number of logfiles to keep in the parameter \"${TEMPVAR}\" is not a number"
      fi
    fi
    
    LogMsg "### The logfile used is ${LOGFILE}"

    if [ ${LOGFILE_PARAMETER_FOUND} = ${__TRUE} ] ; then
      LOGDIR="$( cd $( dirname "${LOGFILE}" ) ; pwd )"
      LOGFILE="${LOGDIR}/$( basename "${LOGFILE}" )"
    fi

    LOGFILE_FOUND=${__TRUE}
  
    OLOGFILE="${LOGFILE}"
    touch "${LOGFILE}" 2>/dev/null >/dev/null 
    if [ $? -ne 0 ] ; then
      OLOGFILE="${LOGFILE}"
      LOGFILE="${LOGFILE}.$$"
      LogError "Can not write to the file ${OLOGFILE} - now using the log file ${LOGFILE}"
      THISRC=${__FALSE}
    else
      [ ! -s "${LOGFILE}" ] && \rm "${LOGFILE}"
    fi
  fi
  
  return ${THISRC}
}

# ----------------------------------------------------------------------
# curtimestamp
#
# write the current date and time to STDOUT in a format that can be 
# used for filenames
#
# usage: curtimestamp
#
# returns: nothing
#
function curtimestamp {
  typeset __FUNCTION="curtimestamp"    
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  date "+%Y.%m.%d.%H_%M_%S_%s" 

  return $?
}
  
# ----------------------------------------------------------------------
# executeCommandAndLog
#
# execute a command and write STDERR and STDOUT also to the logfile
#
# usage: executeCommandAndLog command parameter
#
# returns: the RC of the executed command (even if a logfile is used!)
#
function executeCommandAndLog {
  typeset __FUNCTION="executeCommandAndLog"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  set +e
  typeset THISRC=0

  if [ ${RUNNING_IN_ANDROID}x = ${__TRUE}x ] ; then
    die 206 "The function \"${__FUNCTION}\" is not supported in Android"
  fi

  if [ ${PRINT_COMMAND_TO_EXECUTE}x  = ${__TRUE}x ] ;  then
    LogMsg "### Executing \"$@\" "
  else
    LogInfo "### Executing \"$@\" " || LogOnly "### Executing \"$@\" "
  fi
  
  if [ "${LOGFILE}"x != ""x -a -f "${LOGFILE}" ] ; then
    # The following trick is from
    # http://www.unix.com/unix-dummies-questions-answers/13018-exit-status-command-pipe-line.html#post47559
    exec 5>&1
    tee -a "${LOGFILE}" >&5 |&
    exec >&p
    eval "$*" 2>&1
    THISRC=$?
    exec >&- >&5
    wait

    LogInfo "### The RC is ${THISRC}" || LogOnly  "### The RC is ${THISRC}"

  else
    eval "$@"
    THISRC=$?
  fi

  return ${THISRC}
}


#### --------------------------------------
#### KillProcess
####
#### Kill one or more processes
####
#### usage: KillProcess pid [...pid]
####
#### returns: ${__TRUE} -- all processes killed
####          ${__FALSE} -- at least one process not killed
#### 
#### notes:
####  The format for pid is "pid[:timeout_in_seconds]"
####
####  timeout_in_seconds is the time to wait after kill before a "kill -9"
####  is issued if the process is still running; use "pid:-1" to disable
####  the "kill -9" for a process
####  Default timeout for all PIDs is KILL_PROC_TIMEOUT
####
function KillProcess {
  typeset __FUNCTION="KillProcess"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}
  
  typeset THISRC=${__TRUE}
  
  typeset CUR_PID=""
  typeset CUR_KILL_PROC_TIMEOUT=""
  typeset PROCS_TO_KILL="$*"
  
  for CUR_PID in ${PROCS_TO_KILL} ; do

    if [[ ${CUR_PID} == *:* ]] ; then
      CUR_KILL_PROC_TIMEOUT="${CUR_PID#*:}"
      CUR_PID="${CUR_PID%:*}"
    else
      CUR_KILL_PROC_TIMEOUT="${KILL_PROC_TIMEOUT}"
    fi
  
    LogRuntimeInfo "Killing the process ${CUR_PID} (Timeout is ${CUR_KILL_PROC_TIMEOUT} seconds) ..."
    ps -p ${CUR_PID} >/dev/null
    if [ $? -eq 0 ] ; then
      LogRuntimeInfo "$( ps -fp ${CUR_PID} ) "
      kill ${CUR_PID}
      if [  ${CUR_KILL_PROC_TIMEOUT} != -1 ] ; then
        if [  ${CUR_KILL_PROC_TIMEOUT} != 0 ] ; then
          LogRuntimeInfo "Waiting up to ${CUR_KILL_PROC_TIMEOUT} second(s) ..."
          i=0
          while [ $i -lt ${CUR_KILL_PROC_TIMEOUT} ] ; do
            sleep 1
            ps -p ${CUR_PID} 2>/dev/null >/dev/null || break
            (( i = i + 1 ))
          done
        fi
        
        ps -p ${CUR_PID} 2>/dev/null >/dev/null
        if [ $? -eq 0 ] ; then
          LogRuntimeInfo "Process ${CUR_PID} is still alive after kill - now using \"kill -9\" ..."
          kill -9 ${CUR_PID}
          ps -p ${CUR_PID} 2>/dev/null >/dev/null
          if [ $? -eq 0 ] ; then
            LogError "The process ${CUR_PID} is still alive after \"kill -9\" "
            THISRC=${__FALSE}
          else
            LogRuntimeInfo "Process ${CUR_PID} killed with \"kill -9\" "                  
          fi
        else
          LogRuntimeInfo "Process ${CUR_PID} killed"
        fi
      else
#
# kill -9 is disabled for this PID
#
        ps -p ${CUR_PID} 2>/dev/null >/dev/null
        if [ $? -eq 0 ] ; then
          LogRuntimeInfo "Process \"${CUR_PID}\" is still alive after kill (\"kill -9\" is disabled)."
          THISRC=${__FALSE}       
        else
          LogRuntimeInfo "Process \"${CUR_PID}\" killed"
        fi
      fi
    else
      LogRuntimeInfo "Process ${CUR_PID} is not runninng"
    fi
  done

  return ${THISRC}
}

# ---------------------------------------
# BackupFile
#
# create a backup of a file if it exists
#
# usage: BackupFile sourcefile [backupfile] [backupfile_extension]
#
# returns:  ${__TRUE} - backup created or original file does not exist
#           ${__FALSE} - error creating the backup
#
# Note: No backup will be created if the varaible ${NO_BACKUPS} is ${__TRUE}
#
function BackupFile {
  typeset __FUNCTION="BackupFile"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}
      
  typeset THISRC=${__TRUE}

  typeset CUR_TIME="$( date +%Y.%m.%d-%H:%M:%S.%s )"
  typeset BACKUP_FILE=""
  typeset BACKUP_EXT=""
  typeset CUR_OUTPUT=""
  
  if [ ${NO_BACKUPS} -eq ${__TRUE} ] ; then
    LogInfo "Backups are disabled via parameter \"--no-backup\" -- will not create a backup of the file \"$1\" "
  else
    if [ $# -eq 3 ] ; then
      BACKUP_EXT="$3"
      shift
    else
      BACKUP_EXT="$$.${CUR_TIME}"
    fi

    if [ $# -eq 2 ] ; then
      BACKUP_FILE="$2"
    else
      BACKUP_FILE="$1"
    fi
    
    if [ -f "$1" ] ; then
      LogMsg "Creating a backup of the file \"$1\" in \"${BACKUP_FILE}.${BACKUP_EXT}\" ..."
      CUR_OUTPUT="$( \cp -p "$1" "${BACKUP_FILE}.${BACKUP_EXT}" 2>&1 )" 
      if [ $? -ne 0 ] ; then 
        LogMsg "-" "${CUR_OUTPUT}"
        THISRC=${__FALSE}
      fi      
    fi
  fi
  return ${THISRC}
}
  

# ----------------------------------------------------------------------
# __evaluate_fn
#
# Evaluate the parameter fn of the various DebugShell aliase
#
# Usage: executed by DebugShell - do not call this function in your code!
#
# returns: write the evaluated string to STDOUT
#
function __evaluate_fn {

  typeset CUR_FN=""
  typeset THIS_FN=""
  typeset NEW_FN=""
  typeset REAL_FN=""
 
## for debugging only
#
#  "printf" "The parameter are: \"$*\" \n" >&2

  
  typeset DEFINED_FUNCTIONS=" $("typeset" +f ) "
  set -f
  
  for CUR_FN in $* ; do
    case ${CUR_FN} in 
      *\** | *\?* )
       for THIS_FN in ${DEFINED_FUNCTIONS} ; do
         [[ " ${THIS_FN} " == *\ ${CUR_FN}\ * ]] && NEW_FN="${NEW_FN} ${THIS_FN} "
       done
       ;;
      
      all )
        NEW_FN="${NEW_FN} ${DEFINED_FUNCTIONS} "
        ;;
        
      * )
        NEW_FN="${NEW_FN} ${CUR_FN} "
        ;;
    esac
  done

  for CUR_FN in  ${NEW_FN} ; do
    [[ ${REAL_FN} == *\ ${CUR_FN}\ * ]] && continue
    REAL_FN="${REAL_FN} ${CUR_FN}"
  done
  
  echo "${REAL_FN}"
}
  
# ----------------------------------------------------------------------
# __DebugShell
#
# Open a simple debug shell
#
# Usage: executed by DebugShell - do not call this function in your code!
#
# returns: ${__TRUE}
#
# Input is always read from /dev/tty; output always goes to /dev/tty
# so DebugShell is only allowed if STDIN is a tty.
#
function __DebugShell {
  typeset __FUNCTION="__DebugShell"

  [ ${ENABLE_DEBUG}x != ${__TRUE}x ] && return 0
  
  [ ${INSIDE_DEBUG_SHELL}x = ${__TRUE}x ] && return 0
  INSIDE_DEBUG_SHELL=${__TRUE}

  if [ ${RUNNING_IN_TERMINAL_SESSION} != ${__TRUE} ] ; then
    LogError "DebugShell can only be used in interactive sessions"
    INSIDE_DEBUG_SHELL=${__FALSE}
    return ${__FALSE}
  fi

  DEBUG_SHELL_CALLED=${__TRUE}

  __settraps
  
  "typeset" THISRC=${__TRUE}
  "typeset" CMD_PARAMETER=""
  "typeset" FUNCTION_LIST=""
  "typeset" CUR_STATEMENT=""
  "typeset" CUR_VALUE=""
  "typeset" ADD_CODE=""

  "typeset" FUNC_SAVE_VAR=""
  "typeset" FUNC_SAVE_CONTENT=""
  
  "typeset" USER_INPUT=""
  "typeset" USER_INPUT1=""
  "typeset" CUR_CMD=""
  "typeset" CUR_FUNCTION_CODE=""
  "typeset" HASHCODE1=""
  "typeset" HASHCODE2=""
  
  "typeset" __TMP__STTY_SETTINGS="$( stty -g )"
            
  "typeset" TMP_FILE1="${TMPDIR}/${SCRIPTNAME}.DebugShell.$$.1.tmp"
  "typeset" TMP_FILE2="${TMPDIR}/${SCRIPTNAME}.DebugShell.$$.2.tmp"
  FILES_TO_REMOVE="${FILES_TO_REMOVE} ${TMP_FILE1} ${TMP_FILE2}"
 
  [ -r "${TMP_FILE1}" ] && \rm "${TMP_FILE1}"
  [ -r "${TMP_FILE2}" ] && \rm "${TMP_FILE2}"
#  ${USER_INPUT%% *}
  
  stty echo
  while "true" ; do
    "printf" "\n ------------------------------------------------------------------------------- \n"
    "printf" "${SCRIPTNAME} - debug shell - enter a command to execute (\"exit\" to leave the shell; \"quit\" to end the script)\n"
    "printf" "Current environment: ksh version: ${__KSH_VERSION} | change function code supported: ${TYPESET_F_SUPPORTED} | tracing feature using \$0 supported: ${TRACE_FEATURE_SUPPORTED}\n"
    "printf" ">> "
    set -f
    "read" USER_INPUT
    set +f

    CMD_PARAMETER="${USER_INPUT#* }"
    [ "${CMD_PARAMETER}"x = "${USER_INPUT}"x ] && CMD_PARAMETER=""
    CUR_CMD="${USER_INPUT%% *}"

    case "${USER_INPUT}" in
    
      "help" )
         "printf" "
vars                      - print the runtime variable values

functions | funcs         - list all defined functions 
functions fn | funcs fn   - list functions matching the regex fn

func fn                   - view the source code for the function fn (supported by this shell: ${TYPESET_F_SUPPORTED})
savedfuncs                - list the saved functions (supported by this shell: ${TYPESET_F_SUPPORTED})
editfunc fn               - edit the source code for the function fn (supported by this shell: ${TYPESET_F_SUPPORTED})
savefunc fn               - save the source code of the function fn (supported by this shell: ${TYPESET_F_SUPPORTED})
viewsavedfunc fn          - view the source code of the saved function fn (supported by this shell: ${TYPESET_F_SUPPORTED})
restorefunc fn            - restore the source code of the function fn (supported by this shell: ${TYPESET_F_SUPPORTED})
clearsavedfunc fn         - delete the saved source code of the function fn (supported by this shell: ${TYPESET_F_SUPPORTED})

verbose                   - toggle the verbose switch (Current value: ${VERBOSE})

view_debug                - view the current trace settings 
clear_debug               - clear the tracing for all functions
set_debug fn              - enable tracing for the functions fn; use \"+fn\" to preserve existing settings
add_debug_code fn         - enable debug code for the functions fn (supported by this shell: ${TYPESET_F_SUPPORTED})

exit                      - exit the debug shell
quit                      - end the script using die
abort                     - abort the script using kill -9

!<code>                   - execute the instructions \"<code>\"
<code>                    - execute the instructions using \"eval <code>\"

Notes:

\"fn\" can be one or more function names or regex; use \"functions fn\" to test the value of \"fn\"

"        ;;

      "exit" )
        "break";
        ;;

      "quit" )
        INSIDE_DEBUG_SHELL=${__FALSE}
        die 254 "${SCRIPTNAME} aborted by the user"
        ;;

      "abort" )
        LogMsg "${SCRIPTNAME} aborted with \"kill -9\" by the user"
        INSIDE_DEBUG_SHELL=${__FALSE}
        "kill" -9 $$
        ;;

      "verbose" )
        [ ${VERBOSE} = ${__TRUE} ] && VERBOSE=${__FALSE} || VERBOSE=${__TRUE}
        "printf" "The verbose switch is now ${__TRUE_FALSE[${VERBOSE}]} \n"
        ;;

      "vars" | "variables" )
        print_runtime_variables 
        ;;

      "savedfuncs" )
         if [ "${TYPESET_F_SUPPORTED}"x != "yes"x ] ; then
           "printf" "\"typeset -f\" required for \"${CUR_CMD}\" is NOT supported by this shell\n"
           continue
         fi
         if [ "${__LIST_OF_SAVED_FUNCTIONS}"x = ""x ] ; then
            "printf" "There are no saved functions\n"
         else
            "printf"  "Saved functions are: \n${__LIST_OF_SAVED_FUNCTIONS} \n"
         fi
         continue
         ;;
      
      "savefunc "* | "saveFunc "* )
         if [ "${TYPESET_F_SUPPORTED}"x != "yes"x ] ; then
           "printf" "\"typeset -f\" required for \"${CUR_CMD}\" is NOT supported by this shell\n"
           continue
         fi
         FUNCTION_LIST="$( __evaluate_fn "${CMD_PARAMETER}" )"

         for CUR_VALUE in ${FUNCTION_LIST} ; do
         
           CUR_FUNCTION_CODE="$( "typeset" -f "${CUR_VALUE}" 2>/dev/null )"
           if [ $? -ne 0 ] ; then
             "printf" "The function ${CUR_VALUE} is not defined\n"
             continue
           fi
           
           FUNC_SAVE_VAR="__FUNCTION_${CUR_VALUE}"
           eval FUNC_SAVE_CONTENT="\$${FUNC_SAVE_VAR}"
           if [ "${FUNC_SAVE_CONTENT}"x != ""x ] ; then
             "printf" "The function ${CUR_VALUE} is already saved\n"
             continue
           fi

           "printf" "Saving the current code for the function ${CUR_VALUE} ...\n"
           eval ${FUNC_SAVE_VAR}="\${CUR_FUNCTION_CODE}"
           __LIST_OF_SAVED_FUNCTIONS="${__LIST_OF_SAVED_FUNCTIONS} ${CUR_VALUE} "
         done      
         ;;

      "restorefunc "* | "restfunc "* | "restFunc "* )
         if [ "${TYPESET_F_SUPPORTED}"x != "yes"x ] ; then
           "printf" "\"typeset -f\" required for \"${CUR_CMD}\" is NOT supported by this shell\n"
           continue
         fi

         FUNCTION_LIST="$( __evaluate_fn "${CMD_PARAMETER}" )"
         
         for CUR_VALUE in ${FUNCTION_LIST} ; do
           FUNC_SAVE_VAR="__FUNCTION_${CUR_VALUE}"
           eval FUNC_SAVE_CONTENT="\$${FUNC_SAVE_VAR}"
           if [ "${FUNC_SAVE_CONTENT}"x = ""x ] ; then
             "printf" "There is no saved code for the function ${CUR_VALUE}\n"
             continue
             continue
           fi

           "printf" "Restoring the code for the function ${CUR_VALUE} ...\n"

           "echo" "${FUNC_SAVE_CONTENT}" >"${TMP_FILE1}"
            eval . "${TMP_FILE1}"
         done
         ;;

      "viewsavedfunc "* | "viewsavedFunc "*)
         if [ "${TYPESET_F_SUPPORTED}"x != "yes"x ] ; then
           "printf" "\"typeset -f\" required for \"${CUR_CMD}\" is NOT supported by this shell\n"
           continue
         fi

         if [ "${PAGER}"x = ""x ] ; then
           "printf" "No valid editor found (set the variable PAGER before calling this script)\n"
           continue
         fi

         if [ ! -x "${PAGER}" ] ; then
           "printf" "${PAGER} not found or not executable (check the variable PAGER)\n"
           continue
         fi

         FUNCTION_LIST="$( __evaluate_fn "${CMD_PARAMETER}" )"
         
         for CUR_VALUE in ${FUNCTION_LIST} ; do
           FUNC_SAVE_VAR="__FUNCTION_${CUR_VALUE}"
           eval FUNC_SAVE_CONTENT="\$${FUNC_SAVE_VAR}"
           if [ "${FUNC_SAVE_CONTENT}"x = ""x ] ; then
             "printf" "There is no saved code for the function ${CUR_VALUE}\n"
             continue
           fi

           "printf" "Viewing the code for the saved function ${CUR_VALUE} ...\n"

           "echo" "${FUNC_SAVE_CONTENT}" >"${TMP_FILE1}"
           ${PAGER} "${TMP_FILE1}"
         done
         ;;

      "clearsavedfunc "* | "clearsavedFunc "* )
         if [ "${TYPESET_F_SUPPORTED}"x != "yes"x ] ; then
           "printf" "\"typeset -f\" required for \"${CUR_CMD}\" is NOT supported by this shell\n"
           continue
         fi

         FUNCTION_LIST="$( __evaluate_fn "${CMD_PARAMETER}" )"
         
         for CUR_VALUE in ${FUNCTION_LIST} ; do
           FUNC_SAVE_VAR="__FUNCTION_${CUR_VALUE}"
           eval FUNC_SAVE_CONTENT="\$${FUNC_SAVE_VAR}"
           if [ "${FUNC_SAVE_CONTENT}"x = ""x ] ; then
             "printf" "There is no saved code for the function ${CUR_VALUE}\n"
             continue
           fi
           "printf" "Deleting the saved code for the function ${CUR_VALUE} ...\n"
           __LIST_OF_SAVED_FUNCTIONS=" ${__LIST_OF_SAVED_FUNCTIONS% ${CUR_VALUE} *} ${__LIST_OF_SAVED_FUNCTIONS#* ${CUR_VALUE} }"
           unset FUNC_SAVE_VAR

         done           
         ;;


      "editfunc "* | "editFunc "* )
         if [ "${TYPESET_F_SUPPORTED}"x != "yes"x ] ; then
           "printf" "\"typeset -f\" required for \"${CUR_CMD}\" is NOT supported by this shell\n"
           continue
         fi

         if [ "${EDITOR}"x = ""x ] ; then
           "printf" "No valid editor found (set the variable EDITOR before calling this script)\n"
           continue
         fi

         if [ ! -x "${EDITOR}" ] ; then
           "printf" "${EDITOR} not found or not executable (check the variable EDITOR)\n"
           continue
         fi

         FUNCTION_LIST="$( __evaluate_fn "${CMD_PARAMETER}" )"
         
         for CUR_VALUE in ${FUNCTION_LIST} ; do
           USER_INPUT1=""
           
           FUNC_SAVE_VAR="__TMP_FUNCTION_${CUR_VALUE}"
           eval CUR_FUNCTION_CODE="\$${FUNC_SAVE_VAR}"
           [ "${CUR_FUNCTION_CODE}"x = ""x ] && CUR_FUNCTION_CODE="$( "typeset" -f "${CUR_VALUE}" 2>/dev/null )"

           if [ "${CUR_FUNCTION_CODE}"x = ""x ] ; then
             "printf" "The function \"${CUR_VALUE}\" is not defined\n"
             "printf" "Create a new function \"${CUR_VALUE}\" (y/N)? " 
             "read" USER_INPUT1
             if [ "${USER_INPUT1}"x = "y"x ] ; then
               CUR_FUNCTION_CODE="$( typeset -f function_template | sed "s/function_template/${CUR_VALUE}/g" )"
             else
               "printf" "New function \"${CUR_VALUE}\" not created.\n"
               "continue"
             fi
             
           else
             CUR_FUNCTION_CODE="# delete the existing function defintion 
unset -f ${CUR_VALUE}

${CUR_FUNCTION_CODE}
"
           fi
           "echo" "${CUR_FUNCTION_CODE}" >"${TMP_FILE1}"

           HASHCODE1="$( cksum "${TMP_FILE1}" 2>/dev/null | cut -f1 -d " "  )"
           [ "${HASHCODE1}"x = ""x ] && HASHCODE1="$( <"${TMP_FILE1}" )"

           while true ; do
             ${EDITOR} "${TMP_FILE1}"

             HASHCODE2="$( cksum "${TMP_FILE1}" 2>/dev/null | cut -f1 -d " "  )"
             [ "${HASHCODE2}"x = ""x ] && HASHCODE2="$( <"${TMP_FILE1}" )"

             if [ "${HASHCODE1}"x = "${HASHCODE2}"x -a "${USER_INPUT1}"x = ""x  ] ; then
               "printf" "No changes found in the edited source code.\n"
               break
             else               
               "printf" "Checking the new source code for \"${CUR_VALUE}\" using the shell ${CUR_SHELL} now ...\n"
               ${CUR_SHELL} -x -n "${TMP_FILE1}"
               if [ $? -ne 0 ] ; then
                 "printf" "Syntax Errors found in the new source code for \"${CUR_VALUE}\" - edit again (Y/n)? "
                 "read" USER_INPUT1
                 [ "${USER_INPUT1}"x != "n"x ] && continue
                  "printf" "New source code for \"${CUR_VALUE}\" ignored\n"
                 break
               fi                 
               "printf" "Enabling the new source code for \"${CUR_VALUE}\" now ...\n"
               . "${TMP_FILE1}"

               eval  ${FUNC_SAVE_VAR}="\$( typeset -f  ${CUR_VALUE} )"
               break
             fi
           done
         done
         ;;

      "func "* | "viewfunc "* | "viewFunc "* )
         if [ "${TYPESET_F_SUPPORTED}"x != "yes"x ] ; then
           "printf" "\"typeset -f\" required for \"${CUR_CMD}\" is NOT supported by this shell\n"
           continue
         fi
         
         FUNCTION_LIST="$( __evaluate_fn "${CMD_PARAMETER}" )"
         
         for CUR_VALUE in ${FUNCTION_LIST} ; do

           FUNC_SAVE_VAR="__TMP_FUNCTION_${CUR_VALUE}"
           eval CUR_FUNCTION_CODE="\$${FUNC_SAVE_VAR}"
           [ "${CUR_FUNCTION_CODE}"x = ""x ] && CUR_FUNCTION_CODE="$( "typeset" -f "${CUR_VALUE}" 2>/dev/null )"

           "typeset" +f "${CUR_VALUE}" 2>/dev/null 1>/dev/null
           if [ $? -ne 0 ] ; then
             "printf" "The function ${CUR_VALUE} is not defined\n\n"
             "continue"
           else
             "printf" "${CUR_FUNCTION_CODE}\n"      
           fi
         done
         ;;

      "functions" | "func" | "funcs" )
        "typeset" +f | grep -v "^__"

        ;;

      "functions "* | "func "* | "funcs "* )
        "printf" "$( __evaluate_fn "${CMD_PARAMETER}" )\n"
        ;;
         
      "add_debug_code"* )
         if [ "${TYPESET_F_SUPPORTED}"x != "yes"x ] ; then
           "printf" "\"typeset -f\" required for \"${CUR_CMD}\" is NOT supported by this shell\n"
           continue
         fi
         
         FUNCTION_LIST="$( __evaluate_fn "${CMD_PARAMETER}" )"
         
         for CUR_VALUE in ${FUNCTION_LIST} ; do
           "typeset" +f "${CUR_VALUE}" 2>/dev/null 1>/dev/null
           if [ $? -ne 0 ] ; then
             "printf" "The function ${CUR_VALUE} is not defined\n"
             "continue"
           fi

           if [[ $( "typeset" -f "${CUR_VALUE}" 2>&1 ) == *\$\{__DEBUG_CODE\}* ]] ; then
             "printf" "The function ${CUR_VALUE} is already debug enabled\n"
             "continue"
           fi
           "printf" "Adding debug code to the function ${CUR_VALUE} ...\n"   
            if [ ${USE_ONLY_KSH88_FEATURES} = 0 ] ; then
              ADD_CODE=" typeset __FUNCTION=${CUR_VALUE}; "
            else
              ADD_CODE="  "
            fi
            eval "$( typeset -f  "${CUR_VALUE}" | sed "1 s/{/\{ ${ADD_CODE}\\\$\{__DEBUG_CODE\}\;/" )"                        
          done
          ;;

      view_debug | viewdebug )
        if [ "${TRACE_FEATURE_SUPPORTED}"x != "yes"x ] ; then
          "printf" "Warning: The tracing features using \$0 are not supported by this shell\n"
        fi
        
        if [ "${__FUNCTIONS_WITH_DEBUG_CODE}"x != ""x ] ; then
          "printf" "Debug code is currently enabled for these functions: \n${__FUNCTIONS_WITH_DEBUG_CODE}\n"
          [ ${VERBOSE} = ${__TRUE} ] && "printf" "The current debug code for all functions (\$__DEBUG_CODE) is:\n${__DEBUG_CODE}\n" 
        else
          "printf" "Debug code is currently enabled for no function\n"
        fi        
        ;;

      clear_debug | cleardebug )
        if [ "${TRACE_FEATURE_SUPPORTED}"x != "yes"x ] ; then
          "printf" "Warning: The tracing features using \$0 are not supported by this shell\n"
        fi
        "printf" "Clearing the debug code now ...\n"
        __DEBUG_CODE="${__USER_DEBUG_CODE} ${__CODE_TO_ENABLE_VERBOSE_MODE}"
        __FUNCTIONS_WITH_DEBUG_CODE=""
        ;;
          
      "debug "* | "set_debug "* | "setdebug "* )
        if [ "${TRACE_FEATURE_SUPPORTED}"x != "yes"x ] ; then
          "printf" "Warning: The tracing features using \$0 are not supported by this shell\n"
        fi

        if [ "${CMD_PARAMETER}"x != ""x ] ; then
          "printf" "Enabling debug code for the function(s) \"${CMD_PARAMETER}\" now\n"
          CUR_STATEMENT="[ 0 = 1 "

          if [ "${__KSH_VERSION}"x = "93"x -a ${USE_ONLY_KSH88_FEATURES} = ${__FALSE} ] ; then
            CUR_STATEMENT="__FUNCTION=\"\${.sh.fun}\" ; ${CUR_STATEMENT}"
          fi

          if [[ ${CMD_PARAMETER} == +* ]] ; then
# preserve existing settings          
            "printf" "Current settings for debug code (${__FUNCTIONS_WITH_DEBUG_CODE}) are preserved.\n"
            FUNCTION_LIST="${__FUNCTIONS_WITH_DEBUG_CODE} $( __evaluate_fn "${CMD_PARAMETER#*+}" )"
          else
# overwrite existing settings          
            "printf" "Current settings for debug code are overwritten.\n"
            FUNCTION_LIST="$( __evaluate_fn "${CMD_PARAMETER}" )"
          fi

          __FUNCTIONS_WITH_DEBUG_CODE=""
          for CUR_VALUE in ${FUNCTION_LIST} ; do
            [[ ${CUR_VALUE} == +* ]] && CUR_VALUE="${CUR_VALUE#*+}"
            
            if [[ ${__FUNCTIONS_WITH_DEBUG_CODE} == *\ ${CUR_VALUE}\ * ]] ; then
              "printf" "Debug code is already enabled for the function ${CUR_VALUE}\n"
              continue
            fi

            "printf" "Enabling debug code for the function \"${CUR_VALUE}\" ...\n"
            __FUNCTIONS_WITH_DEBUG_CODE="${__FUNCTIONS_WITH_DEBUG_CODE} ${CUR_VALUE} "
            CUR_STATEMENT="${CUR_STATEMENT} -o \"\$0\"x = \"${CUR_VALUE}\"x -o \"\${__FUNCTION}\"x = \"${CUR_VALUE}\"x "

            if ! "typeset" +f "${CUR_VALUE}" >/dev/null ; then
              "printf" "WARNING: The function \"${CUR_VALUE}\" is not defined\n"
               continue
            fi
 
            if [ "${TYPESET_F_SUPPORTED}"x != "yes"x ] ; then
              "printf" "\"typeset -f\" required for \"${CUR_CMD}\" is NOT supported by this shell\n"
               continue
            fi

            if [[ $( "typeset" -f "${CUR_VALUE}" 2>&1 ) != *\$\{__DEBUG_CODE\}* ]] ; then
              "printf" "Adding debug code to the function ${CUR_VALUE} ...\n"           
              ADD_CODE=" typeset __FUNCTION=${CUR_VALUE}; "
              eval "$( typeset -f  "${CUR_VALUE}" | sed "1 s/{/\{ ${ADD_CODE}\\\$\{__DEBUG_CODE\}\;/" )"                        
            fi
          done
          CUR_STATEMENT="eval ${CUR_STATEMENT} ] && printf \"\n*** Enabling trace for the function \${__FUNCTION:=\$0} ...\n\" >&2 && set -x "
          __DEBUG_CODE="${__USER_DEBUG_CODE} ${CUR_STATEMENT} ; ${__CODE_TO_ENABLE_VERBOSE_MODE}" 

        else
          "printf" " ${USER_INPUT}: Parameter missing\n"
        fi 
        ;;

      "" )
        :
        ;;

      * )
        if [ "${USER_INPUT}"x = "."x -o "${USER_INPUT}"x = "!."x ] ; then
            "printf" "\".\" without parameter is useless\n"
            continue          
        elif [ "${USER_INPUT}"x = "function"x ] ; then
          continue
        fi
        
        if [[ ${USER_INPUT} = .\ * || ${USER_INPUT} = !.\ * ]] ; then
          eval "CUR_FUNCTION_CODE=${CMD_PARAMETER}"
          if [ "${CUR_FUNCTION_CODE}"x != "${CMD_PARAMETER}"x ] ; then
            "printf" "File to source in is \"${CUR_FUNCTION_CODE}\" \n"
          fi
          
          if [ ! -r "${CUR_FUNCTION_CODE}" ] ; then
            "printf" "The file \"${CUR_FUNCTION_CODE}\" does not exist or is not readable\n"
            continue
          fi    
          "printf" "Checking the file \"${CUR_FUNCTION_CODE}\" for errors using the shell ${CUR_SHELL} ...\n"
          ${CUR_SHELL} -x -n "${CUR_FUNCTION_CODE}"
          if [ $? -ne 0 ] ; then
            "printf" "There is a syntax error in the file \"${CUR_FUNCTION_CODE}\" \n"
            continue
          fi
        fi

        if [[ ${USER_INPUT} = !* ]] ; then
          "printf" "Executing now \"${USER_INPUT#*!}\" ...\n"
          ${USER_INPUT#*!}
        else
          "printf" "Executing now \"eval ${USER_INPUT}\" ...\n"
          "eval" ${USER_INPUT}
        fi
        "printf" "\n---------\nRC is $?\n"    
        ;;
    esac
  done </dev/tty >/dev/tty 2>&1

  [ "${__TMP__STTY_SETTINGS}"x != ""x ] &&  stty ${__TMP__STTY_SETTINGS}

  INSIDE_DEBUG_SHELL=${__FALSE}

  "return" ${THISRC}
}

# ----------------------------------------------------------------------
# DebugShell
#
# this is a wrapper function for __DebugShell
#
# Usage: DebugShell
#
# returns: ${__TRUE}
#
# Input is always read from /dev/tty; output always goes to /dev/tty
# so DebugShell is only allowed if STDIN is a tty.
#
function DebugShell {
  typeset __FUNCTION="DebugShell"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}
  
  typeset THISRC=${__TRUE}

  while true ; do
    __DebugShell $*
    THISRC=$?
    [ ${INSIDE_DEBUG_SHELL}x = ${__FALSE}x ]  && break
    INSIDE_DEBUG_SHELL=${__FALSE}
  done
  
  return ${THISRC}
}

# ----------------------------------------------------------------------
# show_script_usage
#
# write the script usage to STDOUT
#
# usage: show_script_usage
#
# returns: ${__TRUE} - the message was written
#
# note: the function writes all lines from the script that start with
#       "#H#" without the "#H#"
#
function show_script_usage {
  typeset __FUNCTION="show_script_usage"    
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  typeset HELPMSG=""
  
  typeset REGEX=""
  
  if [ ${SHORT_HELP} = ${__TRUE} ]; then
    REGEX="^#h#"
  elif [ ${VERBOSE_LEVEL} -ge 1 ] ; then
#
# print also the verbose usage help if --v used
#
    REGEX="^#H#|^#h#|^#U#"
  else
    REGEX="^#H#|^#h#"
  fi
  
  HELPMSG="$( ${EGREP} "${REGEX}" "${REAL_SCRIPTNAME}" | cut -c4- | sed -e "s/scriptt_mini.sh/${SCRIPTNAME}/g"  -e "s/#VERSION#/${SCRIPT_VERSION}/g")"
   
  eval echo \""${HELPMSG}"\"

  if [ ${SHORT_HELP} = ${__TRUE} ]; then
    echo "
 Use the parameter \"--help\" to print the detailed help message; use the parameter \"--help -v\" to also print the list of supported environment variables"
  fi

  if [ "${USAGE_HELP}"x != ""x ] ; then
    echo "${USAGE_HELP}"
  fi
  echo
  echo " The known modules are: ${LIST_OF_KNOWN_MODULES}" 
  echo
  
# check for r
  if [ "${ENABLE_DEBUG}"x = "${__TRUE}x" ] ; then
    echo "
Current environment: ksh version: ${__KSH_VERSION} | change function code supported: ${TYPESET_F_SUPPORTED} | tracing feature using \$0 supported: ${TRACE_FEATURE_SUPPORTED}
"
  else
    echo "
Note: The parameter -D and --var are disabled
"
  fi
  
# execute the function show_extended_usage_help if defined and the parameter
# -v was found
#
  if [ ${VERBOSE} = ${__TRUE} ] ; then  
    if typeset -f show_extended_usage_help 2>/dev/null  >/dev/null ; then
      show_extended_usage_help
    fi
  fi
  
  return ${THISRC}
}

# ----------------------------------------------------------------------
# general exit routine
#      

# ----------------------------------------------------------------------
# cleanup
#
# Housekeeping tasks (in this order):
#
#   - execute the cleanup functions
#   - kill temporary processes 
#   - remove temporary files 
#   - umount mount points
#   - remove temporary directories
#   - execute the finish functions
#
# usage: cleanup
#
# returns: 0
#
function cleanup {
  typeset __FUNCTION="cleanup"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset CUR_DIR=""
  typeset CUR_FILE=""
  typeset CUR_PID=""
  typeset CUR_KILL_PROC_TIMEOUT=""
  typeset CUR_FUNC=""
  typeset CUR_DEV0=""
  typeset CUR_DEV1=""
  typeset CUR_MOUNT=""
  typeset CUR_MOUNT1=""
  typeset i=0
  typeset ROUTINE_PARAMETER=""
  
  cd /
  
  LogRuntimeInfo "Housekeeping process started ...." 
  if [ $? -ne 0 -a "${PREFIX}"x != ""x ] ; then
    LogMsg "-"
    LogMsg "*** Housekeeping is starting ..."
  fi
  
  if [ "${CLEANUP_FUNCTIONS}"x != ""x -a "${NO_EXIT_ROUTINES}"x != "${__TRUE}"x ] ; then
    LogRuntimeInfo "Executing the cleanup functions \"${CLEANUP_FUNCTIONS}\" ..."
  
    for CUR_FUNC in ${CLEANUP_FUNCTIONS} ; do

      ROUTINE_PARAMETER="${CUR_FUNC#*:}"
      CUR_FUNC="${CUR_FUNC%%:*}"
      [ "${CUR_FUNC}"x = "${ROUTINE_PARAMETER}"x ] && ROUTINE_PARAMETER="" || ROUTINE_PARAMETER="$( IFS=: ; printf "%s " ${ROUTINE_PARAMETER}  )"
    
      typeset +f "${CUR_FUNC}" 2>/dev/null >/dev/null${CUR_KILL_PROC_TIMEOUT}
      if [ $? -eq 0 ] ; then
        LogRuntimeInfo "Executing the cleanup function \"${CUR_FUNC}\" (Parameter are: \"${ROUTINE_PARAMETER}\") ..."
        INSIDE_CLEANUP_ROUTINE=${__TRUE}
        ${PREFIX} ${CUR_FUNC} ${ROUTINE_PARAMETER}
        INSIDE_CLEANUP_ROUTINE=${__FALSE}
      else
        LogRuntimeInfo "The cleanup function \"${CUR_FUNC}\" is not defined - ignoring this entry"
      fi
    done
  else
    LogRuntimeInfo "No cleanup functions defined or cleanup functions disabled"
  fi

  if [ "${PROCS_TO_KILL}"x != ""x -a "${NO_KILL_PROCS}"x != "${__TRUE}"x ] ; then
    LogRuntimeInfo "Stopping the processes to kill \"${PROCS_TO_KILL}\" ..."
    ${PREFIX} KillProcess ${PROCS_TO_KILL}
  else
    LogRuntimeInfo "No processes to kill defined or process killing disabled"
  fi
  
  if [ "${FILES_TO_REMOVE}"x != ""x -a "${NO_TEMPFILES_DELETE}"x != "${__TRUE}"x ] ; then
    LogRuntimeInfo "Removing the temporary files \"${FILES_TO_REMOVE}\" ..." 
    for CUR_FILE in ${FILES_TO_REMOVE} ; do
      if [ -f "${CUR_FILE}" ] ; then
        LogRuntimeInfo "Removing the file \"${CUR_FILE}\" ..."
        ${PREFIX} \rm -f "${CUR_FILE}"
      else
        LogRuntimeInfo "The file \"${CUR_FILE}\" does not exist."
      fi
    done
  else
    LogRuntimeInfo "No files to delete defined or files deleting disabled"
  fi

  if [ "${MOUNTS_TO_UMOUNT}"x != ""x -a "${NO_UMOUNT_MOUNTPOINTS}"x != "${__TRUE}"x ] ; then
    LogRuntimeInfo "Umounting the mount points to umount \"${MOUNTS_TO_UMOUNT}\" ..."
    for CUR_MOUNT in ${MOUNTS_TO_UMOUNT} ; do
      if [[ ${CUR_MOUNT} != /* ]] ; then
        LogRuntimeInfo "\"${CUR_MOUNT}\" is not a mount point"
        continue
      fi

      if [ ! -d "${CUR_MOUNT}" ] ; then
        LogRuntimeInfo "\"${CUR_MOUNT}\" does not exist"
        continue
      fi

      CUR_MOUNT1="${CUR_MOUNT%/*}" 
      [ "${CUR_MOUNT1}"x = ""x ] && CUR_MOUNT1="/"
      CUR_DEV0="$( df -h ${CUR_MOUNT}  2>/dev/null | tail -1 | awk '{ print $1 };' )"
      CUR_DEV1="$( df -h ${CUR_MOUNT1} 2>/dev/null | tail -1 | awk '{ print $1 };' )"
      if [ "${CUR_DEV1}"x != "${CUR_DEV0}"x ] ; then
        LogRuntimeInfo "Umounting \"${CUR_MOUNT}\" ..."
        ${PREFIX} umount "${CUR_MOUNT}"
      else
        LogRuntimeInfo "\"${CUR_MOUNT}\" is not mounted"
      fi
    done
  else
    LogRuntimeInfo "No mount points to umount configured"
  fi
  
  if [ "${DIRS_TO_REMOVE}"x != ""x -a "${NO_TEMPDIR_DELETE}"x != "${__TRUE}"x ] ; then
    LogRuntimeInfo "Removing the temporary directories \"${DIRS_TO_REMOVE}\" ..."
    for CUR_DIR in ${DIRS_TO_REMOVE} ; do
      if [ -d "${CUR_DIR}" ] ; then
        LogRuntimeInfo "Removing the directory \"${CUR_DIR}\" ..."
        ${PREFIX} \rm -rf "${CUR_DIR}"
      else
        LogRuntimeInfo "The directory \"${CUR_DIR}\" does not exist"
      fi
    done
  else
    LogRuntimeInfo "No directories to remove defined or directory removing disabled"
  fi


  if [ "${FINISH_FUNCTIONS}"x != ""x  -a "${NO_FINISH_ROUTINES}"x != "${__TRUE}"x ] ; then
    LogRuntimeInfo "Executing the finish functions \"${FINISH_FUNCTIONS}\" ..."
    for CUR_FUNC in ${FINISH_FUNCTIONS} ; do

      ROUTINE_PARAMETER="${CUR_FUNC#*:}"
      CUR_FUNC="${CUR_FUNC%%:*}"
      [ "${CUR_FUNC}"x = "${ROUTINE_PARAMETER}"x ] && ROUTINE_PARAMETER="" || ROUTINE_PARAMETER="$( IFS=: ; printf "%s " ${ROUTINE_PARAMETER}  )"

      typeset +f "${CUR_FUNC}" 2>/dev/null >/dev/null
      if [ $? -eq 0 ] ; then
        LogRuntimeInfo "Executing the finish function \"${CUR_FUNC}\" (Parameter are: \"${ROUTINE_PARAMETER}\") ..."
        INSIDE_FINISH_ROUTINE=${__TRUE}
        ${PREFIX} ${CUR_FUNC} ${ROUTINE_PARAMETER}
        INSIDE_FINISH_ROUTINE=${__FALSE}
      else
        LogRuntimeInfo "The finish function \"${CUR_FUNC}\" is not defined - ignoring this entry"
      fi
    done
  else
    LogRuntimeInfo "No finish functions defined or finish functions disabled"
  fi
           
  return 0
}

# ----------------------------------------------------------------------
# die
#
# do the housekeeping and end the script 
#
# usage: die [script_returncode] [end_message]
#
# returns: the function ends the script
#
# default returncode is 0; there is no default for end_message
#
function die {
  typeset __FUNCTION="die"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  __unsettraps

  typeset THISRC=$1
  [ "${THISRC}"x = ""x ] && THISRC=0
  
  INSIDE_DIE=${__TRUE}

  if [ "${__STTY_SETTINGS}"x != ""x ] ; then
    LogRuntimeInfo "Resetting the tty ..."
    stty ${__STTY_SETTINGS}
    __STTY_SETTINGS=""
  fi
  
  if [ ${NO_CLEANUP}x = ${__TRUE}x ] ; then
    LogRuntimeInfo "House keeping is disabled"
  else
    cleanup
  fi
  
  if [ $# -ne 0 ] ; then
    shift
    if [ $# -ne 0 ] ; then
      if [ ${THISRC} = 0 ] ; then
        LogMsg "$*"
      else
        LogError "$*! RC=${THISRC}"
      fi
    fi      
  fi

  if [ "${PREFIX}"x != ""x ] ; then
    LogMsg "-"
    LogMsg "*** Running in dry-run mode -- no changes were done. The dryrun prefix used was \"${PREFIX}\" "
    LogMsg "-"
  fi

  if [ "${LOGFILE}"x != ""x -a -f "${LOGFILE}" ] ; then
    LogMsg "### The logfile used was ${LOGFILE}"
  fi
   
  gettime_in_seconds ENDTIME_IN_SECONDS
  ENDTIME_IN_HUMAN_READABLE_FORMAT="$( date "+%d.%m.%Y %H:%M:%S" )"

  if isNumber ${STARTTIME_IN_SECONDS} -a isNumber ${ENDTIME_IN_SECONDS}  ; then
    (( RUNTIME_IN_SECONDS = ENDTIME_IN_SECONDS - STARTTIME_IN_SECONDS ))
    RUNTIME_IN_HUMAN_READABLE_FORMAT="$( echo ${RUNTIME_IN_SECONDS} | awk '{printf("%d:%02d:%02d:%02d\n",($1/60/60/24),($1/60/60%24),($1/60%60),($1%60))}'  )"
  else
    RUNTIME_IN_SECONDS="?"
    RUNTIME_IN_HUMAN_READABLE_FORMAT=""
  fi

  LogMsg "### The start time was ${STARTTIME_IN_HUMAN_READABLE_FORMAT}, the script runtime is (day:hour:minute:seconds) ${RUNTIME_IN_HUMAN_READABLE_FORMAT} (= ${RUNTIME_IN_SECONDS} seconds)"

  LogMsg "### ${SCRIPTNAME} ended at ${ENDTIME_IN_HUMAN_READABLE_FORMAT} (The PID of this process is $$; the RC is ${THISRC})"

  exit ${THISRC}
}


# ----------------------------------------------------------------------
# signal_exit_handler
#
# signal handler for the signal EXIT
#
# usage: the function is called via the signal only
#
# returns: the function ends the script using the function die
#
function signal_exit_handler {  
  typeset __FUNCTION="signal_exit_handler"    
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}
  
  typeset SIGNAL_LINENO=$1
  LogRuntimeInfo "Signal handler for the signal EXIT called"
  
  [ ${INSIDE_EXIT_HANDLER} = ${__TRUE} ] && return
  INSIDE_EXIT_HANDLER=${__TRUE}
  
  if [ ${INSIDE_DIE} = ${__FALSE} ] ; then
    die 200 "Script aborted for unknown reason; EXIT signal received"
  fi  

  INSIDE_EXIT_HANDLER=${__FALSE}
}

# ----------------------------------------------------------------------
# signal_quit_handler
#
# signal handler for the signal QUIT
#
# usage: the function is called via the signal only
#
# returns: 
#
function signal_quit_handler {  
  typeset __FUNCTION="signal_quit_handler"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset SIGNAL_LINENO=$1
  LogRuntimeInfo "Signal handler for the signal QUIT called"
 
  [ ${INSIDE_QUIT_HANDLER} = ${__TRUE} ] && return
  INSIDE_QUIT_HANDLER=${__TRUE}

  if [ ${INSIDE_DIE} = ${__FALSE} ] ; then
    die 201 "Script aborted for unknown reason, QUIT signal received"
  fi  
  
  INSIDE_QUIT_HANDLER=${__FALSE}
}

# ----------------------------------------------------------------------
# signal_usr1_handler
#
# signal handler for the signal USR1
#
# usage: the function is called via the signal only
#
# returns: n/a
#
function signal_usr1_handler {
  typeset __FUNCTION="signal_usr1_handler"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset SIGNAL_LINENO=$1
  LogRuntimeInfo "Signal handler for the signal USR1 called in line ${SIGNAL_LINENO}"

  [ ${INSIDE_USR1_HANDLER} = ${__TRUE} ] && return
  INSIDE_USR1_HANDLER=${__TRUE}

  LogMsg "Signal USR1 received while in line ${SIGNAL_LINENO}" >&2
  DebugShell
  
  INSIDE_USR1_HANDLER=${__FALSE}
}

# ----------------------------------------------------------------------
# signal_usr2_handler
#
# signal handler for the signal USR2
#
# usage: the function is called via the signal only
#
# returns: n/a
#
function signal_usr2_handler {
  typeset __FUNCTION="signal_usr2_handler"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset SIGNAL_LINENO=$1
  LogRuntimeInfo "Signal handler for the signal USR2 called in line ${SIGNAL_LINENO}"

  [ ${INSIDE_USR1_HANDLER} = ${__TRUE} ] && return
  INSIDE_USR2_HANDLER=${__TRUE}

#  LogMsg "Signal USR2 received while in line ${SIGNAL_LINENO}" >&2
#  DebugShell
  
  INSIDE_USR2_HANDLER=${__FALSE}
}


# ----------------------------------------------------------------------
# signal_hup_handler
#
# signal handler for the signal HUP
#
# usage: the function is called via the signal only
#
# returns: n/a
#
function signal_hup_handler {
  typeset __FUNCTION="signal_hup_handler"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset SIGNAL_LINENO=$1
  LogRuntimeInfo "Signal handler for the signal HUP called in line ${SIGNAL_LINENO}"

  [ ${INSIDE_USR1_HANDLER} = ${__TRUE} ] && return
  INSIDE_HUP_HANDLER=${__TRUE}

#  LogMsg "Signal HUP received while in line ${SIGNAL_LINENO}" >&2
#  DebugShell
  
  INSIDE_HUP_HANDLER=${__FALSE}
}

# ----------------------------------------------------------------------
# signal_break_handler
#
# signal handler for the signal break (CTRL-C)
#
# usage: the function is called via the signal only
#
# returns: n/a
#
function signal_break_handler {
  typeset __FUNCTION="signal_break_handler"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset SIGNAL_LINENO=$1
  LogRuntimeInfo "Signal handler for the signal BREAK called in line ${SIGNAL_LINENO}"

  if [ ${INSIDE_BREAK_HANDLER} = ${__TRUE} ] ; then
    INSIDE_BREAK_HANDLER=${__FALSE}
    return
  fi

  LogMsg "Signal BREAK received while in line ${SIGNAL_LINENO}" >&2
  
  INSIDE_BREAK_HANDLER=${__TRUE}
  
  if [ "${BREAK_ALLOWED}"x = "DebugShell"x ] ; then
    if [ ${ENABLE_DEBUG}x = ${__TRUE}x ]  ; then
      LogMsg "*** DebugShell called via CTRL_C"
      DebugShell
    fi
  elif [ ${BREAK_ALLOWED} = ${__FALSE} ] ; then
    LogRuntimeInfo "CTRL-C is disabled for ${SCRIPTNAME}"
  else
    die 250 "${SCRIPTNAME} aborted by CTRL-C"
  fi
  
  INSIDE_BREAK_HANDLER=${__FALSE}
}

# ----------------------------------------------------------------------
#

# ----------------------------------------------------------------------
# print_runtime_variables
#
# print the current values of the runtime variables
#
# usage: print_runtime_variables 
#
# returns: ${__TRUE}
#
function print_runtime_variables {
  typeset __FUNCTION="print_runtime_variables"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}
    
  typeset THISRC=${__TRUE}
  typeset CUR_VAR=""
  typeset CUR_VALUE=""
  typeset CUR_MSG=""
  
  for CUR_VAR in ${RUNTIME_VARIABLES} ${APPLICATION_VARIABLES} ; do
    if [[ ${CUR_VAR} == \#* ]] ; then
      CUR_MSG="*** $( echo "${CUR_VAR#*#}" | tr "_" " ")"
    else
      eval CUR_VALUE="\$${CUR_VAR}"
      CUR_MSG="  ${CUR_VAR}: \"${CUR_VALUE}\" "
    fi
    "printf"  "${CUR_MSG}\n" 
  done
  
  return ${THISRC}
}

# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
# isNumber
#
# check if a value is an integer
#
# usage: isNumber testValue
#
# returns: ${__TRUE} - testValue is a number else not
#
function isNumber {
  typeset __FUNCTION="isNumber"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}
    
  typeset THISRC=${__FALSE}

# old code:
#  typeset TESTVAR="$(echo "$1" | sed 's/[0-9]*//g' )"
#  [ "${TESTVAR}"x = ""x ] && return ${__TRUE} || return ${__FALSE}

  [[ $1 == +([0-9]) ]] && THISRC=${__TRUE} || THISRC=${__FALSE}

  return ${THISRC}
}

# ----------------------------------------------------------------------
# AskUser
#
# Ask the user (or use defaults depending on the parameter -n and -y)
#
# Usage: AskUser "message" [default_return_code] [nodefault]
#
# returns: ${__TRUE} - user input is yes
#          ${__FALSE} - user input is no
#          USER_INPUT contains the user input
#
# Notes: "all" is interpreted as yes for this and all other questions
#        "none" is interpreted as no for this and all other questions
#
# If __NOECHO is ${__TRUE} the user input is not written to STDOUT
# __NOECHO is set to ${__FALSE} again in this function
#
# If __USE_TTY is ${__TRUE} the prompt is written to /dev/tty and the
# user input is read from /dev/tty . This is useful if STDOUT is redirected
# to a file.
#
# "shell" opens the DebugShell; set __DEBUG_SHELL_IN_ASKUSER to ${__FALSE}
# to disable the DebugShell in AskUser
#
function AskUser {
  typeset __FUNCTION="AskUser"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}
    
  typeset THISRC=""

  typeset CUR_MSG="$1"
  
  typeset DEFAULT_RETURN_CODE="${__FALSE}"
  
  typeset CUR_USER_REPSONSE=${__USER_RESPONSE_IS}
  
  [ $# -eq 2 ] && DEFAULT_RETURN_CODE="$2"
  [ "$3"x = "nodefault"x ] && CUR_USER_REPSONSE=""

  if [ "${__USE_TTY}"x = "${__TRUE}"x ] ; then
    typeset mySTDIN="</dev/tty"
    typeset mySTDOUT=">/dev/tty"
  else
    typeset mySTDIN=""
    typeset mySTDOUT=""
  fi

  case ${CUR_USER_REPSONSE} in

   "y" ) USER_INPUT="y" ; THISRC=${__TRUE}
         ;;

   "n" ) USER_INPUT="n" ; THISRC=${__FALSE}
         ;;

     * ) while true ; do
           [ $# -ne 0 ] && eval printf "\"${CUR_MSG} \"" ${mySTDOUT}
           if [ ${__NOECHO} = ${__TRUE} ] ; then
             __STTY_SETTINGS="$( stty -g )"
             stty -echo
           fi

           eval read USER_INPUT ${mySTDIN}
           if [ "${USER_INPUT}"x = "shell"x -a ${__DEBUG_SHELL_IN_ASKUSER} = ${__TRUE} ] ; then
             DebugShell
           else
             [ "${USER_INPUT}"x = "#last"x ] && USER_INPUT="${LAST_USER_INPUT}"
             break
           fi
         done

         if [ ${__NOECHO} = ${__TRUE} ] ; then
           stty ${__STTY_SETTINGS}
           __STTY_SETTINGS=""
         fi

         case ${USER_INPUT} in

           "y" | "Y" | "yes" | "Yes") THISRC=${__TRUE}  ;;

           "n" | "N" | "no" | "No" ) THISRC=${__FALSE} ;;

           "all" ) __USER_RESPONSE_IS="y"  ; THISRC=${__TRUE}  ;;

           "none" )  __USER_RESPONSE_IS="n" ;  THISRC=${__FALSE} ;;

           * )  THISRC=${DEFAULT_RETURN_CODE} ;;

        esac
        ;;
  esac
  [ "${USER_INPUT}"x != ""x ] && LAST_USER_INPUT="${USER_INPUT}"

  __NOECHO=${__FALSE}
  return ${THISRC}
}

# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
# show_extended_usage_help
#
# function: show_extended_usage_help
#
# usage: this function is called in show_script_usage if the 
#        parameter -v and -h are used
#
# returns: ${__TRUE} - 
#          ${__FALSE} - 
#
function show_extended_usage_help {
  typeset __FUNCTION="show_extended_usage_help"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
 
  typeset CUR_ENTRY=""
  typeset CUR_VAR=""
  typeset CUR_VALUE=""
  typeset CUR_TYPE=""
  typeset CUR_COMMENT=""

  typeset CUR_VAR_L=10
  typeset CUR_VALUE_L=16
  typeset CUR_TYPE_L=5
  typeset CUR_COMMENT_L=10
  
  typeset CUR_PRINTF_FORM=""
  typeset LAST_LINE_EMPTY=${__FALSE}
  
  
# add your code her
#  LogMsg "This function is called if the parameter -v and -h are used"

  if [ "${ENV_VARIABLES}"x != ""x ] ; then
    echo ""
    echo " Supported environment variables are (values for booleans: 0 = TRUE, 1 = FALSE):"
    echo ""
  
    echo "${ENV_VARIABLES}" | while IFS= read -r CUR_ENTRY  ; do
#    echo "${CUR_ENTRY}"
  
      CUR_VAR=""
      CUR_TYPE=""
      CUR_COMMENT=""
      
      CUR_VAR="${CUR_ENTRY%%#*}"
      [ ${#CUR_VAR} -gt ${CUR_VAR_L} ] && CUR_VAR_L=${#CUR_VAR}
      
      CUR_ENTRY="${CUR_ENTRY#*#}" 
      if [ "${CUR_ENTRY}"x != "${CUR_VAR}"x ] ; then
  
        CUR_TYPE="${CUR_ENTRY%%#*}"
        [ ${#CUR_TYPE} -gt ${CUR_TYPE_L} ] && CUR_TYPE_L=${#CUR_TYPE}
  
        CUR_COMMENT="${CUR_ENTRY#*#}"
        if [ "${CUR_TYPE}"x != "${CUR_COMMENT}"x ] ; then
          [ ${#CUR_COMMENT} -gt ${CUR_COMMENT_L} ] && CUR_COMMENT_L=${#CUR_COMMENT}
        fi
      fi
      
      if [ "${CUR_VAR}"x != ""x ] ; then
        eval CUR_VALUE="\$${CUR_VAR}"
        if [ ${#CUR_VALUE} -gt ${CUR_VALUE_L} ] ;then
          (( CUR_VALUE_L = ${#CUR_VALUE} + 2 ))
        fi
      fi
  
#
# ugly but working code .. (this loop is executed in a sub shell)
#
      echo  " %-${CUR_VAR_L}s %-${CUR_TYPE_L}s %-${CUR_VALUE_L}s %-${CUR_COMMENT_L}s" >"${TMPFILE1}"
  
    done
  
#  (( CUR_VALUE_L = CUR_VALUE_L +4 ))
  
#  CUR_PRINTF_FORM="%-${CUR_VAR_L}s %-${CUR_TYPE_L}s %-${CUR_VALUE_L}s %-${CUR_COMMENT_L}s"
  
    CUR_PRINTF_FORM="$( cat "${TMPFILE1}" )"
    
    LogMsg "-" "$( printf "${CUR_PRINTF_FORM}" "Variable" "Type" "Current value" "Comment" )"
  
    echo "${ENV_VARIABLES}" | while IFS= read -r CUR_ENTRY  ; do
     if [[ ${CUR_ENTRY} == \# ]] ; then
       LogMsg "-"
     elif [[ ${CUR_ENTRY} == \#* ]] ; then
       LogMsg "-" "${CUR_ENTRY}"
       continue
     fi
#    echo "${CUR_ENTRY}"
  
      CUR_VAR=""
      CUR_VALUE=""
      CUR_TYPE=""
      CUR_COMMENT=""
  
      CUR_VAR="${CUR_ENTRY%%#*}"
      [ ${#CUR_VAR} -gt ${CUR_VAR_L} ] && CUR_VAR_L=${#CUR_VAR}
      
      CUR_ENTRY="${CUR_ENTRY#*#}" 
      if [ "${CUR_ENTRY}"x != "${CUR_VAR}"x ] ; then
  
        CUR_TYPE="${CUR_ENTRY%%#*}"
        CUR_COMMENT="${CUR_ENTRY#*#}"
        if [ "${CUR_TYPE}"x != "${CUR_COMMENT}"x ] ; then
          [ ${#CUR_COMMENT} -gt ${CUR_COMMENT_L} ] && CUR_COMMENT_L=${#CUR_COMMENT}
        else
          CUR_COMMENT=""
        fi
      fi
  
      if [ "${CUR_VAR}"x != ""x ] ; then
        eval CUR_VALUE="\$${CUR_VAR}"
        CUR_VALUE="\"${CUR_VALUE}\""
      else 
        continue
      fi
  
#
# ugly but working code .. (this loop is executed in a sub shell)
#
   
      LogMsg "-" "$( printf "${CUR_PRINTF_FORM}" "${CUR_VAR# *}" "${CUR_TYPE# *}" "${CUR_VALUE}"  "${CUR_COMMENT# *}" )"
  
    done
  
    LogMsg "-" "
 How to use the variables:
      
 Either define the environment variables before executing the script or use the parameter \"--var name=value\"
  " 
  fi   

# print also the history if the parameter -v is used two times
#
  if [ ${VERBOSE_LEVEL} -ge 2 ] ; then
    grep "^#V#" "${REAL_SCRIPTNAME}" | cut -c4- | sed "s#sync_install_server_directory#${REAL_SCRIPTNAME}#g"
  fi

# print also the template history if the parameter -v is used three times
#
  if [ ${VERBOSE_LEVEL} -ge 3 ] ; then
    grep "^#T#" "${REAL_SCRIPTNAME}" | cut -c4- | sed "s#sync_install_server_directory#${REAL_SCRIPTNAME}#g"
  fi

  VERBOSE_LEVEL=0
  return ${THISRC}
}
  
  

# ----------------------------------------------------------------------
# switch_to_background
#
# function: switch the current process running this script into the background
#
# usage: switch_to_background {no_redirect}
#
# parameter: no_redirect - do not redirect STDOUT and STDERR to a file
#
# returns: ${__TRUE} - ok, the process is running in the background
#          ${__FALSE} - error, can not switch the process into the background
#
function switch_to_background {
  typeset __FUNCTION="switch_to_background"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  if [ ${INSIDE_DEBUG_SHELL}x = ${__TRUE}x ] ; then
    LogError "${__FUNCTION} not allowed in the Debugshell"
    return ${__FALSE}
  fi

  typeset REDIRECT_STDOUT=${__TRUE}
  [ "$1"x = "no_redirect"x ] && REDIRECT_STDOUT=${__FALSE}

  typeset TMPFILE=""
  typeset TMPLOGFILE=""

  typeset SIGTSTP=""
  typeset SIGCONT=""

# the signals used to stop a process and to restart the process in the
# background are different in the various Unix OS
#  
  case ${CUR_OS} in 
  
     SunOS )
       SIGTSTP="24"
       SIGCONT="25"
       ;;

     Linux )
       SIGTSTP="20"
       SIGCONT="18"
       ;;

     AIX )
       SIGTSTP="18"
       SIGCONT="19"
       ;;

     Darwin )
       SIGTSTP="18"
       SIGCONT="19"
       ;;

  esac

  if [ "${SIGTSTP}"x = ""x -o "${SIGCONT}"x = ""x ] ; then
    LogError "${__FUNCTION}: I do not know the signals used for OS \"${CUR_OS}\" "
    THISRC=${__FALSE}
  else

    LogMsg "Switching the process for the script \"${SCRIPTNAME}\" with the PID $$ into the background now ..."
  
  # create a duplicate file descriptor for the current STDOUT file descriptor
  #
    exec 9>&1
  
  # the file used for STDOUT and STDERR for the background process
  # (this is a global variable!)
  #
  
    if [ ${REDIRECT_STDOUT} = ${__TRUE} ] ; then
      NOHUP_STDOUT_STDERR_FILE="${NOHUP_STDOUT_STDERR_FILE:=${PWD}/nohup.out}"
  
      LogMsg "STDOUT/STDERR now goes to the file \"${NOHUP_STDOUT_STDERR_FILE}\" "
    fi
    
    case ${CUR_OS} in 
  
      SunOS | Linux | AIX | Darwin )
        if [ ${REDIRECT_STDOUT} = ${__TRUE} ] ; then
          exec 1>"${NOHUP_STDOUT_STDERR_FILE}" 2>&1 </dev/null
        fi
        
        TMPFILE="${TMPDIR}/${SCRIPTNAME}.$$.temp.sh"
        TMPLOGFILE="${TMPDIR}/${SCRIPTNAME}.$$.temp.log"
        
  # use &9 to write messages to the old STDOUT file descriptor
  #      echo "Test Redirect, TMPFILE is ${TMPFILE} " >&9
  
  # create a temporary script to switch this process into the background
  #      
        echo "
  # script to switch the process $$ to the background
  #
  kill -${SIGTSTP} $$
  sleep 1
  kill -${SIGCONT} $$
  exit 0
  "     >"${TMPFILE}" && chmod 755  "${TMPFILE}" && \
            FILES_TO_REMOVE="${FILES_TO_REMOVE} ${TMPFILE} ${TMPLOGFILE}"
  
        if [ ! -x "${TMPFILE}" ] ; then
          THISRC=${__FALSE}
          LogError "Can not create the temporary file for switching the process into the background"
        else
          "${TMPFILE}" >"${TMPLOGFILE}" 2>&1 &
          sleep 1
          __settraps
  
          LogMsg "-" >&9
          LogMsg "*** The script \"${SCRIPTNAME}\" (PID is $$) should now run in the background ...
  " >&9
        fi
        ;;
  
      * ) 
        LogError "Can not switch a process into the background in ${CUR_OS}"
        THISRC=${__FALSE}
        ;; 
    esac
  
    tty -s && RUNNING_IN_TERMINAL_SESSION=${__TRUE} || RUNNING_IN_TERMINAL_SESSION=${__FALSE}
  
  # close the temporary file descriptor again  
    exec 9>&-

  fi

  return ${THISRC}
}


# ----------------------------------------------------------------------
# create_lock_file
#
# function: create a lock file to avoid that multiple instances of this script are running at the same time
#
# usage: create_lock_file [lockfile] [wait_time] [wait_step_in_seconds]
#
# parameter: 
#   lockfile - fully qualified name of the lock file
#     default: ${DEFAULT_LOCK_FILE}
#
#   wait_time - time in seconds (#S), minutes (#M), or hours (#H) to wait if the lockfile already exist
#     default : ${DEFAULT_LOCK_FILE_WAIT_TIME} 
#
#   wait_step_in_seconds - wait pause in seconds
#     default: ${DEFAULT_STEP_COUNT}
#
# global varables used:
#
# WAIT_TIME_FOR_THE_LOCKFILE_IN_SECONDS
# PID_OF_PROCESS_HOLDING_THE_LOCKFILE
#
#                 
# returns: 0 -  lock file created without waiting (probably after waiting for ${WAIT_TIME_FOR_THE_LOCKFILE_IN_SECONDS} seconds)
#          1 -  error creating the lock file
#          2 -  lock file already exists - could not create the lockfile, the variable 
#               ${PID_OF_PROCESS_HOLDING_THE_LOCKFILE} contains the PID of the process holding the lockfile
#          3 -  usage error (invalid parameter, etc)
#          3 -  unknown error
#
function create_lock_file {
  typeset __FUNCTION="create_lock_file"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=0

  typeset LOCKFILE=""
  typeset LOCKFILE_DIR=""
  typeset WAIT_TIME=""
  typeset FACTOR=""
  typeset CUR_WAIT_TIME=""
  typeset WAIT_TIME_IN_SECONDS=""
  typeset WAIT_TIME_MSG=""
  typeset STEP_COUNT=""
  typeset CUR_STEP_COUNT=""
  typeset STEP_COUNT_MSG=""
  typeset STEP_COUNT_IN_SECONDS=""
  
  [ "$1"x != ""x ] && LOCKFILE="$1"    || LOCKFILE="${DEFAULT_LOCK_FILE}"
  [ "$2"x != ""x ] && WAIT_TIME="$2"   || WAIT_TIME="${DEFAULT_LOCK_FILE_WAIT_TIME}"
  [ "$3"x != ""x ] && STEP_COUNT="$3"  || STEP_COUNT="${DEFAULT_STEP_COUNT}"

  
  WAIT_TIME_FOR_THE_LOCKFILE_IN_SECONDS="0"
  PID_OF_PROCESS_HOLDING_THE_LOCKFILE=""

  LOCKFILE_DIR="${LOCKFILE%/*}"
  [ "${LOCKFILE_DIR}"x  = ""x ] && LOCKFILE_DIR="/"

  if [[ ${LOCKFILE_DIR} != /* ]] ; then
    LogError "The value for the lock file, \"${LOCKFILE_DIR}\", is not an absolute path"
    THISRC=3
  elif [ ! -d "${LOCKFILE_DIR}" ] ; then
    LogError "The directory for the lock file, \"${LOCKFILE_DIR}\" does not exist"
    THISRC=3
  fi

  if [ "${WAIT_TIME}"x = ""x ] ; then
    CUR_WAIT_TIME="0"
    FACTOR=1
    WAIT_TIME_MSG=""
  elif [[ ${WAIT_TIME} == *M || ${WAIT_TIME} == *m ]] ; then
    CUR_WAIT_TIME="${WAIT_TIME%[mM]*}"
    FACTOR=60
    WAIT_TIME_MSG=" ( = ${CUR_WAIT_TIME} minute(s) )"
  elif [[ ${WAIT_TIME} == *H || ${WAIT_TIME} == *h ]] ; then
    CUR_WAIT_TIME="${WAIT_TIME%[hH]*}"
    FACTOR=3600
    WAIT_TIME_MSG=" ( = ${CUR_WAIT_TIME} hour(s) )"
  elif [[ ${WAIT_TIME} == *S || ${WAIT_TIME} == *s ]] ; then
    CUR_WAIT_TIME="${WAIT_TIME%[sS]*}"
    FACTOR=1
    WAIT_TIME_MSG=""
  else
    CUR_WAIT_TIME="${WAIT_TIME}"
    FACTOR=1
    WAIT_TIME_MSG=""
  fi
   
  if ! isNumber ${CUR_WAIT_TIME}  ; then
    LogError "\"${WAIT_TIME}\" is not a valid value for the time wait parameter"
    THISRC=${__FALSE}
  fi
   
  (( WAIT_TIME_IN_SECONDS = CUR_WAIT_TIME * FACTOR ))


  if [ "${STEP_COUNT}"x = ""x ] ; then
    CUR_STEP_COUNT="0"
    FACTOR=1
    STEP_COUNT_MSG=""
  elif [[ ${STEP_COUNT} == *M || ${STEP_COUNT} == *m ]] ; then
    CUR_STEP_COUNT="${STEP_COUNT%[mM]*}"
    FACTOR=60
    STEP_COUNT_MSG=" ( = ${CUR_STEP_COUNT} minute(s) )"
  elif [[ ${STEP_COUNT} == *H || ${STEP_COUNT} == *h ]] ; then
    CUR_STEP_COUNT="${STEP_COUNT%[hH]*}"
    FACTOR=3600
    STEP_COUNT_MSG=" ( = ${CUR_STEP_COUNT} hour(s) )"
  elif [[ ${STEP_COUNT} == *S || ${STEP_COUNT} == *s ]] ; then
    CUR_STEP_COUNT="${STEP_COUNT%[sS]*}"
    FACTOR=1
    STEP_COUNT_MSG=""
  else
    CUR_STEP_COUNT="${STEP_COUNT}"
    FACTOR=1
    STEP_COUNT_MSG=""
  fi
   
  if ! isNumber ${CUR_STEP_COUNT} ] ; then
    LogError "\"${STEP_COUNT}\" is not a valid value for the time wait parameter"
    THISRC=${__FALSE}
  elif [ ${STEP_COUNT} = 0 ] ; then
    LogError "\"${STEP_COUNT}\" is not a valid value for the step count parameter"
    THISRC=${__FALSE}

  fi

  (( STEP_COUNT_IN_SECONDS = CUR_STEP_COUNT * FACTOR ))
    
#
# create the lock file
#
  if [ ${THISRC} = ${__TRUE} ] ; then

    while [ ${WAIT_TIME_FOR_THE_LOCKFILE_IN_SECONDS} -le ${WAIT_TIME_IN_SECONDS} ] ; do
      if [ -f "${LOCKFILE}" ] ; then
        LN_RC=1
      else
        set -C  # or: set -o noclobber
        : > "${LOCKFILE}" 2>>/dev/null
        LN_RC=$?
      fi

      if [ ${LN_RC} = 0 ] ; then
        LogInfo "Lockfile \"${LOCKFILE}\" created"
        set +C # or: set +o noclobber
        echo $$ >>"${LOCKFILE}"
        
        break
      fi

      if [ "${WAIT_TIME_IN_SECONDS}" != 0 ] ; then
        if [ "${WAIT_TIME_FOR_THE_LOCKFILE_IN_SECONDS}"x = "0"x  ] ; then
          LogMsg "-"
          LogMsg  "*******************************************************************************"
          LogMsg  "*** Another instance of the script \"${SCRIPTNAME}\" is currently running"
          LogMsg "-"
          
          RUNNING_PID="$( ${EGREP} -v "^#|^$" "${LOCKFILE}" 2>//dev/null )"
          if [ "${RUNNING_PID}"x != ""x ] ; then
            if isNumber ${RUNNING_PID} ; then
              CUR_OUTPUT="$( ps -fp ${RUNNING_PID} 2>&1 )"
              if [ $? -eq 0 ] ; then
                LogMsg "The running process is:"
                LogMsg "-"
                LogMsg "-" "${CUR_OUTPUT}"
                LogMsg "-"
              else
                LogMsg "The PID of the process creating the semaphor was ${RUNNING_PID} (there is no process currently running with that PID)"
              fi
            fi
          fi
          LogMsg "The file \"${LOCKFILE}\" already exists - now waiting for up to ${WAIT_TIME_IN_SECONDS} seconds${WAIT_TIME_MSG} in steps with ${STEP_COUNT_IN_SECONDS} seconds${STEP_COUNT_MSG}..."
        else
          printf "."
        fi
        sleep ${STEP_COUNT}
        (( WAIT_TIME_FOR_THE_LOCKFILE_IN_SECONDS = WAIT_TIME_FOR_THE_LOCKFILE_IN_SECONDS + STEP_COUNT_IN_SECONDS ))
      fi
    done      
  fi
  printf "\n"
 
#
# remove the lockfile at script end
#    
  if [ ${THISRC} = ${__TRUE} ] ; then

    if [ ${LN_RC} = 0 ] ; then
      [ ${WAIT_TIME_FOR_THE_LOCKFILE_IN_SECONDS} != 0 ] &&  LogMsg  "*** The other instance of the script ended. Will continue now ..."

      FILES_TO_REMOVE="${FILES_TO_REMOVE} ${LOCKFILE}"
      echo $$ >>"${LOCKFILE}"
    else
      THISRC=${__FALSE}
      LogMsg "-"
      LogError "Another instance of \"${SCRIPTNAME}\" is still running"
      PID_OF_PROCESS_HOLDING_THE_LOCKFILE="$( grep -v "^#" "${LOCKFILE}" )"
      if [ "${PID_OF_PROCESS_HOLDING_THE_LOCKFILE}"x != ""x  ] ; then
        if isNumber ${PID_OF_PROCESS_HOLDING_THE_LOCKFILE} ; then
          CUR_OUTPUT="$( ps -f -p ${PID_OF_PROCESS_HOLDING_THE_LOCKFILE} )" && \
            LogMsg "-" "
${CUR_OUTPUT}
"
        fi    
      fi
      LogMsg "       Either wait until the instance is finished or "
      LogMsg "       remove the file \"${LOCKFILE}\" if there is no other instance running"
      LogMsg "-"
    fi
  fi

  return ${THISRC}
}


# ----------------------------------------------------------------------
# get_fqn
#
# function: get the FQN of a file
#
# usage: get_fqn filename [...[filename#]]
#
# returns: ${__TRUE} - 
#          ${__FALSE} - 
#
# The function writes the FQN or the filename to STDOUT
#
function get_fqn {
  typeset __FUNCTION="get_fqn"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  typeset CUR_OUTPUT=""
  
  if [ "${READLINK}"x = ""x ] ; then
    CUR_OUTPUT="$*"
  else
    while [ $# -ne 0 ] ; do
      if [ ! -r $1 -a ! -d $( dirname $1 ) ] ; then
        CUR_OUTPUT="${CUR_OUTPUT} $1"
      else
        [ "${CUR_OUTPUT}"x = ""x ] && CUR_OUTPUT="$( ${READLINK} -f $1 )" || CUR_OUTPUT="${CUR_OUTPUT} $( ${READLINK} -f $1 )"
      fi
      shift 
    done
  fi
  \echo "${CUR_OUTPUT}"      

  return ${THISRC}
}

# ----------------------------------------------------------------------
# read_file_section
#
# function: read the lines of a file between start_regex and end_regex
#
# usage: read_file_section [filename] [start_regex] [end_regex] 
#
# returns: 0  OK, section found and printed to STDOUT 
#          1  OK, section not found in the file
#          2  file not found
#          3  error in one of the regex
#          4  invalid usage
#
# The function searches for sections starting with 
#
# start_regex
#  ...
# end_regex
# 
# The lines matching start_regex and end_regex are part of the output
#
# The output of the sed command used is in the global variable FILE_SECTION_CONTENTS (including
# the lines matching start_regex and end_regex).
# The remaining lines from the file will be in the global variable REMAINING_FILE_CONTENTS
#
# Example usage:
#   read_file_section "${DHCPD_CONFIG_FILE}" "^[ \t]*host[ \t]*${THIS_HOSTID}[ \t]*$" "^[ \t]*}[ \t]*$*"
#   read_file_section "${PXE_DEFAULT_CONFIG_FILE}" "^[ \t]*label[ \t]*${LABEL_FOR_PXE_DEFAULT_BOOT_MENU}[ \t]*$" "^[ \t]*append[ \t]*.*$"
#   read_file_section "${CUR_OUTPUT_FILE}" "^[ \t]*label install[ \t]*$" "^[ \t]*append[ \t]"
#
function read_file_section {
  typeset __FUNCTION="read_file_section"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=4
 
  typeset CUR_FILE="$1"
  typeset START_REGEX="$2"
  typeset END_REGEX="$3"

# init the global variables used
#  
  FILE_SECTION_CONTENTS=""
  REMAINING_FILE_CONTENTS=""
  
  if [ $# -eq 3 ] ; then
    if [ -r "${CUR_FILE}" ] ; then

#    ${SED} -n "/^[ \t]*host schemmer-04/,/^[ \t]*}/p" /var/tmp/dhcpd.conf  ; echo $?
#      FILE_SECTION_CONTENTS="$( ${SED} -n "/^[ \t]*${START_REGEX}/,/^[ \t]*${END_REGEX}[ \t]$/p" "${CUR_FILE}" 2>&1 )"

      FILE_SECTION_CONTENTS="$( ${SED} -n "/${START_REGEX}/,/${END_REGEX}/p" "${CUR_FILE}" 2>&1 )"
      if [ $? -eq 0 ] ; then
        REMAINING_FILE_CONTENTS="$( ${SED} -n "/${START_REGEX}/,/${END_REGEX}/!p" "${CUR_FILE}" 2>&1 )"
        if [ "${FILE_SECTION_CONTENTS}"x != ""x ] ; then
          THISRC=0
        else
          THISRC=1       
        fi
      else
        THISRC=3
      fi
    else
      THISRC=2
    fi
  else
    THISRC=4
  fi
  
  return ${THISRC}
}

# ----------------------------------------------------------------------
# gettime_in_seconds
#
# function: get the time since 1.1.1970 in seconds
#
# usage: VAR_NAME=$( gettime_in_seconds )
#
#  or  gettime_in_seconds VAR_NAME1 {... VAR_NAME#}
#
# returns: ${__TRUE} - time retrieved
#          ${__FALSE} - error retrieving the time
#
# Note:
#
#  "date +%s" is not supported on all OS
#
function gettime_in_seconds {
  typeset __FUNCTION="gettime_in_seconds"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
 
  typeset CUR_TIME_IN_SEC=""

  CUR_TIME_IN_SEC="$( perl -e 'print int(time)' 2>/dev/null )"
  if [ $? -ne 0 -o "${CUR_TIME_IN_SEC}"x = ""x ] ; then
    CUR_TIME_IN_SEC="$( date +%s 2>/dev/null )"
    if [ $? -ne 0 -o "${CUR_TIME_IN_SEC}"x = "%s"x ] ; then
      THISRC=${__FALSE}
    fi
  fi

  if [ ${THISRC} = ${__TRUE} ] ; then
    if [ $# -ne 0 ] ; then
       while [ $# -ne 0 ] ; do
         eval "$1=${CUR_TIME_IN_SEC}"
         shift
       done
    else
       echo "${CUR_TIME_IN_SEC}"
    fi
  fi
  
  return ${THISRC}
}

# ----------------------------------------------------------------------
# runcmd_with_timeout
#
# function: run a function or command with timeout
#
# usage: runcmd_with_timeout [timeout_value] [kill_signal] [cmd] [parameter]
#
# returns: 
#
#   the return code of the function is the return code of the program executed but only if the program finished before hitting the timeout.
#   If the program is killed by the timeout function the return code of the function is 249.
#   If the first parameter of the function is invalid the function ends with the return code 248
#
# parameter:
#
#   timeout_value
#     timeout value in seconds, use #m for minutes, #h for hours, or # or (optional) #s for seconds
#
#   kill_signal 
#     use "kill -${kill_signal}" to kill the command when the timeout is reached ("kill -9" is neccessary for example for some shell scripts)
#     default is kill with the standard signal to kill a process (which is 15)
#     kill_signal must be a number
#
#   cmd 
#     command to execute; the command can NOT be a number
#     "cmd" can be an external command or a function in the script
#
#   parameter 
#     parameter for the command to execute
#
# Be carefull with writing messages to STDOUT/STDERR or into the logfile of this script.
#
# Note:
#
# The function does NOT work in AIX
#
# Credits for this function
#    https://stackoverflow.com/questions/24412721/elegant-solution-to-implement-timeout-for-bash-commands-and-functions
#
function runcmd_with_timeout {
  typeset __FUNCTION="runcmd_with_timeout"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset TIMEOUT_PARAMETER=""
  typeset CUR_CMD=""
  typeset CUR_VAL=""
  typeset CHILD_PID=""
  typeset CHILD_PID2=""
  typeset TIMEOUT_MSG=""
  typeset FACTOR=""
  typeset KILL_SIGNAL=15
#
# process the parameter
#  
  TIMEOUT_PARAMETER="$1"
  shift
  
  if isNumber $1 ; then
    KILL_SIGNAL=$1
    shift
  fi
  
  CUR_CMD="$@"
  
  if [[ ${TIMEOUT_PARAMETER} == *h ]] ; then
    CUR_VAL="${TIMEOUT_PARAMETER%*h}"
    FACTOR=3600
    TIMEOUT_MSG=" (= ${CUR_VAL} hours(s))"
  elif [[ ${TIMEOUT_PARAMETER} == *m ]] ; then
    CUR_VAL="${TIMEOUT_PARAMETER%*m}"
    FACTOR=60
    TIMEOUT_MSG=" (= ${CUR_VAL} minutes(s))"
  elif [[ ${TIMEOUT_PARAMETER} == *s ]] ; then
    CUR_VAL="${TIMEOUT_PARAMETER%*s}"
    FACTOR=1
    TIMEOUT_MSG=""  
  elif isNumber "${TIMEOUT_PARAMETER}" ; then
    CUR_VAL="${TIMEOUT_PARAMETER}"
    FACTOR=1
    TIMEOUT_MSG=""
  fi
    
  if [ "${FACTOR}"x = ""x ] ; then
    LogError "Internal Error: ${__FUNCTION} called with an invalid parameter for the timeout: \"${TIMEOUT_PARAMETER}\" "
    THISRC=248
  else
    ((  CUR_TIMEOUT = CUR_VAL * FACTOR ))
    
    LogInfo "Using the signal ${KILL_SIGNAL} to kill the command if the timeout is reached"
    LogInfo "Executing now \"${CUR_CMD}\" with a timeout of ${CUR_TIMEOUT} seconds ${TIMEOUT_MSG}"

#
# start a sub shell
#
    ( 
        ${CUR_CMD} &
        CHILD_PID=$!
        LogInfo "The running cmd is: $( ps -f -p ${CHILD_PID} | tail -1  )"
        trap -- "" SIGTERM 
#
# start a background process to kill the command after # seconds
#        
        (                       
          sleep ${CUR_TIMEOUT}
          LogInfo "The process ${CHILD_PID} is still running after ${CUR_TIMEOUT} seconds -- will kill it now using the signal ${KILL_SIGNAL}"
          kill -${KILL_SIGNAL} ${CHILD_PID} 

        ) 1>/dev/null  &     
        CHILD_PID2=$!

#
# now wait for the command to finish
#        
        wait ${CHILD_PID}
#
# store the return code of the command executed in the background
#
        THISRC=$?

        LogInfo "${__FUNCTION} : The return code of the \"wait\" command is ${THISRC}"
#
# kill the background process used to wait and kill if it's still running
#        
        if  ps -p ${CHILD_PID2} >/dev/null ; then
          LogInfo "The temporary process for the timeout functionality (PID =  ${CHILD_PID2}) is still running -- will kill it now"
          kill -9 ${CHILD_PID2}
        else  
          THISRC=249
        fi

#
# exit the sub shell with the return code of the command executed with timoeut
#                
        exit ${THISRC}
    ) 

#
# exit the function runcmd_with_timeout with the return code of the executed command
#
    THISRC=$?
  fi
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# convert_variable_to_boolean
#
# function: convert the value of a variable to ${__TRUE} or ${__FALSE}
#
# usage: convert_variable_to_boolean VARIABLE_NAME
#        
# returns: ${__TRUE} - variable set to ${__TRUE}
#          ${__FALSE} - variable set to ${__FALSE}
#          100 - variable not changed
#          110 - variable is already ${__TRUE}
#          111 - variable is already ${__FALSE}
#
function convert_variable_to_boolean {
  typeset __FUNCTION="convert_variable_to_boolean"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=100

  typeset CUR_OUTPUT=""
  typeset TEMPRC=""

  typeset VAR_NAME="$1"
  
  typeset CUR_VALUE=""
  typeset NEW_VALUE=""
  
  if [ "${VAR_NAME}"x != ""x ] ; then
    eval "CUR_VALUE=\$${VAR_NAME}"
    LogInfo "${__FUNCTION}: The current value of the variable \"${VAR_NAME}\" is \"${CUR_VALUE}\" "
    
    CUR_VALUE="$( echo "${CUR_VALUE}" | tr "[a-z]"  "[A-Z]" )"
    
    case ${CUR_VALUE} in
      0  )
        THISRC=110
        ;;

      1 )
        THISRC=111
        ;;
        
      TRUE | YES  )
        NEW_VALUE=${__TRUE}
        ;;

      FALSE | NO )        
        NEW_VALUE=${__FALSE}
        ;;

    esac
    
    if [ "${NEW_VALUE}"x != ""x ] ; then
#
# change the variable
#    
      THISRC=${NEW_VALUE}
      eval "${VAR_NAME}=${NEW_VALUE}"

# check the result    
      eval "CUR_VALUE=\$${VAR_NAME}"
      LogInfo "${__FUNCTION}: The current value of the variable \"${VAR_NAME}\" is now \"${CUR_VALUE}\" "
      
    fi
  fi

  return ${THISRC}
}


# ----------------------------------------------------------------------
# is_variable_true
#
# function: check if the value of a variable is true
#
# usage: is_variable_true [var_value]
#
# returns: ${__TRUE} - ok, the variable is set to true
#          ${__FALSE} - the variable is not set to true
#          100 - the value of the variable is not known
#
#
function is_variable_true {
  typeset __FUNCTION="is_variable_true"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

# init the return code of the function
#
  typeset THISRC=${__TRUE}

  LogInfo "*** Function \"${__FUNCTION}\" started"

  case $1 in
    "0" | "yes" | "YES" | "Yes" | "true" | "TRUE" | "True" | ${__TRUE} )
      THISRC=${__TRUE}
      ;;

    "1" | "no" | "No" | "No" | "false" | "FALSE" | "False" | ${__FALSE} )
      THISRC=${__FALSE}
      ;;

     * | "" )
      THISRC=100
      ;;
  esac

  LogInfo "*** Function \"${__FUNCTION}\" ended ; RC = ${THISRC}"

  return ${THISRC}
}


# ----------------------------------------------------------------------
# helper function to restore the return code of the last command for the 
# code for enabling the debug code
#
function __return {
  \return $1
}

# ----------------------------------------------------------------------
# __enable_trace_for_functions
#
# enable trace for functions
#
# Usage: __enable_trace_for_functions
#
# returns: ${__TRUE}
#
function __enable_trace_for_functions {
  typeset __FUNCTION="__enable_trace_for_functions"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}
  
  typeset THISRC=${__TRUE}
  typeset FUNCTIONS_TO_TRACE="$*"
  typeset CUR_STATEMENT=""
  typeset CUR_VALUE=""
  typeset ADD_CODE=""
  
  if [ "${FUNCTIONS_TO_TRACE}"x != ""x ] ; then
    CUR_STATEMENT="[ 0 = 1 "

    if [ "${__KSH_VERSION}"x = "93"x -a ${USE_ONLY_KSH88_FEATURES} = ${__FALSE} ] ; then
      CUR_STATEMENT="__FUNCTION=\"\${.sh.fun}\" ; ${CUR_STATEMENT}"
    fi

#    __FUNCTIONS_WITH_DEBUG_CODE=""
    FUNCTION_LIST="$( __evaluate_fn "${FUNCTIONS_TO_TRACE}" )"
    for CUR_VALUE in ${FUNCTION_LIST} ; do
      LogMsg "Enabling trace for the function \"${CUR_VALUE}\" ..."

      if [[ ${__FUNCTIONS_WITH_DEBUG_CODE} == *\ ${CUR_VALUE}\ * ]] ; then
        "printf" "Debug code is already enabled for the function ${CUR_VALUE}"
        continue
      fi
    
      CUR_STATEMENT="${CUR_STATEMENT} -o \"\$0\"x = \"${CUR_VALUE}\"x -o \"\${__FUNCTION}\"x = \"${CUR_VALUE}\"x  "

       __FUNCTIONS_WITH_DEBUG_CODE="${__FUNCTIONS_WITH_DEBUG_CODE} ${CUR_VALUE} "

      if ! typeset +f "${CUR_VALUE}" >/dev/null ; then
        LogMsg "The function \"${CUR_VALUE}\" is not defined"
        continue
      fi

      if [ "${TYPESET_F_SUPPORTED}"x != "yes"x ] ; then
        :
      elif [[ $( typeset -f "${CUR_VALUE}" 2>&1 ) != *\$\{__DEBUG_CODE\}* ]] ; then
        LogMsg "Adding debug code to the function \"${CUR_VALUE}\" ..."           
        ADD_CODE=" typeset __FUNCTION=${CUR_VALUE}; "
        eval "$( typeset -f  "${CUR_VALUE}" | sed "1 s/{/\{ ${ADD_CODE}\\\$\{__DEBUG_CODE\}\;/" )"                        
      else
        LogMsg "\"${CUR_VALUE}\" already contains debug code."      
      fi
    done
    CUR_STATEMENT="eval ${CUR_STATEMENT} ] && printf \"\n*** Enabling trace for the function \${__FUNCTION:=\$0} ...\n\" >&2 && set -x "

    if [ "${__DEBUG_CODE}"x != ""x ] ; then
      
      if [[ "${__DEBUG_CODE}" == *\; ]] ; then
        __DEBUG_CODE="${__DEBUG_CODE}    ${CUR_STATEMENT} "
      else
        __DEBUG_CODE="${__DEBUG_CODE}  ; ${CUR_STATEMENT} "
      fi

    else
      __DEBUG_CODE="${CUR_STATEMENT}"
    fi
  
    if [ "${TRACE_FEATURE_SUPPORTED}"x != "yes"x ] ; then
      LogWarning "The tracing features are only supported using the local variable __FUNCTION by this shell"
    fi
  
    if [ "${TYPESET_F_SUPPORTED}"x != "yes"x ] ; then
      LogWarning "\"typeset -f\" is not supported by this shell - can not check or add the debug code to the functions"
    fi

  fi
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# __enable_verbose_for_functions
#
# enable verbose mode for functions
#
# Usage: __enable_verbose_for_functions
#
# returns: ${__TRUE}
#
function __enable_verbose_for_functions {
  typeset __FUNCTION="__enable_verbose_for_functions"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}
  
  typeset THISRC=${__TRUE}
  typeset FUNCTIONS_TO_TRACE="$*"
  typeset CUR_STATEMENT=""
  typeset CUR_VALUE=""
  typeset ADD_CODE=""
  
  if [ "${FUNCTIONS_IN_VERBOSE}"x != ""x ] ; then
    CUR_STATEMENT="[ 0 = 1 "

    if [ "${__KSH_VERSION}"x = "93"x -a ${USE_ONLY_KSH88_FEATURES} = ${__FALSE} ] ; then
      CUR_STATEMENT="__FUNCTION=\"\${.sh.fun}\" ; ${CUR_STATEMENT}"
    fi

#    __FUNCTIONS_IN_VERBOSE_MODE=""
    FUNCTION_LIST="$( __evaluate_fn "${FUNCTIONS_TO_TRACE}" )"
    for CUR_VALUE in ${FUNCTION_LIST} ; do
      LogMsg "Enabling verbose mode for the function \"${CUR_VALUE}\" ..."

      if [[ ${__FUNCTIONS_IN_VERBOSE_MODE} == *\ ${CUR_VALUE}\ * ]] ; then
        "printf" "Debug code is already enabled for the function ${CUR_VALUE}"
        continue
      fi
    
      CUR_STATEMENT="${CUR_STATEMENT} -o \"\$0\"x = \"${CUR_VALUE}\"x -o \"\${__FUNCTION}\"x = \"${CUR_VALUE}\"x  "

       __FUNCTIONS_IN_VERBOSE_MODE="${__FUNCTIONS_IN_VERBOSE_MODE} ${CUR_VALUE} "

      if ! typeset +f "${CUR_VALUE}" >/dev/null ; then
        LogMsg "The function \"${CUR_VALUE}\" is not defined"
        continue
      fi

      if [ "${TYPESET_F_SUPPORTED}"x != "yes"x ] ; then
        :
      elif [[ $( typeset -f "${CUR_VALUE}" 2>&1 ) != *\$\{__DEBUG_CODE\}* ]] ; then
        LogMsg "Adding debug code to the function \"${CUR_VALUE}\" ..."           
        ADD_CODE=" typeset __FUNCTION=${CUR_VALUE}; "
        eval "$( typeset -f  "${CUR_VALUE}" | sed "1 s/{/\{ ${ADD_CODE}\\\$\{__DEBUG_CODE\}\;/" )"                        
      else
        LogMsg "\"${CUR_VALUE}\" already contains debug code."      
      fi
    done

# __DEBUG_CODE="eval typeset __VERBOSE=\${VERBOSE} ; [[ \${FUNCTIONS_IN_VERBOSE_MODE}  == \${__FUNCTION} ]] && VERBOSE=\${__TRUE} ||  unset __VERBOSE ; ${__DEBUG_CODE} "
        
    CUR_STATEMENT="eval ${CUR_STATEMENT} ] && printf \"\n*** Enabling verbose mode for the function \${__FUNCTION:=\$0} ...\n\" >&2 && eval typeset __VERBOSE=\${VERBOSE} && VERBOSE=\${__TRUE} ||  unset __VERBOSE ; "
    
    __CODE_TO_ENABLE_VERBOSE_MODE="${CUR_STATEMENT}"
    
    if [ "${__DEBUG_CODE}"x != ""x ] ; then
      if [[ "${__DEBUG_CODE}" == *\; ]] ; then
        __DEBUG_CODE="${__DEBUG_CODE}  ${CUR_STATEMENT}  "
      else
        __DEBUG_CODE="${__DEBUG_CODE} ; ${CUR_STATEMENT} "
      fi
    else
      __DEBUG_CODE="${CUR_STATEMENT}"
    fi
  
    if [ "${TRACE_FEATURE_SUPPORTED}"x != "yes"x ] ; then
      LogWarning "Enabling verbose mode is only supported using the local variable __FUNCTION by this shell"
    fi
  
    if [ "${TYPESET_F_SUPPORTED}"x != "yes"x ] ; then
      LogWarning "\"typeset -f\" is not supported by this shell - can not check or add the debug code to the functions"
    fi

  fi
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# create_directory
#
# function: create a directory
#
# usage: create_directory [directory_name]
#
# returns: ${__TRUE} - directory successfully created
#          ${__FALSE} - error creating the directory
#
# Notes:
# 
#
function create_directory {
  typeset __FUNCTION="create_directory"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CUR_OUTPUT=""
  typeset TEMPRC=""

  typeset CUR_DIR=""
  
  while [ $# -ne 0 ] ; do
    CUR_DIR="$1"
    shift
    LogMsg "Creating the directory \"${CUR_DIR}\" ..." 

    CUR_OUTPUT="$( mkdir -p "${CUR_DIR}" 2>&1 )"
    if [ $? -ne 0 ] ; then
      LogMsg "-" "${CUR_OUTPUT}"
      LogError "Can not create the directory \"${CUR_DIR}\" "
      THISRC=${__FALSE}
      break
    fi
  done
  

#
# use \return ${THISRC} to ignore an alias defined for return
# 
  return ${THISRC}
}


# ----------------------------------------------------------------------
# function_template
#
# function: 
#
# usage: 
#
# returns: ${__TRUE} - 
#          ${__FALSE} - 
#
#
function function_template {
  typeset __FUNCTION="function_template"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CUR_OUTPUT=""
  typeset TEMPRC=""

# add your code here

  return ${THISRC}
}

# ----------------------------------------------------------------------
# list_magisk_settings
#
# function:  list the Magisk settings
#
# usage: list_magisk_settings.sh
#
# returns: ${__TRUE} - 
#          ${__FALSE} - 
#
#
function list_magisk_settings {
  typeset __FUNCTION="list_magisk_settings"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
 
  cat >"${TMPFILE1}" <<-\EOT
  
  grep ' / ' /proc/mounts | grep -qv 'rootfs' && SYSTEM_ROOT=true
  cd /data/adb/magisk
  . ./util_functions.sh
  get_flags
  echo -------------------------
  echo "SYSTEM_ROOT:       $SYSTEM_ROOT"
  echo "KEEPVERITY:        $KEEPVERITY"
  echo "KEEPFORCEENCRYPT:  $KEEPFORCEENCRYPT"
  echo "RECOVERYMODE:      $RECOVERYMODE"
  echo "PATCHVBMETAFLAG:   $PATCHVBMETAFLAG"
  echo "ISENCRYPTED:       $ISENCRYPTED"
  echo "VBMETAEXIST:       $VBMETAEXIST"
EOT

  ${GLOBAL_ROOT_PREFIX} sh "${TMPFILE1}"
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# search_help_script
#
# function: search a helper script or executable
#
# usage: search_help_script [scriptname]
#
# returns: ${__TRUE} - the fully qualified scriptname is written to STDOUT
#          ${__FALSE} - script not found; an empty string is written to STDOUT
#
#
function search_help_script {
  typeset __FUNCTION="search_help_script"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__FALSE}

  typeset SCRIPT_NAME="$*"

  typeset SCRIPT_FULL_NAME=""

# the directory for binaries used in most of my Magisk modules
#
  typeset USR_BIN="/system/usr/bin"
  
# the directory with binaries from the clang19 toolchain
#
  typeset CLANG19_SYSROOT_USR_BIN="/data/local/tmp/sysroot/usr/bin"

      
  if [ "${SCRIPT_FULL_NAME}"x  = ""x ] ; then
    SCRIPT_FULL_NAME="$( which "${SCRIPT_NAME}" )"
    THISRC=${__TRUE}
  fi 

  if [ "${SCRIPT_FULL_NAME}"x  = ""x ] ; then  
    if [ -x "${PWD}/${SCRIPT_NAME}" ] ; then
      SCRIPT_FULL_NAME="${PWD}/${SCRIPT_NAME}"
      THISRC=${__TRUE}
    fi
  fi

  if [ "${SCRIPT_FULL_NAME}"x  = ""x ] ; then  
    if [ -x "${REAL_SCRIPTDIR}/${SCRIPT_NAME}" ] ; then
      SCRIPT_FULL_NAME="${REAL_SCRIPTDIR}/${SCRIPT_NAME}"
      THISRC=${__TRUE}
    fi
  fi



  if [ "${SCRIPT_FULL_NAME}"x  = ""x ] ; then  
    if [ -x "${USR_BIN}/${SCRIPT_NAME}" ] ; then
      SCRIPT_FULL_NAME="${USR_BIN}/${SCRIPT_NAME}"
      THISRC=${__TRUE}
    fi
  fi

  if [ "${SCRIPT_FULL_NAME}"x  = ""x ] ; then  
    if [ -x "${CLANG19_SYSROOT_USR_BIN}/${SCRIPT_NAME}" ] ; then
      SCRIPT_FULL_NAME="${CLANG19_SYSROOT_USR_BIN}/${SCRIPT_NAME}"
      THISRC=${__TRUE}
    fi
  fi

  echo "${SCRIPT_FULL_NAME}"
  
  return ${THISRC}
}

# ----------------------------------------------------------------------
# copy_config_file
#
# function: copy a config file
#
# usage: copy_config_file [file] [target_directory|target_file]

#
# returns: ${__TRUE} - file successfuly copied
#          ${__FALSE} - error copying the file
#
#
function copy_config_file {
  typeset __FUNCTION="copy_config_file"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CUR_OUTPUT=""
  typeset TEMPRC=""

  typeset CUR_FILE="$1"
  typeset CUR_TARGET="$2"
  
  [[ -d "${CUR_TARGET}"  && "${CUR_TARGET}" != */ ]] &&  CUR_TARGET="${CUR_TARGET}/"
  
  LogMsg "  Copying the file \"${CUR_FILE}\" to \"${CUR_TARGET}\" ..."
  CUR_OUTPUT="$( ${ROOT_PREFIX} cp "${CUR_FILE}" "${CUR_TARGET}" 2>&1 )"
  if [ $? -ne 0 ] ; then
    LogMsg "-" "${CUR_OUTPUT}"
    LogError "Error copying the file \"${CUR_FILE}\" to \"${CUR_TARGET}\" "
    THISRC=${__FALSE}
  fi

  return ${THISRC}
}

# ----------------------------------------------------------------------
# execute_command
#
# function: execute a command and write the output to a logfile
#
# usage: execute_command [command] [logfile] [prefix]
#
# returns: return code of the executed commmand or 254 if the function was called with invalid parameter
#
#
function execute_command {
  typeset __FUNCTION="execute_command"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=0

  typeset CMD="$1"
  typeset CUR_LOG_FILE="$2"
  typeset ROOT_PREFIX="$3"
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""

  if [ $# -eq 2 -o $# -eq 3 ] ; then
    LogMsg "."  "  Writing the output of the command \"${CMD}\" to the file \"${CUR_LOG_FILE}\" "
    CUR_OUTPUT="$( ( ${ROOT_PREFIX} eval ${CMD}  >"${CUR_LOG_FILE}" ) 2>&1 )"
    THISRC=$?

    LogMsg "-" "... (RC=${THISRC})"

    if [ ${THISRC} -ne 0 ] ; then
      echo "
----
${CUR_OUTPUT}
---
" 2>/dev/null >>"${CUR_LOG_FILE}"

    fi
  else
    LogError "{__FUNCTION} -- ERROR: Invalid number of parameter: \"$*\" "
    THISRC=254
  fi

  return ${THISRC}
}
  

# ----------------------------------------------------------------------
# module_anr
#
# function: Collect the infos about anr
#
# usage: module_anr
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_anr {
  typeset __FUNCTION="module_anr"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset FILE_LIST=""
  typeset CUR_FILE=""
  typeset i=0
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"

# ----------------------------------------------------------------------
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

# ----------------------------------------------------------------------

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then

    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ] ; then

      RC_FILES="$( ${ROOT_PREFIX} find /data/anr -type f  2>/dev/null )"
  
      for CUR_FILE in ${RC_FILES} ; do
         CUR_DIR="${CUR_FILE%/*}"
       
        CUR_LOG_FILE="${MODULE_WORKDIR}/${CUR_FILE##*/}"
        CMD="cat  ${CUR_FILE}"
        execute_command "${CMD}" "${CUR_LOG_FILE}" "${ROOT_PREFIX}"
      done
    fi
  fi

# ----------------------------------------------------------------------

  return ${THISRC}
}



# ----------------------------------------------------------------------
# module_bugreport
#
# function: Collect the infos from the command bugreport
#
# usage: module_bugreport
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_bugreport {
  typeset __FUNCTION="module_bugreport"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset FILE_LIST=""
  typeset CUR_FILE=""
  typeset i=0
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"

# ----------------------------------------------------------------------
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

# ----------------------------------------------------------------------

  if which bugreportz >/dev/null ; then
    CMD="bugreportz -s"
    CUR_LOG_FILE="${MODULE_WORKDIR}/bugreport-$( getprop ro.product.name )-$( getprop ro.build.id ).$( date +%Y-%m-%d-%H-%M-%S ).zip"
    execute_command "${CMD}" "${CUR_LOG_FILE}" 
  elif which bugreport >/dev/null ; then
    CMD="bugreport  -s"
    CUR_LOG_FILE="${MODULE_WORKDIR}/bugreport-$( getprop ro.product.name )-$( getprop ro.build.id ).$( date +%Y-%m-%d-%H-%M-%S ).txt"
    execute_command "${CMD}" "${CUR_LOG_FILE}" 
  fi  

# ----------------------------------------------------------------------

  if which bugreport_procdump >/dev/null ; then
    CMD="bugreport_procdump"
    CUR_LOG_FILE="${MODULE_WORKDIR}/bugreport-procdump-$( getprop ro.product.name )-$( getprop ro.build.id ).$( date +%Y-%m-%d-%H-%M-%S ).txt"
    
    execute_command "${CMD}" "${CUR_LOG_FILE}" 
  fi
# ----------------------------------------------------------------------

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    CUR_LOG_FILE="${MODULE_WORKDIR}/xxxx.txt"
    :
  fi

# ----------------------------------------------------------------------

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ] ; then

      CUR_LOG_FILE="${MODULE_WORKDIR}/yyy.txt"
      CMD="ip ntable list"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

      :
    fi
  fi

# ----------------------------------------------------------------------

  return ${THISRC}
}


# ----------------------------------------------------------------------
# module_certificates
#
# function: Collect the infos about ceritficates
#
# usage: module_certificates
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_certificates {
  typeset __FUNCTION="module_certificates"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset FILE_LIST=""
  typeset CUR_FILE=""
  typeset i=0
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"

  typeset OPENSSL="$( search_help_script openssl )"

# ----------------------------------------------------------------------
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    if [ "${OPENSSL}"x  = ""x ] ; then
      LogWarning "openssl executable not found -- can not check any certificates"
      CONT=${__FALSE}
    elif [ ! -x "${OPENSSL}" ] ; then
      LogWarning "\"${OPENSSL}\" is not executable -- can not check any certificates"
      CONT=${__FALSE}
    fi
  fi
  

# ----------------------------------------------------------------------
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

# ----------------------------------------------------------------------

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    CUR_LOG_FILE="${MODULE_WORKDIR}/otacerts_certificate.txt"
    CMD="unzip -p /etc/security/otacerts.zip *.pem | /data/local/tmp/sysroot/usr/bin/openssl x509  -text     "
    execute_command "${CMD}" "${CUR_LOG_FILE}"  
  fi

# ----------------------------------------------------------------------

  return ${THISRC}
}


# ----------------------------------------------------------------------
# module_dumpsys
#
# function: Collect the infos from the command dumpsys
#
# usage: module_dumpsys
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_dumpsys {
  typeset __FUNCTION="module_dumpsys"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""

  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
  
    CUR_LOG_FILE="${MODULE_WORKDIR}/dumpsys_all.txt"
    CMD="dumpsys"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  
  
    for CUR_ENTRY in $( dumpsys -l | grep -v ":$" ) ; do

      CUR_LOG_FILE="${MODULE_WORKDIR}/dumpsys_${CUR_ENTRY//\//_}.txt"
      CMD="dumpsys ${CUR_ENTRY}"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  
      
    done
    
  fi

  return ${THISRC}
}


# ----------------------------------------------------------------------
# module_general
#
# function: Collect the infos about the installed OS
#
# usage: module_general
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_general {
  typeset __FUNCTION="module_general"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset CMD=""
  
  typeset IMPORTANT_PROPERTIES="
ro.system.build.type
ro.system.build.version.release
ro.product.build.date
ro.boot.slot_suffix

ro.build.fingerprint
ro.product.model
ro.product.device
ro.build.version.release
ro.build.version.sdk
ro.boot.verifiedbootstate
ro.boot.vbmeta.device_state
ro.boot.avb_version

ro.boot.flash.locked
ro.boot.verifiedbootstate
ro.boot.vbmeta.device_stat

init.svc.zygote
init.svc.surfaceflinger
init.svc.netd
init.svc.vold
init.svc.keystore2
init.svc.apexd

persist.sys.safemode
"  
  typeset CUR_PROPERTY=""
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/uname-a.txt"
    CMD="uname -a"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------
    
    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ]; then

      CUR_LOG_FILE="${MODULE_WORKDIR}/build.prop"
      CMD="cat /system/build.prop"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

    fi

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/getenforce.txt"
    CMD="getenforce"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/selinux_denied.txt"
    CMD='logcat -d | grep "avc:" '
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/safemode.txt"
    CMD=" dumpsys display | grep mSafeMode"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  


# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/top.txt"
    CMD="top -b -n 1"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/ps.txt"
    CMD="ps -A -o USER,PID,PPID,NAME,ARGS"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

        
# ----------------------------------------------------------------------
    
    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ]; then

      CUR_LOG_FILE="${MODULE_WORKDIR}/by-name_misc.txt"
      CMD="strings /dev/block/by-name/misc"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

    fi

# ----------------------------------------------------------------------
  
    LogMsg "  Writing the value of some important properties to the file \"${CUR_LOG_FILE}\" ..."
    
    for CUR_PROPERTY in ${IMPORTANT_PROPERTIES} ; do 

      CUR_LOG_FILE="${MODULE_WORKDIR}/${CUR_PROPERTY}.txt"
      CMD="getprop ${CUR_PROPERTY}"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  

    done

# ----------------------------------------------------------------------

    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ]; then

      CUR_LOG_FILE="${MODULE_WORKDIR}/proc_cmdline.txt"
      CMD="cat /proc/cmdline"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

    fi
  
# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/proc_version.txt"
    CMD="cat /proc/version"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  
  
# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/proc_cpuinfo.txt"
    CMD="cat /proc/cpuinfo"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  
  
# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/proc_meminfo.txt"
    CMD="cat /proc/meminfo"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  
  
# ----------------------------------------------------------------------

    if [ -r /proc/config.gz ] ; then

      CUR_LOG_FILE="${MODULE_WORKDIR}/kernel_config.txt"
      CMD="gzip -cd /proc/config.gz"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  
       
    else
      LogMsg "The kernel config file \"/proc/config.gz\" does not exist"
    fi      

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/service_list.txt"
    CMD="service list"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/cmd_l.txt"
    CMD="cmd -l"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/init_svc.txt"
    CMD="getprop | grep init.svc"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/dumpsys_dropbox.txt"
    CMD="dumpsys dropbox"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/dumpsys_dropbox_file.txt"
    CMD="dumpsys dropbox --file"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/dumpsys_dropbox_print.txt"
    CMD="dumpsys dropbox --print"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/dumpsys_stats.txt"
    CMD="dumpsys stats"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------

  fi
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# module_list_packages
#
# function: Collect the infos about directories with the applications
#
# usage: module_list_packages
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_list_packages {
  typeset __FUNCTION="module_list_packages"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset FILE_LIST=""
  typeset CUR_FILE=""

  typeset FILE_CONTENT=""
  typeset PACKAGE_LIST=""
  typeset CUR_PACKAGE=""
  typeset i=0
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then

    CUR_LOG_FILE="${MODULE_WORKDIR}/pm_list_packges_f.txt"
    CMD="pm list packages -f | sed 's/apk=/apk   -> /g'"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

    CUR_LOG_FILE="${MODULE_WORKDIR}/dumpsys_package.txt"
    CMD="dumpsys package"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

  fi
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# module_logs
#
# function: Collect the logcat, dmesg, and other log files 
#
# usage: module_logs
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_logs {
  typeset __FUNCTION="module_logs"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""

  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"
  
  typeset OTHER_LOGS=""
  typeset LOG_TYPE=""
    
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then

    CUR_LOG_FILE="${MODULE_WORKDIR}/logcat.txt"
    CMD="logcat -d"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

    CUR_LOG_FILE="${MODULE_WORKDIR}/logcat_selinux.txt"
    CMD="logcat -d | grep -i avc"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

    for LOG_TYPE in crash system main events ; do

      CUR_LOG_FILE="${MODULE_WORKDIR}/logcat.txt"
      CMD="logcat -b ${LOG_TYPE} -d"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  
    done
 
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    
    OTHER_LOGS="$( ls /data/local/tmp/*.log )"

    if [ "${OTHER_LOGS}"x != ""x ] ; then
      create_directory "${MODULE_WORKDIR}/other_logs" || THISRC=${__FALSE}
        
      for CUR_FILE in ${OTHER_LOGS} ; do
        CUR_LOG_FILE="${MODULE_WORKDIR}/other_logs/${CUR_FILE##*/}"
        CMD="cat ${CUR_FILE}"
        execute_command "${CMD}" "${CUR_LOG_FILE}"  
    
      done
    fi
  fi
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ] ; then

      CUR_LOG_FILE="${MODULE_WORKDIR}/dmesg.txt"
      CMD="dmesg -T"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

      OTHER_LOGS="$( ${ROOT_PREFIX} find /data/cache -type f -name "*.log" )"
      if [ "${OTHER_LOGS}"x != ""x ] ; then
        create_directory "${MODULE_WORKDIR}/data_cache" || THISRC=${__FALSE}

        for CUR_FILE in ${OTHER_LOGS} ; do
          CUR_LOG_FILE="${MODULE_WORKDIR}/data_cache/${CUR_FILE//\//_}"
          CMD="cat ${CUR_FILE}"
          execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"
    
        done
      fi


      CUR_LOG_FILE="${MODULE_WORKDIR}/sys_fs_pstore.txt"
#      CMD="ls -lhz /sys/fs/pstore/ "
      CMD='ls -ldZ $( find /sys/fs/pstore )'
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"


      OTHER_LOGS="$( ${ROOT_PREFIX} find /sys/fs/pstore/ -type f )"
      if [ "${OTHER_LOGS}"x != ""x ] ; then
        create_directory "${MODULE_WORKDIR}/sys_fs_pstore" || THISRC=${__FALSE}

        for CUR_FILE in ${OTHER_LOGS} ; do
          CUR_LOG_FILE="${MODULE_WORKDIR}/sys_fs_pstore/${CUR_FILE//\//_}"
          CMD="cat ${CUR_FILE}"
          execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"
    
        done
      fi

    fi

  fi

  return ${THISRC}
}

# ----------------------------------------------------------------------
# module_magisk
#
# function: Collect the infos about an installed Magisk
#
# usage: module_magisk
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_magisk {
  typeset __FUNCTION="module_magisk"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}

  typeset CUR_OUTPUT=""
  typeset TEMPRC=""

  typeset CUR_DIR=
  typeset CUR_FILE=

  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"
    
  typeset MAGISK="$( which magisk )"
  typeset MAGISK_PACKAGE=""

  typeset GRANTED=""
  typeset UID=""
  typeset MAGISK_DB_TABLES=""
  typeset CUR_TABLE=""
  typeset MAGISK_MODULE_LIST=""
  typeset MAGISK_MODULES_WORKDIR=""
  typeset CUR_MODULE_NAME=""
  typeset CUR_MAGISK_MODULE=""
  
  typeset CUR_MAGISK_MODULE_WORKDIR=""
  typeset CUR_MODULE_UPDATE_DIR=""

  typeset LMM="$( search_help_script lmm )"
  
  typeset MAGISK_ROOT_PERMISSIONS="$( search_help_script list_magisk_root_permissions.sh )"
  
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    if [ "${MAGISK}"x = ""x ] ; then
      LogMsg "No magisk binary found"
      CONT=${__FALSE}
    fi      
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then

    CUR_LOG_FILE="${MODULE_WORKDIR}/magisk_c.txt"
    CMD="${MAGISK} -c"
    execute_command "${CMD}" "${CUR_LOG_FILE}"

    CUR_LOG_FILE="${MODULE_WORKDIR}/magisk_V.txt"
    CMD="${MAGISK} -V"
    execute_command "${CMD}" "${CUR_LOG_FILE}"
  
    CUR_LOG_FILE="${MODULE_WORKDIR}/magisk_package.txt"
    CMD='pm list packages | grep magisk | cut -f2 -d ":" '
    execute_command "${CMD}" "${CUR_LOG_FILE}"

    MAGISK_PACKAGE="$( cat ${MODULE_WORKDIR}/magisk_package.txt )"

    CUR_LOG_FILE="${MODULE_WORKDIR}/magisk_package_dump.txt"
    CMD="pm dump ${MAGISK_PACKAGE} "
    execute_command "${CMD}" "${CUR_LOG_FILE}"

    CUR_LOG_FILE="${MODULE_WORKDIR}/magisk_path.txt"
    CMD="${ROOT_PREFIX} ${MAGISK} --path "
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    MAGISK_PATH="$( cat ${MODULE_WORKDIR}/magisk_path.txt )"
  fi


  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then

    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ] ; then

      CUR_LOG_FILE="${MODULE_WORKDIR}/magisk_path_ls.txt"
      CMD="find  ${MAGISK_PATH} -exec ls -ldZ {} + "
      execute_command "${CMD}" "${CUR_LOG_FILE}" "${ROOT_PREFIX}"

      CUR_LOG_FILE="${MODULE_WORKDIR}/magisk_logfile_ls.txt"
      CMD="ls -ldZ /cache/magisk.log " 
      execute_command "${CMD}" "${CUR_LOG_FILE}" "${ROOT_PREFIX}"
 
      CUR_LOG_FILE="${MODULE_WORKDIR}/magisk_logfile_contents.txt"
      CMD="cat /cache/magisk.log" 
      execute_command "${CMD}" "${CUR_LOG_FILE}" "${ROOT_PREFIX}"

      CUR_LOG_FILE="${MODULE_WORKDIR}/magisk_settings.txt"
      CMD="list_magisk_settings" 
      execute_command "${CMD}" "${CUR_LOG_FILE}" 

      if ${ROOT_PREFIX} test -f "/data/adb/magisk.db" ; then

        CUR_LOG_FILE="${MODULE_WORKDIR}/magisk_database_ls.txt"
        CMD="ls -ldZ /data/adb/magisk.db "
        execute_command "${CMD}" "${CUR_LOG_FILE}" "${ROOT_PREFIX}"

 
        if [ "${ROOT_PREFIX}"x != ""x ] ; then
          TMP_PREFIX="${ROOT_PREFIX}"
        else
          TMP_PREFIX="su - ${CUR_USER_NAME} -c "
        fi

        MAGISK_DB_TABLES="$( ${TMP_PREFIX} ${MAGISK} "--sqlite 'select name FROM sqlite_master WHERE type=\"table\" ' "  | cut -f2 -d= )"

        CUR_LOG_FILE="${MODULE_WORKDIR}/magisk_database_db_tables.txt"
        LogMsg "  Writing the list of tables in the Magisk database table to the file \"${CUR_LOG_FILE}\" ..."
        echo "${MAGISK_DB_TABLES}" >"${CUR_LOG_FILE}"

        for CUR_TABLE in ${MAGISK_DB_TABLES} ; do
  
          CUR_LOG_FILE="${MODULE_WORKDIR}/magisk_database_table_${CUR_TABLE}.txt"
          MAGISK_DB_TABLE="$( ${TMP_PREFIX} "${MAGISK} --sqlite 'select * FROM ${CUR_TABLE} ' " )"
          LogMsg "  Writing the contents of the Magisk database table \"${CUR_TABLE}\" to the file \"${CUR_LOG_FILE}\" ..."
          echo "${MAGISK_DB_TABLE}" >"${CUR_LOG_FILE}"

        done

        if [ "${MAGISK_ROOT_PERMISSIONS}"x != ""x ] ; then
          CUR_LOG_FILE="${MODULE_WORKDIR}/magisk_root_access.txt"
          CMD="${MAGISK_ROOT_PERMISSIONS}"
          execute_command "${CMD}" "${CUR_LOG_FILE}" "${ROOT_PREFIX}" 
        fi


        for CUR_DIR in  /data/adb/post-fs-data.d /data/adb/service.d ; do

          LogMsg "-"
          LogMsg "Processing the directory \"${CUR_DIR}\" ..."
          
          CUR_OUTPUT="$( ${ROOT_PREFIX} ls -lZ ${CUR_DIR} 2>&1 )"

          CUR_LOG_FILE="${MODULE_WORKDIR}/${CUR_DIR##*/}_ls.txt"
          CMD="ls -lZ ${CUR_DIR} "
          execute_command "${CMD}" "${CUR_LOG_FILE}" "${ROOT_PREFIX}"

          FILE_LIST="$( ${ROOT_PREFIX} ls ${CUR_DIR}/* 2>/dev/null )"
          if [ "${FILE_LIST}"x != ""x ] ; then
            create_directory "${MODULE_WORKDIR}/${CUR_DIR##*/}" 
            for CUR_FILE in ${FILE_LIST} ; do
              copy_config_file "${CUR_FILE}"   "${MODULE_WORKDIR}/${CUR_DIR##*/}"
            done
          fi
        done
  
        if [ "${LMM}"x != ""x ] ; then

          LogMsg "-"

          CUR_LOG_FILE="${MODULE_WORKDIR}/lmm.txt"
          CMD=""${LMM}""
          execute_command "${CMD}" "${CUR_LOG_FILE}" "${ROOT_PREFIX}"

        fi

        LogMsg "-"
        LogMsg "Processing the Magisk modules ..."

        CUR_LOG_FILE="${MODULE_WORKDIR}/magisk_module.lst"
        CMD=" ls -aZdl /data/adb/modules/* "
        execute_command "${CMD}" "${CUR_LOG_FILE}" "${ROOT_PREFIX}"

        MAGISK_MODULE_LIST="$( ${ROOT_PREFIX} ls -1d /data/adb/modules/* )"
                     
        MAGISK_MODULES_WORKDIR="${MODULE_WORKDIR}/magisk_modules" 
        create_directory "${MAGISK_MODULES_WORKDIR}" 

        for CUR_MAGISK_MODULE in ${MAGISK_MODULE_LIST} ; do
          
          CUR_MODULE_NAME="${CUR_MAGISK_MODULE##*/}"

          CUR_MODULE_UPDATE_DIR="/data/adb/modules_updates/${CUR_MODULE_NAME}"
          LogMsg "-"
          
          LogMsg "Processing the Magisk Module \"${CUR_MODULE_NAME}\" ..."
   
          CUR_MAGISK_MODULE_WORKDIR="${MAGISK_MODULES_WORKDIR}/${CUR_MODULE_NAME}"
          create_directory "${CUR_MAGISK_MODULE_WORKDIR}"
               
          CUR_LOG_FILE="${CUR_MAGISK_MODULE_WORKDIR}/magisk_module_${CUR_MODULE_NAME}_ls.txt"
          CMD=" ls -ladZ \"${CUR_MAGISK_MODULE}/\"*  "
          execute_command "${CMD}" "${CUR_LOG_FILE}" "${ROOT_PREFIX}"
  
          LogMsg "Copying the config files and scripts from the Magisk module \"${CUR_MODULE_NAME}\" to \"${CUR_MAGISK_MODULE_WORKDIR}\" ..."
          for CUR_FILE in module.prop service.sh action.sh post-fs-data.sh ; do 
            ${ROOT_PREFIX} test -r "${CUR_MAGISK_MODULE}/${CUR_FILE}" && copy_config_file "${CUR_MAGISK_MODULE}/${CUR_FILE}" "${CUR_MAGISK_MODULE_WORKDIR}"
          done

          CUR_LOG_FILE="${CUR_MAGISK_MODULE_WORKDIR}/magisk_module_${CUR_MODULE_NAME}_filelist.txt"
          CMD=" find ${CUR_MAGISK_MODULE} -exec ls -lZd {} +  "
          execute_command "${CMD}" "${CUR_LOG_FILE}" "${ROOT_PREFIX}"

        done

      fi        
    fi

  fi
  LogMsg "-"
  
  return ${THISRC}
}

 
# ----------------------------------------------------------------------
# module_microg
#
# function: Collect the infos about MicroG
#
# usage: module_microg
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_microg {
  typeset __FUNCTION="module_microg"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset FILE_LIST=""
  typeset CUR_FILE=""
  typeset CUR_DIR=""
  typeset i=0
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"

  typeset AAPT="$( search_help_script aapt )"
  [ "${AAPT}"x = ""x ] && AAPT="$( search_help_script aapt2 )"


# ----------------------------------------------------------------------
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi


# ----------------------------------------------------------------------

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then

    CUR_LOG_FILE="${MODULE_WORKDIR}/dumpsys_com_google_android_gms.txt"
    CMD='dumpsys package com.google.android.gms'
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    grep -i microg "${CUR_LOG_FILE}" 2>/dev/null 1>/dev/null
    if [ $? -ne 0 ] ; then
      LogMsg "MicroG is not installed"
      CONT=${__FALSE}
    else
      LogMsg "MicroG is installed"
    fi
  fi

# ----------------------------------------------------------------------

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then

    CUR_LOG_FILE="${MODULE_WORKDIR}/microg_processes.txt"
    CMD='ps -A | grep com.google.android.gms'
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    CUR_LOG_FILE="${MODULE_WORKDIR}/pm_path_com_google_android_gms.txt"
    CMD='pm path com.google.android.gms'
    execute_command "${CMD}" "${CUR_LOG_FILE}" 


    CUR_LOG_FILE="${MODULE_WORKDIR}/fake_package_signature.txt"
    CMD='pm list permissions | grep FAKE_PACKAGE_SIGNATURE'
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    CUR_LOG_FILE="${MODULE_WORKDIR}/spoof_permission.txt"
    CMD='pm list permissions -g -f | grep -i spoof'
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    CUR_LOG_FILE="${MODULE_WORKDIR}/microg_version.txt"
    CMD='pm dump com.google.android.gms | grep "versionCode" '
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    CUR_LOG_FILE="${MODULE_WORKDIR}/microg_logcat.txt"
    CMD='logcat -d | grep -iE "microg|gms|GmsCompat"'
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    CUR_LOG_FILE="${MODULE_WORKDIR}/dumpsys_package_com_android_vending.txt"
    CMD='dumpsys package com.android.vending'
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    CUR_LOG_FILE="${MODULE_WORKDIR}/pm_path_com_android_vending.txt"
    CMD='pm path com.android.vending'
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    CUR_FILE="$( cat "${CUR_LOG_FILE}"  | cut -f2 -d":" | tail -1  )"
    CUR_DIR="${CUR_FILE%/*}"
    
    if [ "${CUR_DIR}"x != ""x ] ; then
      CUR_LOG_FILE="${MODULE_WORKDIR}/pm_path_contents.txt"
      CMD="ls -ldZ \$( find ${CUR_DIR} )"
      execute_command "${CMD}" "${CUR_LOG_FILE}" 
      
      if  [ "${AAPT}"x != ""x ] ; then
        cd "${CUR_DIR}"
        for CUR_FILE in *apk ; do 
          CUR_LOG_FILE="${MODULE_WORKDIR}/aapt_dump_badging_${CUR_FILE}.txt"
          CMD="${AAPT} dump badging ${CUR_FILE}"
          execute_command "${CMD}" "${CUR_LOG_FILE}" 
        done

        CUR_LOG_FILE="${MODULE_WORKDIR}/apk_versions.txt"
        CMD="${AAPT} dump badging ${CUR_DIR}/*apk | grep -E '^package:|^application-label:' | sed 's/^package:/\npackage:/g' " 
        execute_command "${CMD}" "${CUR_LOG_FILE}" 
        
        cd -
      fi
    fi

  fi

# ----------------------------------------------------------------------

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ] ; then


      :
    fi
  fi

# ----------------------------------------------------------------------

  return ${THISRC}
}


# ----------------------------------------------------------------------
# module_network
#
# function: Collect the infos about the network config
#
# usage: module_network
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_network {
  typeset __FUNCTION="module_network"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset FILE_LIST=""
  typeset CUR_FILE=""
  typeset i=0
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/ifconfig.txt"
    CMD="ifconfig -a"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------

    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ] ; then

      CUR_LOG_FILE="${MODULE_WORKDIR}/iptables.txt"
      CMD="iptables -L"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"


      CUR_LOG_FILE="${MODULE_WORKDIR}/iptables_L_n_v.txt"
      CMD="iptables  -L -n -v"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

      CUR_LOG_FILE="${MODULE_WORKDIR}/iptables_t_nat_L_n_v.txt"
      CMD="iptables -t nat -L -n -v"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

      CUR_LOG_FILE="${MODULE_WORKDIR}/ip6tables_L_n_v.txt"
      CMD="ip6tables  -L -n -v"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

    fi

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/ip_addr_list.txt"
    CMD="ip addr list"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/ip_route_list.txt"
    CMD="ip route list"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/ip_rule_show.txt"
    CMD="ip rule show"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------

    CUR_LOG_FILE="${MODULE_WORKDIR}/ip_ntable_list.txt"
    CMD="ip ntable list"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

# ----------------------------------------------------------------------
# root access is optional for this command

    CUR_LOG_FILE="${MODULE_WORKDIR}/netstat_anp.txt"
    CMD="netstat -anp"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

# ----------------------------------------------------------------------
# root access is optional for this command

    CUR_LOG_FILE="${MODULE_WORKDIR}/ss.txt"
    CMD="ss"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

# ----------------------------------------------------------------------
# root access is optional for this command

    CUR_LOG_FILE="${MODULE_WORKDIR}/netstat_a.txt"
    CMD="netstat -a"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

  fi

# ----------------------------------------------------------------------

  return ${THISRC}
}


# ----------------------------------------------------------------------
# module_overlay_mounts
#
# function: Collect the infos about overlay mounts
#
# usage: module_overlay_mounts
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_overlay_mounts {
  typeset __FUNCTION="module_overlay_mounts"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset FILE_LIST=""
  typeset CUR_FILE=""
  typeset i=0
  typeset CUR_LOOP_DEVICE=""
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"

  typeset CREATE_OVERLAY_MOUNT=$( search_help_script "ceate_overlay_mount.sh" )
  
# ----------------------------------------------------------------------
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

# ----------------------------------------------------------------------
#  CUR_LOG_FILE="${MODULE_WORKDIR}/df_h_dev_ov.txt"
#  CMD="df -h /dev/ov"
#  execute_command "${CMD}" "${CUR_LOG_FILE}" 
#
# ----------------------------------------------------------------------

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    CUR_LOG_FILE="${MODULE_WORKDIR}/xxxx.txt"
    :
  fi

# ----------------------------------------------------------------------

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ] ; then

      if [ "${CREATE_OVERLAY_MOUNT}"x != ""x ] ; then
        CUR_LOG_FILE="${MODULE_WORKDIR}/create_overlay_mount.txt"
        CMD="${CREATE_OVERLAY_MOUNT} --verbose--details list "
        execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"
      fi

# find loop back devices mount on a file
#
      CUR_LOG_FILE="${MODULE_WORKDIR}/losetup_a.txt"

      LOOP_DEVICES="$( execute_command "losetup -a"  "${CUR_LOG_FILE}" "${ROOT_PREFIX}" )"
      
        while read CUR_LOOP_DEVICE_INFO ;do
          LogInfo "Processing the loop device \"${CUR_LOOP_DEVICE_INFO}\" ..."
          CUR_LOOP_DEVICE="$( echo "${CUR_LOOP_DEVICE_INFO}" | cut -f1 -d":" )"
          CUR_IMAGE_FILE="$( echo "${CUR_LOOP_DEVICE_INFO}" | tr '()' '##' | cut -f2 -d '#' )"
          CUR_MOUNT_POINT="$( df -h "${CUR_LOOP_DEVICE}" | tail -1 | sed "s#.* /#/#g" )"

          [ "${CUR_IMAGE_FILE}"x = ""x ] && continue

          LogMsg "Processing the loop device \"${CUR_LOOP_DEVICE_INFO}\" ..."

          cat >"${TMPFILE1}" <<EOT
echo          
echo "The loop device is \"${CUR_LOOP_DEVICE}\""
echo "The file used is \"${CUR_IMAGE_FILE}\" " 
echo "The mount point is \"${CUR_MOUNT_POINT}\""

echo
echo "*** ls -lhZ \"${CUR_IMAGE_FILE}\" "
ls -lhZ "${CUR_IMAGE_FILE}" 

echo
echo "*** ls -lZ \"${CUR_LOOP_DEVICE}\""
ls -lZ "${CUR_LOOP_DEVICE}"
echo

echo
echo "*** ls -ldZ \"${CUR_MOUNT_POINT}\""
ls -ldZ "${CUR_MOUNT_POINT}"
echo

EOT
          if [ "${CUR_MOUNT_POINT}"x != ""x ] ; then
            cat >>"${TMPFILE1}" <<EOT
echo "*** df -h \"${CUR_MOUNT_POINT}\" "
df -h "${CUR_MOUNT_POINT}"
echo

echo "*** mount | grep \"${CUR_MOUNT_POINT}\"  "
mount | grep "${CUR_MOUNT_POINT}"
echo

echo "*** ls -dZl \"${CUR_MOUNT_POINT}\"/* "
ls -dZl "${CUR_MOUNT_POINT}"/*
echo

echo "*** ls -dZl \"${CUR_MOUNT_POINT}\"/*/* "
ls -dZl "${CUR_MOUNT_POINT}"/*/*
echo

EOT
          fi

          CUR_LOG_FILE="${MODULE_WORKDIR}/file_loop_mounts_${CUR_LOOP_DEVICE##*/}.txt"
          CMD="sh ${TMPFILE1}"
          execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

        done <"${CUR_LOG_FILE}"
      
    fi
  fi

# ----------------------------------------------------------------------

  return ${THISRC}
}

# ----------------------------------------------------------------------
# module_pm
#
# function: Collect the infos from pm
#
# usage: module_pm
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_pm {
  typeset __FUNCTION="module_pm"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset FILE_LIST=""
  typeset CUR_FILE=""

  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"
  
  typeset CUR_PARAM=""
  
  typeset -a PARAM
  
  i=0
  (( i=i+1 )) ; PARAM[$i]="pm list features"
  (( i=i+1 )) ; PARAM[$i]="pm list instrumentation"
  (( i=i+1 )) ; PARAM[$i]="pm list libraries -v"
  (( i=i+1 )) ; PARAM[$i]="pm list packages -a -i -U --show-versioncode # all packages"
  (( i=i+1 )) ; PARAM[$i]="pm list packages -d -i -U --show-versioncode # disabled packages"
  (( i=i+1 )) ; PARAM[$i]="pm list packages -e -i -U --show-versioncode # enabled packages"
  (( i=i+1 )) ; PARAM[$i]="pm list packages -s -i -U --show-versioncode # system packages"
  (( i=i+1 )) ; PARAM[$i]="pm list packages -3 -i -U --show-versioncode # 3rd party packages"

  (( i=i+1 )) ; PARAM[$i]="pm list packages -a -i -U -u --show-versioncode # all packages including uninstalled packages"
  
  (( i=i+1 )) ; PARAM[$i]="pm list permission-groups"
  (( i=i+1 )) ; PARAM[$i]="pm list permission-groups -f"
  (( i=i+1 )) ; PARAM[$i]="pm list permission-groups -d"
  (( i=i+1 )) ; PARAM[$i]="pm list permission-groups -u"
  (( i=i+1 )) ; PARAM[$i]="pm list packages"
  (( i=i+1 )) ; PARAM[$i]="pm list permissions"
  (( i=i+1 )) ; PARAM[$i]="pm list permissions -f # print all information"
  (( i=i+1 )) ; PARAM[$i]="pm list permissions -d # only list dangerous permissions"
  (( i=i+1 )) ; PARAM[$i]="pm list permissions -u # list only permissions the users will see"

  (( i=i+1 )) ; PARAM[$i]="pm list users"
  (( i=i+1 )) ; PARAM[$i]="pm get-max-users"
  (( i=i+1 )) ; PARAM[$i]="pm get-max-running-users"
  
  (( i=i+1 )) ; PARAM[$i]="pm list packages"
  PARAM[0]=$i
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    i=0
    while [ $i -lt ${PARAM[0]} ] ; do
      (( i = i + 1 ))
      CUR_PARAM="${PARAM[$i]}"

      CUR_LOG_FILE="${MODULE_WORKDIR}/${CUR_PARAM// /_}.txt"
      CMD="${CUR_PARAM}"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  
      
    done
    
  fi

  return ${THISRC}
}

# ----------------------------------------------------------------------
# module_privapps
#
# function: Collect the infos about privileged apps
#
# usage: module_privapps
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_privapps {
  typeset __FUNCTION="module_privapps"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset FILE_LIST=""
  typeset CUR_FILE=""

  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then

    CUR_LOG_FILE="${MODULE_WORKDIR}/dirs_with_privileged_apps.txt"
    CMD="ls -ld /*/priv-app/* "
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

    CUR_LOG_FILE="${MODULE_WORKDIR}/privileged_apps.txt"
    CMD="ls -ld /*/priv-app/*/*apk "
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

    CUR_LOG_FILE="${MODULE_WORKDIR}/privileged_apps_size.txt"
    CMD="du -hs /*/priv-app/* "
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

  fi

  return ${THISRC}
}


# ----------------------------------------------------------------------
# module_apps
#
# function: Collect the infos about non-privileged apps
#
# usage: module_apps
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_apps {
  typeset __FUNCTION="module_apps"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset FILE_LIST=""
  typeset CUR_FILE=""

  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then

    CUR_LOG_FILE="${MODULE_WORKDIR}/dirs_with_non_privileged_apps.txt"
    CMD="ls -ld /*/app/* "
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

    CUR_LOG_FILE="${MODULE_WORKDIR}/non_privileged_apps.txt"
    CMD="ls -ld /*/app/*/*apk "
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

    CUR_LOG_FILE="${MODULE_WORKDIR}/non_privileged_apps_size.txt"
    CMD="du -hs /*/app/* "
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

  fi

  return ${THISRC}
}
# ----------------------------------------------------------------------
# module_properties
#
# function: Collect the infos about the properties
#
# usage: module_properties
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_properties {
  typeset __FUNCTION="module_properties"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then

    CUR_LOG_FILE="${MODULE_WORKDIR}/getprop_${CUR_USER_NAME}.txt"
    CMD="getprop"
    execute_command "${CMD}" "${CUR_LOG_FILE}"

  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} -a "${CUR_USER_NAME}"x != "root"x ] ; then

      CUR_LOG_FILE="${MODULE_WORKDIR}/getprop_root.txt"
      CMD="getprop"
      execute_command "${CMD}" "${CUR_LOG_FILE}" "${ROOT_PREFIX}"

    fi
  fi

  return ${THISRC}
}
 

# ----------------------------------------------------------------------
# module_rcfiles
#
# function: Collect the infos about .rc files
#
# usage: module_rcfiles
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_rcfiles {
  typeset __FUNCTION="module_rcfiles"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset FILE_LIST=""
  typeset CUR_FILE=""
  typeset i=0
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"

  typeset RC_FILES=""
  typeset CUR_DIR=""
  
# ----------------------------------------------------------------------
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi
  
# ----------------------------------------------------------------------

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    RC_FILES="$( find / -type f -name "*.rc"  2>/dev/null | grep -v "/data"  )"
  
    for CUR_FILE in ${RC_FILES} ; do
       CUR_DIR="${CUR_FILE%/*}"
    
      [ ! -d "${MODULE_WORKDIR}/${CUR_DIR}" ] && mkdir -p "${MODULE_WORKDIR}/${CUR_DIR}"
    
      CUR_LOG_FILE="${MODULE_WORKDIR}/${CUR_FILE}"
      CMD="cat  ${CUR_FILE}"
      execute_command "${CMD}" "${CUR_LOG_FILE}" 
    done
  fi


# ----------------------------------------------------------------------

  return ${THISRC}
}



# ----------------------------------------------------------------------
# module_settings
#
# function: Collect the infos from the command settings
#
# usage: module_settings
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_settings {
  typeset __FUNCTION="module_settings"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset CUR_ENTRY=""
  typeset CUR_OUTFILE=""
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"
  
  typeset CUR_FILE_TYPE=""
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
  
    for CUR_ENTRY in system secure global ; do
    
      CUR_LOG_FILE="${MODULE_WORKDIR}/settings_${CUR_ENTRY}.txt"
      CMD="settings list ${CUR_ENTRY}"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  
    
    done
    
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}/xml" || THISRC=${__FALSE}
  fi


  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then

    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ] ; then
  
      LogMsg "Copying the config files from \"/data/system/users/0\" to \"${MODULE_WORKDIR}/xml/\" ..."
      
      for CUR_ENTRY in $(  ${ROOT_PREFIX} find /data/system/users/0/ -name "*.xml" ) ;do
  
        CUR_LOG_FILE="${MODULE_WORKDIR}/${CUR_ENTRY##*/}"
        CUR_FILE_TYPE="$( ${ROOT_PREFIX} file "${CUR_ENTRY}" )"
  
        if [[ "${CUR_FILE_TYPE}" == *"Android Binary XML v0"* ]] ; then
          LogInfo "Converting the file \"${CUR_ENTRY}\" to the plain xml file \"${CUR_LOG_FILE}\" ..."
     
          CMD="abx2xml ${CUR_ENTRY} -"
        else
          CMD="cat ${CUR_ENTRY}"
        fi
        execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"
      done
    fi
  fi

  return ${THISRC}
}



# ----------------------------------------------------------------------
# module_storage
#
# function: Collect the infos about the storage
#
# usage: module_storage
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_storage {
  typeset __FUNCTION="module_storage"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}

  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"

  typeset LIST_LOGICAL_DEVICE_BACKENDS="$( search_help_script list_logical_device_backends.sh )"
  typeset LIST_LOGICAL_DEVICE_USAGE="$( search_help_script list_logical_device_usage.sh )"

  typeset CUR_LIST_OF_LOGICAL_DEVICES=""
  typeset CUR_LOGICAL_DEVICE=""
  typeset CUR_MOUNT_DIR=""

  typeset MOUNT_DYNAMIC_PARTITIONS=""
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then

    CUR_LOG_FILE="${MODULE_WORKDIR}/df-h.txt"
    CMD="df -h"
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    CUR_LOG_FILE="${MODULE_WORKDIR}/df-i.txt"
    CMD="df -i"
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    CUR_LOG_FILE="${MODULE_WORKDIR}/mount.txt"
    CMD="mount"
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    CUR_LOG_FILE="${MODULE_WORKDIR}/proc_mounts.txt"
    CMD="cat /proc/mounts"
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    CUR_LOG_FILE="${MODULE_WORKDIR}/overlay_mounts.txt"
    CMD='mount | grep ^overlay'
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    CUR_LOG_FILE="${MODULE_WORKDIR}/tmpfs_mounts.txt"
    CMD="mount | grep ^tmpfs"
    execute_command "${CMD}" "${CUR_LOG_FILE}" 

    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ]; then

      CUR_LOG_FILE="${MODULE_WORKDIR}/lsblk.txt"
      CMD="lsblk"
      execute_command "${CMD}" "${CUR_LOG_FILE}" 

      CUR_LOG_FILE="${MODULE_WORKDIR}/dev_block_by-name.txt"
      CMD="ls -lZ /dev/block/by-name "
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

      CUR_LOG_FILE="${MODULE_WORKDIR}/dev_block_mapper.txt"
      CMD="find /dev/block/mapper -exec ls -ldZ {} +"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

      CUR_LOG_FILE="${MODULE_WORKDIR}/dmctl_list_devices.txt"
      CMD="dmctl list devices "
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

      CUR_LIST_OF_LOGICAL_DEVICES="$( ${ROOT_PREFIX} dmctl list devices | tr "\t" " " | cut -f1 -d  " " )"

      for CUR_LOGICAL_DEVICE in ${CUR_LIST_OF_LOGICAL_DEVICES} ; do
        CUR_LOG_FILE="${MODULE_WORKDIR}/dmctl_table_${CUR_LOGICAL_DEVICE}.txt"
        CMD="dmctl table ${CUR_LOGICAL_DEVICE}"
        execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"
      done

      MOUNT_DYNAMIC_PARTITIONS="${MOUNT_DYNAMIC_PARTITIONS:=$( which mount_dynamic_partitions )}"
      [ "${MOUNT_DYNAMIC_PARTITIONS}"x = ""x -a -x /data/local/tmp/mount_dynamic_partitions ] && MOUNT_DYNAMIC_PARTITIONS=" /data/local/tmp/mount_dynamic_partitions"

      ${ROOT_PREFIX} which mount_dynamic_partitions >/dev/null
      if [ "${MOUNT_DYNAMIC_PARTITIONS}"x != ""x ]  ; then
      
        CUR_MOUNT_DIR="${MODULE_WORKDIR}/mount_dynamic_partitions"
        mkdir -p "${CUR_MOUNT_DIR}"
        
        CUR_LOG_FILE="${CUR_MOUNT_DIR}/dmctl_list_devices_advanced.txt"
        CMD="${MOUNT_DYNAMIC_PARTITIONS} --list-all "
        execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

        CUR_LOG_FILE="${CUR_MOUNT_DIR}/dmctl_list_devices_config_advanced.txt"
        CMD="${MOUNT_DYNAMIC_PARTITIONS} -o ${CUR_MOUNT_DIR} --mountdir ${CUR_MOUNT_DIR} --dry-run"
        execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

      fi

      CUR_LOG_FILE="${MODULE_WORKDIR}/lpdump.txt"
      CMD="lpdump"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

      CUR_LOG_FILE="${MODULE_WORKDIR}/rootdir.txt"
      CMD="ls -lZ / "
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

      CUR_LOG_FILE="${MODULE_WORKDIR}/data_misc_vold.txt"
      CMD='ls -ld $( ${ROOT_PREFIX} find /data/misc/vold/ )'
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"
      
    fi    

    CUR_LOG_FILE="${MODULE_WORKDIR}/crypto_state.txt"
    CMD="getprop | egrep 'crypto|verity'"
    execute_command "${CMD}" "${CUR_LOG_FILE}" 


    if [ "${LIST_LOGICAL_DEVICE_BACKENDS}"x != ""x ] ; then
      CUR_LOG_FILE="${MODULE_WORKDIR}/list_logical_device_backends.txt"
      CMD="${LIST_LOGICAL_DEVICE_BACKENDS}"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  
    fi


    if [ "${LIST_LOGICAL_DEVICE_USAGE}"x != ""x ] ; then
      CUR_LOG_FILE="${MODULE_WORKDIR}/list_logical_device_usage.txt"
      CMD="${LIST_LOGICAL_DEVICE_USAGE}"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  
    fi
    
  fi

  return ${THISRC}
}



# ----------------------------------------------------------------------
# module_tombstones
#
# function: Collect the infos about tombstones
#
# usage: module_tombstones
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_tombstones {
  typeset __FUNCTION="module_tombstones"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset FILE_LIST=""
  typeset CUR_FILE=""
  typeset i=0
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"

  typeset OTHER_LOGS=""
  
# ----------------------------------------------------------------------
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

# ----------------------------------------------------------------------

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then

    CUR_LOG_FILE="${MODULE_WORKDIR}/data_tombstones.txt"
    CMD='ls -ldZ $( find /data/tombstones )'
    execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

    OTHER_LOGS="$(  find /data/tombstones -type f )"
    if [ "${OTHER_LOGS}"x != ""x ] ; then
      create_directory "${MODULE_WORKDIR}/data_tombstones" || THISRC=${__FALSE}

      CUR_LOG_FILE="${MODULE_WORKDIR}/data_tombstones/copy_tombstones.log"
      CMD='cp -r /data/tombstones/ ${MODULE_WORKDIR}/data_tombstones'
      execute_command "${CMD}" "${CUR_LOG_FILE}"  
      
      CUR_LOG_FILE="${MODULE_WORKDIR}/data_tombstones/tombstones.cmds.txt"
      CMD='egrep "Cmdline|Timestamp" tombstones/data_tombstones/tombstones/*'
      execute_command "${CMD}" "${CUR_LOG_FILE}"  
      
    fi

  fi
  
  
# ----------------------------------------------------------------------

  return ${THISRC}
}


# ----------------------------------------------------------------------
# module_update
#
# function: Collect the infos about the  update engine
#
# usage: module_update
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_update {
  typeset __FUNCTION="module_update"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""

  typeset FILE_LIST=""
  typeset CUR_FILE=""
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"
  
  typeset UPDATE_ENGINE_CONF_FILE="/system/etc/update_engine.conf"
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then

    CUR_LOG_FILE="${MODULE_WORKDIR}/logcat_update_engine.txt"
    CMD="logcat -d |  grep update_engine"
    execute_command "${CMD}" "${CUR_LOG_FILE}"  

    if [ -r "${UPDATE_ENGINE_CONF_FILE}" ] ; then
      CUR_LOG_FILE="${MODULE_WORKDIR}/update_engine.conf"
      CMD="cat ${UPDATE_ENGINE_CONF_FILE}"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  
    else
      LogInfo "The file \"${UPDATE_ENGINE_CONF_FILE}\"does not exist"
    fi
  fi
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ] ; then
      
      FILE_LIST="$( ${ROOT_PREFIX} ls  /data/misc/update_engine_log/*   )"
      for CUR_FILE in ${FILE_LIST} ; do

        CUR_LOG_FILE="${MODULE_WORKDIR}/${CUR_FILE##*/}" 
        CMD="cat ${CUR_FILE}"
        execute_command "${CMD}" "${CUR_LOG_FILE}"   "${ROOT_PREFIX}"

      done
    fi
  fi

  return ${THISRC}
}


# ----------------------------------------------------------------------
# module_template
#
# function: Collect the infos about ???
#
# usage: module_template
#
# returns: ${__TRUE} - module successfully executed
#          ${__FALSE} - error executing the module
#
#
function module_template {
  typeset __FUNCTION="module_template"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=""
  typeset CUR_LOG_FILE=""
  typeset FILE_LIST=""
  typeset CUR_FILE=""
  typeset i=0
  
  typeset MODULE_WORKDIR="${CUR_WORKDIR}/${__FUNCTION#module_*}"

# ----------------------------------------------------------------------
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    create_directory "${MODULE_WORKDIR}" || THISRC=${__FALSE}
  fi

# ----------------------------------------------------------------------

  CUR_LOG_FILE="${MODULE_WORKDIR}/ip_ntable_list.txt"
  CMD="ip ntable list"
  execute_command "${CMD}" "${CUR_LOG_FILE}" 

# ----------------------------------------------------------------------

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    CUR_LOG_FILE="${MODULE_WORKDIR}/xxxx.txt"
    :
  fi

# ----------------------------------------------------------------------

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ;then
    if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ] ; then

      CUR_LOG_FILE="${MODULE_WORKDIR}/yyy.txt"
      CMD="ip ntable list"
      execute_command "${CMD}" "${CUR_LOG_FILE}"  "${ROOT_PREFIX}"

      :
    fi
  fi

# ----------------------------------------------------------------------

  return ${THISRC}
}


# ----------------------------------------------------------------------
# main code starts here
#

# install the trap handler
#
__settraps

# ----------------------------------------------------------------------
#
# redirect STDOUT and STDERR of the script and all commands executed by
# the script to a file if called in an background session
#
if [ ${RUNNING_IN_TERMINAL_SESSION} = ${__FALSE} -a  ${LOG_STDOUT} = ${__TRUE} ] ; then
  if [[ " $* " = *\ --noSTDOUTlog\ * ]] ; then
    :
  elif [[ " $* " != *\ -q\ * && " $* " != *\ --quiet\ * ]] ; then
    STDOUT_FILE="${TMPDIR}/${SCRIPTNAME}.STDOUT_STDERR"
    touch "${STDOUT_FILE}" 2>/dev/null
    if [ $? -ne 0 ] ; then
      STDOUT_FILE="${TMPDIR}/${SCRIPTNAME}.STDOUT_STDERR.$$"
    else
      [ ! -s "${STDOUT_FILE}" ] && \rm "${STDOUT_FILE}"
    fi
    
    RotateLog "${STDOUT_FILE}"
  
    echo "${SCRIPTNAME} -- Running in a detached session ... STDOUT/STDERR will be in ${STDOUT_FILE}" >&2
 
    exec 3>&1
    exec 4>&2
    exec 1>>"${STDOUT_FILE}"  2>&1
  fi
fi

# ----------------------------------------------------------------------

DISABLED_MODULES=""

# modules defined in this script
#
LIST_OF_KNOWN_MODULES="$( grep "^function module_" "${REAL_SCRIPTNAME}" | grep -v "module_template" |  awk '{ print $2 }'  | cut -f2- -d "_"  |  tr "\n" " " )"

# modules found in the include files
#
LIST_OF_ADDITIONAL_KNOWN_MODULES=""

# ----------------------------------------------------------------------


gettime_in_seconds STARTTIME_IN_SECONDS
STARTTIME_IN_HUMAN_READABLE_FORMAT="$( date "+%d.%m.%Y %H:%M:%S" )"

LogMsg "### ${SCRIPTNAME} started at ${STARTTIME_IN_HUMAN_READABLE_FORMAT} (The PID of this process is $$)"


# get the parameter
#
ALL_PARAMETER="$*"

PARAMETER_OKAY=${__TRUE}

SHOW_SCRIPT_USAGE=${__FALSE}

FUNCTIONS_TO_TRACE=""

FUNCTIONS_IN_VERBOSE=""

PRINT_VERSION_AND_EXIT=${__FALSE}

LOGFILE_PARAMETER_FOUND=${__FALSE}

PRINT_RUNTIME_VARIABLES=${__FALSE}

CUR_SERIAL_NO="$( "${GETPROP}" ro.serialno )"

if [ "${TMPDIR}"x != ""x ] ; then
  DEFAULT_OUTPUT_FILE="${TMPDIR}/android_explorer_${CUR_SERIAL_NO}_$( date +%Y-%m-%d-$H_%S_%s ).tar.gz"
else
  DEFAULT_OUTPUT_FILE=""
fi

OUTPUT_FILE="${OUTPUT_FILE:=${DEFAULT_OUTPUT_FILE}}"

DEFAULT_WORKDIR="${TMPDIR}/${SCRIPTNAME}.$$.work"
CUR_WORKDIR="${WORKDIR:=${DEFAULT_WORKDIR}}"

MODULES_TO_EXECUTE=""

MODULES_TO_EXCLUDE=""

KEEP_WORKING_DIRECTORY=${__FALSE}

LIST_DEFINED_MODULES=${__FALSE}

MODULES_TO_EXECUTE="${MODULES_TO_EXECUTE:=${LIST_OF_KNOWN_MODULES} ${LIST_OF_ADDITIONAL_KNOWN_MODULES}}"

DEFAULT_INCLUDE_FILES="$( ls ${REAL_SCRIPTDIR}/*.include 2>/dev/null ) $( ls ${PWD}/*.include  2>/dev/null )"

INCLUDE_FILES="default"

DO_NOT_USE_ROOT_ACCESS=${__FALSE}

# ----------------------------------------------------------------------

# process all variables beginning with __DEFAULT_
#
if [ ${SET_DEFAULT_VALUES} = ${__TRUE} ] ; then
  for CURVAR in $( set | grep "^__DEFAULT_"  | cut -f1 -d"=" ) ; do
    P1="${CURVAR%%=*}"
    P2="${P1#__DEFAULT_*}"

    LogInfo "Setting variable $P2 to \"$( eval "echo \"\$$P1\"")\" "

    eval "$P2="\"\$$P1\"""
  done
fi

# ----------------------------------------------------------------------

# the alias __getparameter is used for parameter that support values
# and can be used like this "-l logfile" or this "-l:logfile"
#
alias __getparameter='
       CUR_KEY="$1"
       CUR_VALUE="${1#*:}"
       if [ "${CUR_VALUE}"x = "$1"x ] ; then
         CUR_VALUE=""
         if [ "$2"x != ""x ] ; then
           if [[ $2 != -* ]] ; then
             CUR_VALUE="$2"
             shift
           fi
         fi  
       fi'


while [ $# -ne 0 ] ; do
  
  CUR_PARAMETER="$1"
  case $1 in

# dummy help parameter
    - ) 
       :
       ;;

    -h | "" )
       SHORT_HELP=${__TRUE}
       SHOW_SCRIPT_USAGE=${__TRUE}
       ;;

    --help | -H | help |  "" )
       SHORT_HELP=${__FALSE}
       SHOW_SCRIPT_USAGE=${__TRUE}
       ;;

    -V | --version )
       PRINT_VERSION_AND_EXIT=${__TRUE}
       ;;

    +V | ++version )
       PRINT_VERSION_AND_EXIT=${__FALSE}
       ;;

    -v | --verbose )
       (( VERBOSE_LEVEL = VERBOSE_LEVEL+1 ))
       VERBOSE=${__TRUE}
       SHORT_HELP=${__FALSE}
       ;;

    +v | ++verbose )
       VERBOSE=${__FALSE}
       [ ${VERBOSE_LEVEL} -gt 0 ] && (( VERBOSE_LEVEL = VERBOSE_LEVEL-1 )) || VERBOSE_LEVEL=0
       ;;

    -q | --quiet )
       QUIET=${__TRUE}
       ;;

    +q | ++quiet )
       QUIET=${__FALSE}
       ;;

    -f | --force )
       FORCE=${__TRUE}
       ;;

    +f | ++force )
       FORCE=${__FALSE}
       ;;

    -o | --overwrite )
       OVERWRITE=${__TRUE}
       ;;

    +o | ++overwrite )
       OVERWRITE=${__FALSE}
       ;;

    -D | --debugshell )
       if [ ${ENABLE_DEBUG}x != ${__TRUE}x ] ; then
         LogError "DebugShell is disabled."
         PARAMETER_OKAY=${__FALSE}
       else
         DebugShell 
       fi
       ;;


    -d | --dryrun | -d:* | --dryrun:* )
       __getparameter    
       
       if [ "${CUR_VALUE}"x = ""x ] ; then
         PREFIX="${PREFIX:=${DEFAULT_DRYRUN_PREFIX}}"
       else
         LogInfo "Parameter \"${CUR_PARAMETER} ${CUR_VALUE}\" found"
         PREFIX="${CUR_VALUE}"
       fi

       if [ ${DRYRUN_MODE_DISABLED} = ${__TRUE} ] ; then
         LogError "Dryrun Mode is NOT supported"
         PARAMETER_OKAY=${__FALSE}
         PREFIX=""
       fi
       ;;

    +d | ++dryrun )
       if [ ${DRYRUN_MODE_DISABLED} = ${__TRUE} ] ; then
         LogError "Dryrun Mode is NOT supported"
         PARAMETER_OKAY=${__FALSE}
       else
         if [ "${PREFIX}"x != ""x ] ; then
           LogMsg "Disabling the dryrun mode (the dryrun prefix was \"${PREFIX}\")"
         fi
         PREFIX=""
       fi
       ;;

#    -d:* | --dryrun:** )
#       if [ ${DRYRUN_MODE_DISABLED} = ${__TRUE} ] ; then
#         LogError "Dryrun Mode is NOT supported"
#         PARAMETER_OKAY=${__FALSE}
#       else
#         PREFIX="${1#*:}"
#         LogMsg "The dryrun prefix used is: \"${PREFIX}\" "
#       fi
#       ;;

    +y | ++yes | +n | ++no )
       __USER_RESPONSE_IS=""
       ;;
   
    -y | --yes )
       __USER_RESPONSE_IS="y"
       ;;
       
    -n | --no )
       __USER_RESPONSE_IS="n"
       ;;

    --nologrotate )
       ROTATE_LOG=${__FALSE}
       ;;

    ++nologrotate )
       ROTATE_LOG=${__TRUE}
       ;;

    --appendlog )
       APPEND_LOG=${__TRUE}
       ROTATE_LOG=${__FALSE}
       ;;
        
    ++appendlog )
       APPEND_LOG=${__FALSE}
       ROTATE_LOG=${__TRUE}
       ;;

    --noSTDOUTlog )
       LOG_STDOUT=${__FALSE}
       ;;

    ++noSTDOUTlog )
       LOG_STDOUT=${__TRUE}
       ;;
    
    --nocleanup )
      NO_CLEANUP=${__TRUE}
      ;;

    ++nocleanup )
      NO_CLEANUP=${__FALSE}
      ;;

    --nobackups)
      NO_BACKUPS=${__TRUE}
      ;;

    ++nobackups )
      NO_BACKUPS=${__FALSE}
      ;;

    --var | --var:* )
      __getparameter

      if [ "${CUR_VALUE}"x = ""x ] ; then
         LogError "Missing value for --var"
         PARAMETER_OKAY=${__FALSE}
       else
         if [ ${ENABLE_DEBUG}x != ${__TRUE}x ] ; then
           LogError "Parameter \"${CUR_PARAMETER}\" is disabled."
           PARAMETER_OKAY=${__FALSE}
         else
           VAR_NAME="${CUR_VALUE%%=*}"
           VAR_VALUE="${CUR_VALUE#*=}"
           LogMsg "Found ${CUR_PARAMETER} parameter for ${VAR_NAME}=\"${VAR_VALUE}\" "
         
           eval CUR_VALUE="\$${VAR_NAME}"
           LogMsg "Current value of ${VAR_NAME} is: \"${CUR_VALUE}\" "
         
           eval ${VAR_NAME}=\"${VAR_VALUE}\" 

           eval NEW_VALUE="\$${VAR_NAME}"
           LogMsg "New value of ${VAR_NAME} is now: \"${NEW_VALUE}\" "
         fi
       fi
       ;;

    -v:* | --verbose:* )
       __getparameter    
       
       if [ "${CUR_VALUE}"x = ""x ] ; then
         LogError "Missing value for the parameter \"${CUR_PARAMETER}\" "
         PARAMETER_OKAY=${__FALSE}
       elif [ "${CUR_VALUE}"x = "none"x ] ; then
         LogInfo "Disabling verbose mode for all functions"
         FUNCTIONS_IN_VERBOSE=""
       else
         FUNCTIONS_IN_VERBOSE="${FUNCTIONS_IN_VERBOSE} $( echo "${CUR_VALUE}" | tr "," " " )"
       fi
       ;;
         
    -t | --tracefunc | -t:* | --tracefunc:* )
       __getparameter    
       
       if [ "${CUR_VALUE}"x = ""x ] ; then
         LogError "Missing value for the parameter \"${CUR_PARAMETER}\" "
         PARAMETER_OKAY=${__FALSE}
       elif [ "${CUR_VALUE}"x = "none"x ] ; then
         LogInfo "Disabling tracing for all functions"
         FUNCTIONS_TO_TRACE=""
       else
         FUNCTIONS_TO_TRACE="${FUNCTIONS_TO_TRACE} $( echo "${CUR_VALUE}" | tr "," " " )"
       fi
       ;;

    -L | --listfunctions ) 
       LIST_FUNCTIONS_AND_EXIT=${__TRUE}
       ;;

    +L | ++listfunctions ) 
       LIST_FUNCTIONS_AND_EXIT=${__FALSE}
       ;;
       
    -l | --logfile | -l:* | --logfile:* )
       LOGFILE_PARAMETER_FOUND=${__TRUE}
       __getparameter

       if [ "${CUR_VALUE}"x = ""x ] ; then
         LogInfo "Running without a logfile (no value for the parameter \"${CUR_PARAMETER}\" found)"
         LOGFILE=""
       elif [[ ${CUR_VALUE} = -* ]] ; then
         LogInfo "Running without a logfile (no value for the parameter \"${CUR_PARAMETER}\" found)"
         LOGFILE=""
       elif [ "${CUR_VALUE}"x = "none"x ] ; then
         LogInfo "Running without a logfile (the value for the parameter \"${CUR_PARAMETER}\" is \"none\")"
         LOGFILE=""
       else
         LOGFILE="${CUR_VALUE}"
         LogRuntimeInfo "Using the logfile ${LOGFILE}"
       fi
       ;;

    -T | --tee )
       # parameter is already processed - ignore it
       :
       ;;

    --disable_tty_check )
       DISABLE_TTY_CHECK=${__TRUE}
       ;;

    ++disable_tty_check )
       LogWarning "The parameter \"${CUR_PARAMETER}\" is not supported and will be ignored"
#       DISABLE_TTY_CHECK=${__FALSE}
       ;;

    --print_runtime_variables | --print_runtime_vars )
       PRINT_RUNTIME_VARIABLES=${__TRUE}
       ;;

    ++print_runtime_variables | ++print_runtime_vars )
       PRINT_RUNTIME_VARIABLES=${__FALSE}
       ;;

    ++configure )
       CHANGE_CONFIG_PARAMETER=${__FALSE}
       ;;    

    --list )
       LIST_DEFINED_MODULES=${__TRUE}
       ;;

    ++list )
       LIST_DEFINED_MODULES=${__FALSE}
       ;;

    --keep )
       KEEP_WORKING_DIRECTORY=${__TRUE}
       ;;

    ++keep )
       KEEP_WORKING_DIRECTORY=${__FALSE}
       ;;


    --noroot )
       DO_NOT_USE_ROOT_ACCESS=${__TRUE}
       ;;

    ++noroot )
       DO_NOT_USE_ROOT_ACCESS=${__FALSE}
       ;;

    -x | --disable | -x:* | --disable:* | --exclude | --exclude:* )
       __getparameter    
       
       if [ "${CUR_VALUE}"x = ""x ] ; then
         LogError "Missing value for the parameter \"${CUR_PARAMETER}\" "
         PARAMETER_OKAY=${__FALSE}
       elif [ "${CUR_VALUE}"x = "none"x ] ; then
         LogInfo "Enabling all modules"
         MODULES_TO_EXCLUDE=""
       else
         MODULES_TO_EXCLUDE="${MODULES_TO_EXCLUDE} $( echo "${CUR_VALUE}" | tr "," " " )"
       fi
       LogInfo "The list of modules to exclude is now: ${MODULES_TO_EXCLUDE}"
       ;;

    -i | --enable | -i:* | --enable:* )
       __getparameter    

       if [ "${CUR_VALUE}"x = ""x ] ; then
         LogError "Missing value for the parameter \"${CUR_PARAMETER}\" "
         PARAMETER_OKAY=${__FALSE}
       elif [ "${CUR_VALUE}"x = "none"x ] ; then
         LogInfo "Disabling all modules"
         MODULES_TO_EXECUTE=""
       elif [ "${CUR_VALUE}"x = "all"x ] ; then
         LogInfo "Enabling all modules"
         MODULES_TO_EXECUTE="${LIST_OF_KNOWN_MODULES}"
       else
         MODULES_TO_EXECUTE="${MODULES_TO_EXECUTE} $( echo "${CUR_VALUE}" | tr "," " " )"
       fi
       LogInfo "The list of modules to execute is now: ${MODULES_TO_EXECUTE}"
       ;;


    -O | --outputfile | -O:* | --outputfile:* )
       __getparameter    
       
       if [ "${CUR_VALUE}"x = ""x ] ; then
         LogError "Missing value for the parameter \"${CUR_PARAMETER}\" "
         PARAMETER_OKAY=${__FALSE}
       elif [ "${CUR_VALUE}"x = "none"x ] ; then
         LogInfo "Disabling writing an output file"
         OUTPUT_FILE=""
       elif [ "${CUR_VALUE}"x = "default"x ] ; then
         LogInfo "Using the default output file"
         OUTPUT_FILE="${DEFAULT_OUTPUT_FILE}"
       else
         OUTPUT_FILE="${CUR_VALUE}"
         LogInfo "Creating the output file \"${OUTPUT_FILE}\""
       fi
       ;;

    -w | --workdir | -w:* | --workdir:* )
       __getparameter    
       
       if [ "${CUR_VALUE}"x = ""x ] ; then
         LogError "Missing value for the parameter \"${CUR_PARAMETER}\" "
         PARAMETER_OKAY=${__FALSE}
       elif [ "${CUR_VALUE}"x = "default"x ] ; then
         LogInfo "Using the default work dir"
         CUR_WORKDIR="${DEFAULT_WORKDIR}"
       else
         CUR_WORKDIR="${CUR_VALUE}"
         LogInfo "Using the work dir \"${CUR_WORKDIR}\""
       fi
       ;;

    -I | --include| -I:* | --include:* )
       __getparameter    
       
       [ "${INCLUDE_FILES}"x = "default"x ] && INCLUDE_FILES=""
       
       if [ "${CUR_VALUE}"x = ""x ] ; then
         LogError "Missing value for the parameter \"${CUR_PARAMETER}\" "
         PARAMETER_OKAY=${__FALSE}
       elif [ "${CUR_VALUE}"x = "default"x ] ; then
         LogInfo "Using the default include files only"
         INCLUDE_FILES="${INCLUDE_FILES} ${DEFAULT_INCLUDE_FILES}"
       elif [ "${CUR_VALUE}"x = "none"x ] ; then
         LogInfo "Using no default include files"
         INCLUDE_FILES="none"
       else
         INCLUDE_FILES="${INCLUDE_FILES} $( echo "${CUR_VALUE}" | tr "," " " )"
         LogInfo "Using the include files: \"${INCLUDE_FILES}\""
       fi
       ;;

    --bg )
        switch_to_background
        ;;
        
    -- )
        shift
        break
        ;;

# check for unknown switches
#
    -*=* )
       LogError "Unknown parameter found: ${CUR_PARAMETER}  (wrong separator character? the separator character to use is the colon \":\")"
       PARAMETER_OKAY=${__FALSE}
       ;;

    -* )
       LogError "Unknown parameter found: ${CUR_PARAMETER}"
       PARAMETER_OKAY=${__FALSE}
       ;;


    * ) 
       break
#       LogError "Unknown parameter found: ${CUR_PARAMETER}"
#       PARAMETER_OKAY=${__FALSE}
       ;;
     
  esac
  shift
done


# process the remaining parameter
#

if [ ${VAR_VALUE_PARAMETER_ENABLED} = ${__TRUE} ] ; then
  TMP_PARAMETER=""
  
  while [ $# -ne 0 ] ; do
    CUR_PARAMETER="$1"
    shift
  
    case ${CUR_PARAMETER} in

      *=* )
        CUR_VAR="${CUR_PARAMETER%%=*}"
        CUR_VAL="${CUR_PARAMETER#*=}"
        LogInfo "Setting the variable \"${CUR_VAR}\" to \"${CUR_VAL}\" ..."
        eval "${CUR_VAR}=\"${CUR_VAL}\""
        ;;

      * )
        TMP_PARAMETER="${TMP_PARAMETER} \"${CUR_PARAMETER}\""         
        ;;
    esac
  done

  set -- ${TMP_PARAMETER}
fi


NOT_USED_PARAMETER="$*"
# [ $# -ne 0 ] && LogMsg "Not yet used parameter are: \"$*\" "


[ $# -ne 0 ] && MODULES_TO_EXECUTE="${MODULES_TO_EXECUTE} $*"


if [ ${SHOW_SCRIPT_USAGE} = ${__TRUE} ] ; then
  show_script_usage    
  die 0
fi

if [ ${PRINT_VERSION_AND_EXIT} = ${__TRUE}   ] ; then
  LOGFILE=""
  echo "${SCRIPT_VERSION}"
  [ ${VERBOSE} = ${__TRUE} ] && echo "The Script template version is ${__TEMPLATE_VERSION}"
  die 0
fi

# ---------------------------------------------------------------------
# process the include files
#

if [ "${INCLUDE_FILES}"x = "none"x ] ; then
  LogInfo "Include files are disabled"
elif [ "${INCLUDE_FILES}"x != ""x ] ; then

  LogMsg "-"
  LogInfo "Checking the include files ..."

  if [ "${INCLUDE_FILES}"x = "default"x ] ; then
    INCLUDE_FILES="${DEFAULT_INCLUDE_FILES}"
  fi
  
  NEW_INCLUDE_FILES=""
  ERROR_FOUND=${__FALSE}

  LogInfo "The list of include files is now: " && \
    LogMsg "-" "${INCLUDE_FILES}" 
  
  for CUR_INCLUDE_FILE in ${INCLUDE_FILES} ; do

    LogInfo "Processing the include file \"${CUR_INCLUDE_FILE}\" ..."

    if [ -d "${CUR_INCLUDE_FILE}" ] ; then
      NEW_INCLUDE_FILES="${NEW_INCLUDE_FILES} $( ls -ld ${CUR_INCLUDE_FILE}/*.include 2>/dev/null )"
    elif [ -r "${CUR_INCLUDE_FILE}" ] ; then
      NEW_INCLUDE_FILES="${NEW_INCLUDE_FILES} ${CUR_INCLUDE_FILE}"
    else
      LogError "The file \"${CUR_INCLUDE_FILE}\" does not exist"
      ERROR_FOUND=${__TRUE}
    fi  

  done

  LogInfo "The list of include files is now: " && \
    LogMsg "${INCLUDE_FILES}" 

  LogInfo "Removing the line breaks ..."
  INCLUDE_FILES="$( echo "${NEW_INCLUDE_FILES}" | tr "\n" " " )"

  LogInfo "The list of include files is now: " && \
    LogMsg "${INCLUDE_FILES}" 

  LogInfo "Removing duplicates ..."

  NEW_INCLUDE_FILES=""
  for CUR_INCLUDE_FILE in ${INCLUDE_FILES} ; do
    if [[ " ${NEW_INCLUDE_FILES} " == *\ ${CUR_INCLUDE_FILE}\ * ]] ; then
      LogInfo "Duplicate include file \"${CUR_INCLUDE_FILE}\" ignored"
      continue
    else 
      NEW_INCLUDE_FILES="${NEW_INCLUDE_FILES} ${CUR_INCLUDE_FILE}"
    fi
  done
  
  INCLUDE_FILES="${NEW_INCLUDE_FILES}"

  LogInfo "The list of include files is now: " && \
    LogMsg "${INCLUDE_FILES}" 

  if [ "${NEW_INCLUDE_FILES}"x != ""x  ] ; then
    LogInfo "Checking the include files ..."
          
    for CUR_INCLUDE_FILE in ${INCLUDE_FILES} ; do
  
      LogInfo "Checking the include file \"${CUR_INCLUDE_FILE}\" ..."
  
      CUR_OUTPUT="$( source "${CUR_INCLUDE_FILE}" 2>&1 )"
      if [ $? -ne 0 ] ; then
        LogMsg "${CUR_OUTPUT}"
        LogError "Error checking the file \"${CUR_INCLUDE_FILE}\" "
        ERROR_FOUND=${__TRUE}
      fi  
    done
  
    if [ ${ERROR_FOUND} = ${__FALSE} -a   ] ;then
      LogMsg "-"
      LogMsg "Reading the include files ..."
  
      for CUR_INCLUDE_FILE in ${NEW_INCLUDE_FILES} ; do
        LogMsg "-"
        LogMsg "Reading the include file \"${CUR_INCLUDE_FILE}\" ..."
        source "${CUR_INCLUDE_FILE}"
        if [ $? -ne 0 ] ; then
          LogMsg "${CUR_OUTPUT}"
          LogError "Error reading the file \"${CUR_INCLUDE_FILE}\" "
          ERROR_FOUND=${__TRUE}
        else
          LIST_OF_NEW_ADDITIONAL_KNOWN_MODULES="$( grep "  function module_" "${CUR_INCLUDE_FILE}" | grep -v "module_template" |  awk '{ print $2 }'  | cut -f2- -d "_"  |  tr "\n" " " )"
          
          LogInfo "Modules found in the include file \"${CUR_INCLUDE_FILE}\" : " && \
           LogMsg "-" "${LIST_OF_NEW_ADDITIONAL_KNOWN_MODULES}"
           
          LIST_OF_ADDITIONAL_KNOWN_MODULES="${LIST_OF_ADDITIONAL_KNOWN_MODULES} ${LIST_OF_NEW_ADDITIONAL_KNOWN_MODULES}"
        fi  
      done
      LogMsg "-"
    fi
  fi
  
  if [ ${ERROR_FOUND} = ${__TRUE} ] ;then
    die 17 "Error(s) found in one ore more include files"
  fi  
fi


# ---------------------------------------------------------------------

for CUR_MODULE in ${MODULES_TO_EXECUTE} ; do
  DISABLED_MODULES="$( echo " ${DISABLED_MODULES} " | sed "s/ ${CUR_MODULE} //g" )"
done

if [ ${PARAMETER_OKAY} != ${__TRUE} ] ; then
  die 2
fi

if [ ${LIST_FUNCTIONS_AND_EXIT} = ${__TRUE} ] ; then
  LogMsg "Defined functions are :"
  LogMsg "-" "$( typeset +f )"
  die 0
fi

if [ ${PRINT_RUNTIME_VARIABLES} = ${__TRUE} ] ; then
  LogMsg "Defined runtime variables are :"
  print_runtime_variables
  die 0
fi


if [ "${PREFIX}"x != ""x ] ; then
  LogMsg "-"
  LogMsg "*** Running in dry-run mode -- no changes will be done. The dryrun prefix used is \"${PREFIX}\" "
  LogMsg "-"
fi


# the logfile to use is now fix so activate the logging to the logfile
#
__activate_logfile

# enable trace (set -x) for all requested functions
#
if [ "${FUNCTIONS_TO_TRACE}"x != ""x ] ; then
  __enable_trace_for_functions  "${FUNCTIONS_TO_TRACE}"
fi


# enable verbose mode for all requested functions
#
if [ "${FUNCTIONS_IN_VERBOSE}"x != ""x ] ; then
  __enable_verbose_for_functions  "${FUNCTIONS_IN_VERBOSE}"

#
# define an alias for return to restore the setting for the verbose mode
#
  alias return='eval typeset __RC_\$\$=\$? ; [ "${__VERBOSE}"x != ""x ] && VERBOSE=${__VERBOSE}; eval __return \$__RC_$$; return '

fi
 
  
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
# main:


# ----------------------------------------------------------------------
# check if this script is executed by the root user
#
# [ "${CUR_USER_ID}"x != "0"x ] && die 202 "This script must be executed by root only"



# ----------------------------------------------------------------------
# to add variables to the print variable function for DebugShell use
#
# APPLICATION_VARIABLES="${APPLICATION_VARIABLES} "
#
# to define files, directories, or processes to remove at script end 
# or functions to execute at script end use
#
# finish routines that should be executed before the house keeping tasks are done
#   Use "function_name:parameter1[[...]:parameter#] to add parameter for a function
#   blanks or tabs in the parameter are NOT allowed
#
# CLEANUP_FUNCTIONS="${CLEANUP_FUNCTIONS} "
#
# processes that should be killed at script end
#   to change the timeout after kill before issuing a kill -9 for 
#   a process use  pid:timeout
#
# PROCS_TO_KILL="${PROCS_TO_KILL} "
#
# files that should be deleted at script end
#
# FILES_TO_REMOVE="${FILES_TO_REMOVE} "
#
# directories that should be removed at script end
#
# DIRS_TO_REMOVE="${DIRS_TO_REMOVE} "
#
# mount points to umount at script end
#
# MOUNTS_TO_UMOUNT="${MOUNTS_TO_UMOUNT} "
#
# finish routines to executed after all house keeping tasks are done
#   Use "function_name:parameter1[[...]:parameter#] to add parameter for a function
#   blanks or tabs in the parameter are NOT allowed
#
# FINISH_FUNCTIONS="${FINISH_FUNCTIONS} "
#

# ----------------------------------------------------------------------
# init the script return code
#
THISRC=${__TRUE}

#
# ----------------------------------------------------------------------

if [ ${DISABLE_TTY_CHECK} != ${__TRUE} ] ; then
  if [ ${RUNNING_IN_TERMINAL_SESSION} = ${__TRUE} ] ; then
    LogRuntimeInfo "The script is running in a terminal session"
  else
    LogRuntimeInfo "The script is running in a session without a terminal"
  fi
else
  LogRuntimeInfo "The tty check is disabled -- the script assumes to run in a terminal session"
fi

LogRuntimeInfo "The name of the shell used is \"${__SHELL}\" "
LogRuntimeInfo "The real ksh version is \"${REAL_KSH_VERSION}\""
LogRuntimeInfo "The ksh version of the running shell is ${__KSH_VERSION}"
LogRuntimeInfo "The current hostname is \"${CUR_HOST}\" "
LogRuntimeInfo "The current short hostname is \"${CUR_SHORT_HOST}\" "
LogRuntimeInfo "The current os is \"${CUR_OS}\", the current OS version is \"${CUR_OS_VERSION}\" "
LogRuntimeInfo "The user id executing this script is \"${CUR_USER_NAME}\" (UID is \"${CUR_USER_ID}\") "
LogRuntimeInfo "The group id executing this script is \"${CUR_GROUP_NAME}\" (GID is \"${CUR_GROUP_ID}\") "

LogRuntimeInfo "The real script name is \"${REAL_SCRIPTNAME}\" "
LogRuntimeInfo "The real script directory is \"${REAL_SCRIPTDIR}\" "
LogRuntimeInfo "The working directory is \"${WORKING_DIR}\" "
LogRuntimeInfo "The editor to use is \"${EDITOR}\" "
LogRuntimeInfo "The pager to use is \"${PAGER}\" "

if [ ${RUNNING_ON_A_VIRTUAL_MACHINE} = ${__TRUE} ] ; then
  LogRuntimeInfo "The script is running in a virtual machine"
  LogRuntimeInfo "The hypervisor used is \"${SYSTEM_PRODUCT_NAME}\" "
  LogRuntimeInfo "The vendor of the hypervisor used is \"${HPYERVISOR_VENDOR}\" "
else
  LogRuntimeInfo "The script is running on a physical machine"
fi

LogRuntimeInfo "RUNNING_IN_A_CONSOLE_SESSION is  \"${RUNNING_IN_A_CONSOLE_SESSION}\" "

LogRuntimeInfo "STDOUT_IS_A_PIPE is ${STDOUT_IS_A_PIPE} "
LogRuntimeInfo "STDIN_IS_A_PIPE is ${STDIN_IS_A_PIPE} "
LogRuntimeInfo "STDIN_IS_TTY is  \"${STDIN_IS_TTY}\" "
LogRuntimeInfo "STDOUT_IS_TTY is  \"${STDOUT_IS_TTY}\" "
LogRuntimeInfo "STDERR_IS_TTY is  \"${STDERR_IS_TTY}\" "

LogRuntimeInfo "STDIN is  \"${STDIN_DEVICE}\" "
LogRuntimeInfo "STDOUT is \"${STDOUT_DEVICE}\" "
LogRuntimeInfo "STDERR is \"${STDERR_DEVICE}\" "

LogRuntimeInfo "Shell options are \"${__SHELL_OPTIONS}\" "
LogRuntimeInfo "Trace mode is \"${__TRACE}\" "

# ----------------------------------------------------------------------
# 

if [ ${RUNNING_IN_ANDROID}x != ${__TRUE}x ] ; then
  die 205 "The current OS is NOT the Android OS"
fi


# ----------------------------------------------------------------------
#


CUR_MODULES_TO_EXECUTE=""

# remove disabled  and duplicate modules
#
for CUR_MODULE in ${MODULES_TO_EXECUTE} ; do

  if [[ " ${MODULES_TO_EXCLUDE} " == *\ ${CUR_MODULE}\ * ]] ; then
    continue
  fi

  if [[ " ${CUR_MODULES_TO_EXECUTE} " == *\ ${CUR_MODULE}\ * ]] ; then
    continue
  fi
  
  CUR_MODULES_TO_EXECUTE="${CUR_MODULES_TO_EXECUTE} ${CUR_MODULE}"
done


CUR_OUTPUT="$( 
  LogMsg "-"
  LogMsg "The known modules are: ${LIST_OF_KNOWN_MODULES}"
  LogMsg "-"
  
  if [ "${LIST_OF_ADDITIONAL_KNOWN_MODULES}"x != ""x ] ; then
    LogMsg "The known modules defined in include files are: ${LIST_OF_ADDITIONAL_KNOWN_MODULES}"
    LogMsg "-"
  fi
  
  LogMsg "The modules to execute are: ${MODULES_TO_EXECUTE}"
  LogMsg "-"
  LogMsg "Disabled modules are: ${DISABLED_MODULES}"
  LogMsg "-"
  LogMsg "The modules to exclude are: ${MODULES_TO_EXCLUDE}"
  LogMsg "-"
)" 

  echo "${CUR_OUTPUT}"


if [ ${LIST_DEFINED_MODULES} = ${__TRUE} ] ; then
  die 0
fi

# ----------------------------------------------------------------------
# create the working directory
#

LogMsg "The working directory is \"${CUR_WORKDIR}\" " 

create_directory "${CUR_WORKDIR}" || \
  die 10 "Can not create the working directory \"${CUR_WORKDIR}\" "

cd "${CUR_WORKDIR}"
if [ $? -ne 0 ] ; then
  die 10 "Can not change the current directory to the working directory \"${CUR_WORKDIR}\" "
fi

# ----------------------------------------------------------------------

echo "${CUR_OUTPUT}" >"${CUR_WORKDIR}/module.lst"

# ----------------------------------------------------------------------

LogMsg "The current user is \"${CUR_USER_NAME}\" " 

# check for root access
#
LogMsg "Checking if root access is available ..."

ROOT_ACCESS_AVAILABLE=${__FALSE}
ROOT_PREFIX=""


if [ ${ROOT_ACCESS_AVAILABLE} = ${__FALSE} -a ${DO_NOT_USE_ROOT_ACCESS} = ${__FALSE} ] ; then
  if [ "${CUR_USER_NAME}"x = "root"x ] ; then
    ROOT_ACCESS_AVAILABLE=${__TRUE}
    LogInfo "The user executing the script is \"root\""
  elif [ $( su - -c id -un 2>/dev/null )x = "root"x ] ; then
    ROOT_ACCESS_AVAILABLE=${__TRUE}
    ROOT_PREFIX="su - -c "
    LogInfo "root access is available using the prefix  \"su - -c \""
  elif [ $( su -c id -un 2>/dev/null )x = "root"x ] ; then
    ROOT_ACCESS_AVAILABLE=${__TRUE}
    ROOT_PREFIX="su -c "    
    LogInfo "root access is available using the prefix  \"su -c \""
  fi
fi

GLOBAL_ROOT_PREFIX="${ROOT_PREFIX}"

if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ] ; then
  LogMsg "root access is available"
else
  LogMsg "root access is not available"
fi

# ----------------------------------------------------------------------

MODULES_SUCCESSFULLY_EXECUTED=""
NO_OF_MODULES_SUCCESSFULLY_EXECUTED=0

MODULES_EXECUTED_WITH_ERROR=""
NO_OF_MODULES_EXECUTED_WITH_ERROR=0

MODULES_NOT_DEFINED=""
NO_OF_MODULES_NOT_DEFINED=0


for CUR_MODULE in ${CUR_MODULES_TO_EXECUTE} ; do
  [[ " ${MODULES_TO_EXCLUDE} " = *\ ${CUR_MODULE}\ * ]] && continue
  [[ " ${DISABLED_MODULES} " = *\ ${CUR_MODULE}\ * ]] && continue
  
  CUR_MODULE="${CUR_MODULE#module_*}"
  
  if [[ " ${LIST_OF_KNOWN_MODULES} ${LIST_OF_ADDITIONAL_KNOWN_MODULES}" != *\ ${CUR_MODULE}\ * ]] ; then
    LogWarning "The module \"${CUR_MODULE}\" is not defined"

   MODULES_NOT_DEFINED="${MODULES_NOT_DEFINED} 
${CUR_MODULE}"
   (( NO_OF_MODULES_NOT_DEFINED = NO_OF_MODULES_NOT_DEFINED + 1 ))

    continue
  fi

  CUR_START_TIME="$( date +%s )"
  
  LogMsg "-"
  LogMsg "Executing the module \"${CUR_MODULE}\" ..."
  module_${CUR_MODULE}
  TEMPRC=$?
  CUR_END_TIME="$( date +%s )"
  
  (( RUN_TIME_IN_SECONDS = CUR_END_TIME - CUR_START_TIME ))
  RUNTIME_IM_HUMNAN_READABLE_FORMAT="$( echo "${RUN_TIME_IN_SECONDS}" | awk '{printf("%d:%02d:%02d:%02d\n",($1/60/60/24),($1/60/60%24),($1/60%60),($1%60))}'  )"

  RUNTIME_STRING="(day:hour:minute:seconds) ${RUNTIME_IM_HUMNAN_READABLE_FORMAT} (= ${RUN_TIME_IN_SECONDS} seconds)"
  
  if [ ${TEMPRC} -eq 0 ] ; then
    LogMsg "... the module \"${CUR_MODULE}\" was executed successfully; the runtime was ${RUNTIME_STRING}"

   MODULES_SUCCESSFULLY_EXECUTED="${MODULES_SUCCESSFULLY_EXECUTED} 
${CUR_MODULE}"
   (( NO_OF_MODULES_SUCCESSFULLY_EXECUTED = NO_OF_MODULES_SUCCESSFULLY_EXECUTED + 1 ))

  else
    LogMsg "... the module \"${CUR_MODULE}\" ended with an error; the rutnime ${RUNTIME_STRING}"

    MODULES_EXECUTED_WITH_ERROR="${MODULES_EXECUTED_WITH_ERROR} 
${CUR_MODULE}"
    (( NO_OF_MODULES_EXECUTED_WITH_ERROR = NO_OF_MODULES_EXECUTED_WITH_ERROR + 1 ))

  fi

done

# ----------------------------------------------------------------------

LogMsg "-"

if [ ${NO_OF_MODULES_SUCCESSFULLY_EXECUTED} = 0 ] ; then
  LogMsg "No modules ended without an error"
else  
  LogMsg "${NO_OF_MODULES_SUCCESSFULLY_EXECUTED} module(s) successfully executed: "
  LogMsg "-" "$( echo "${MODULES_SUCCESSFULLY_EXECUTED}"  )" 
  LogMsg "-"
fi

if [ ${NO_OF_MODULES_EXECUTED_WITH_ERROR} = 0 ] ; then
  LogMsg "No modules ended with an error"
else
  LogMsg "${NO_OF_MODULES_EXECUTED_WITH_ERROR} module(s) ended with an error: "
  LogMsg "-" "$( echo "${MODULES_EXECUTED_WITH_ERROR}"  )" 
  LogMsg "-"
fi

if [ ${NO_OF_MODULES_NOT_DEFINED} != 0 ] ; then
  LogMsg "${NO_OF_MODULES_NOT_DEFINED} module(s) not defined: "
  LogMsg "-" "$( echo "${MODULES_NOT_DEFINED}"  )" 
  LogMsg "-"
fi

# ----------------------------------------------------------------------

 FINAL_MESSAGE="Android explorer created on $( date "+%Y-%m-%d %H:%M:%S" ) from the phone $( getprop ro.product.model ) with the s/n $( getprop ro.serialno )"

 LogMsg "-" "
 ----------------------------------------------------------------------

${FINAL_MESSAGE} 

 ----------------------------------------------------------------------
" | tee -a "${CUR_WORKDIR}/README"
 
 LogMsg "-" '
  
 ----------------------------------------------------------------------
WARNING: 

The files in the archive may contain passwords in plain text.
Please check the files in the archive for passwords before sharing the archive.

 ----------------------------------------------------------------------
' | tee -a "${CUR_WORKDIR}/WARNING"

# ----------------------------------------------------------------------

if [ "${OUTPUT_FILE}"x = ""x ] ; then
  LogWarning "No output file defined -- the work directory \"${CUR_WORKDIR}\" is not deleted"
else
  LogMsg "Creating the output file \"${OUTPUT_FILE}\" ..."

  if [ ${ROOT_ACCESS_AVAILABLE} = ${__TRUE} ] ; then
    ${ROOT_PREFIX} chown -R "${CUR_USER_NAME}:${CUR_GROUP_NAME}" "${CUR_WORKDIR}" 
  fi

  [ "${LOGFILE}"x != ""x ] && [ -r "${LOGFILE}" ] && copy_config_file "${LOGFILE}" "${CUR_WORKDIR}"
  
  CUR_OUTPUT="$( exec 2>&1; set -x ; cd "${CUR_WORKDIR}/.." && ${ROOT_PREFIX} tar -czf "${OUTPUT_FILE}" "${CUR_WORKDIR##*/}" )"
  if [ $? -ne 0 ] ; then
    LogMsg "-" "${CUR_OUTPUT}"
    die 20 "Error creating the output file \"${OUTPUT_FILE}\" -- the work directory \"${CUR_WORKDIR}\" is not deleted"
  else
    LogMsg "Output file \"${OUTPUT_FILE}\" successfully created: "
    LogMsg "-" "$( ls -lZ "${OUTPUT_FILE}" 2>&1 )"

    if [ ${KEEP_WORKING_DIRECTORY} = ${__FALSE} ] ; then
      DIRS_TO_REMOVE="${DIRS_TO_REMOVE} ${CUR_WORKDIR}"
    else
      LogMsg "The working directory \"${CUR_WORKDIR}\" is not deleted"
    fi
  fi  
fi

# ----------------------------------------------------------------------
  
die ${THISRC}

# ----------------------------------------------------------------------
#

