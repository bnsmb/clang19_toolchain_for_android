#!/system/bin/sh
#
# list_logical_device_backends.sh - list the backends for logical devices
#
#h#
#h# Usage: list_logical_device_backends.sh [var=value] [--verbose|-v] [--help|-h] [--noheader] [--noloop] [logical_device# ...]
#h#
#h# Parameter: 
#h#   --verbose | -v  print more messages
#h#   --help | -h     print this usage help
#h#   --noheader      print only the results
#h#   --noloop        ignore loop devices
#h#
# History
#   05.09.2024 1.0.0 /bs
#     initial release
#
#   07.09.2024 1.1.0 /bs
#     added the parameter --noloop to ignore loop devices
#

__TRUE=0
__FALSE=1


# for debugging
#
#PREFIX="echo"
#PREFIX=""

SCRIPT_VERSION="$( grep -E "^#.*/bs" $0 | tail -1 | awk '{ print $3 }' )"

SCRIPT_NAME="${0##*/}"

SCRIPT_COMMAND="$0"

SCRIPT_PARAMETER="$*"

DMCTL="${DMCTL:=$( which dmctl )}"

PRINT_HEADER=${PRINT_HEADER=${__TRUE}}

IGNORE_LOOP_DEVICES=${__FALSE}

# ---------------------------------------------------------------------

function cleanup {
  typeset THISRC=0
  
  
  typeset CUR_TIMESTAMP="$( date +"%Y-%m-%d %H:%M:%S" )"

  return ${THISRC}
}

# install a trap handler for house keeping
#
trap "cleanup"  0

function LogMsg {
  echo "$@"
  return ${__TRUE}
}

function LogHeader {
  typeset THISRC=${__FALSE}
  
  if [ ${PRINT_HEADER}x = ${__TRUE}x  ] ; then
    echo "$@"
    THISRC=${__TRUE}
  fi
  
  return ${THISRC}
}

function LogInfo {
  typeset THISMSG=""

  if [[ "$1"x = "-"x ]] ; then
    shift
    THISMSG="$@" 
  else
    THISMSG="INFO: $@"
  fi
  
  [[ ${VERBOSE} == ${__TRUE} ]] && LogMsg "${THISMSG}" >&2 || return ${__FALSE}
}

function LogError {
  LogMsg "ERROR: $@" >&2
}

function die {
  typeset THISRC=$1

  [ $# -gt 0 ] && shift

  typeset THISMSG="$*"
  
  if [ "${THISRC}"x = "0"x -o "${THISRC}"x = "1"x ] ; then
     [ "${THISMSG}"x != ""x ] && LogMsg "${THISMSG} (RC=${THISRC})"
  else
    ERRORS_FOUND=${__TRUE}
    LogError "${THISMSG} (RC=${THISRC})"
  fi
  exit ${THISRC}
}

# ---------------------------------------------------------------------
# process the parameter 
#

LIST_OF_LOGICAL_DEVICES=""

PRINT_HELP=${__FALSE}

while [ $# -ne 0 ] ; do

  CUR_PARAMETER="$1"
  shift
  
  case ${CUR_PARAMETER} in

    --noloop | --no_loop | --no-loop )
      IGNORE_LOOP_DEVICES=${__TRUE} 
      ;;

    --noheader | --no_header )
      PRINT_HEADER=${__FALSE}
      ;;

    -v | --verbose )
      VERBOSE=${__TRUE}
      ;;

    -h | --help )
      PRINT_HELP=${__TRUE}
      ;;
  
    *=* )
      CUR_VAR="${CUR_PARAMETER%%=*}"
      CUR_VALUE="${CUR_PARAMETER#*=}"
      eval ${CUR_VAR}=\"${CUR_VALUE}\"
      ;;

    * )
      LIST_OF_LOGICAL_DEVICES="${LIST_OF_LOGICAL_DEVICES} ${CUR_PARAMETER}"
      PRINT_HEADER="${__FALSE}"
      
      ;;

    * )
      die 100 "Unknown parameter found: ${CUR_PARAMETER}"
      ;;
  esac
done

# ---------------------------------------------------------------------

LogHeader ""
LogHeader "${SCRIPT_NAME} ${SCRIPT_VERSION} - list the backends for logical devices "


if [ ${PRINT_HELP} = ${__TRUE} ] ; then
  grep "^#h#" $0 | cut -c4-
      
  if [ "${VERBOSE}"x != ""x ] ; then
    CUR_ENV_VARS=$( grep -v "^#" $0 | grep ":=" | cut -f1 -d"=" | grep -v CUR_ENV_VARS )
    if  [ "${CUR_ENV_VARS}"x != ""x ] ; then
      echo 
      echo "The environment variables supported by this script are:"
      echo 
      for CUR_VAR in ${CUR_ENV_VARS} ; do
        eval CUR_VALUE="\"\$${CUR_VAR}\""
        echo "${CUR_VAR}; the current value is \"${CUR_VALUE}\" "
      done
      echo
    fi
  else
    echo "Use the parameter \"-v -h\" to also print the list of supported environment variables"
  fi
  
  IN_USAGE_HELP=${__TRUE}
  exit 1 

fi


# ---------------------------------------------------------------------

ERRORS_FOUND=${__FALSE}

# check if we do have root access on the phone

SU_PREFIX=""

CUR_ID="$( id -un )"
if [ "${CUR_ID}"x = "root"x ] ; then
  LogInfo "root access without any prefix works"
else
  CUR_ID="$( su - -c id -un )"
  if [ "${CUR_ID}"x = "root"x ] ; then
    SU_PREFIX="su - -c "
    LogInfo "Using the prefix \"${SU_PREFIX}\" for root access"
  else
    LogError "root access to the phone does not work"
    ERRORS_FOUND=${__TRUE}
  fi
fi

# check that the necessary executables exist

if [ "${DMCTL}"x = ""x ] ; then
  LogError "Executable \"dmctl\" not found"
  ERRORS_FOUND=${__TRUE}
elif ! ${SU_PREFIX} test -x "${DMCTL}"  ; then
  LogError "The file \"${DMCTL}\" is not an executable"
  ERRORS_FOUND=${__TRUE}
fi

if [ "${LIST_OF_LOGICAL_DEVICES}"x = ""x -a "${DMCTL}"x != ""x ] ; then
  LogHeader "Retrieving the list of logical devices ..."
  LIST_OF_LOGICAL_DEVICES="$( ${SU_PREFIX} ${DMCTL} list devices | tail -n +2 | awk '{ print $1}' )"
  
fi

if [ "${LIST_OF_LOGICAL_DEVICES}"x = ""x ] ; then
  LogError "No logical devices found"
  ERRORS_FOUND=${__TRUE}
fi
   
[ ${ERRORS_FOUND} = ${__TRUE} ] && die 10 "One or more errors found"

# ---------------------------------------------------------------------

if [ ${PRINT_HEADER} = ${__TRUE} ] ; then
  LogHeader ""
  LogHeader "# Logical device = dm device [ -> backend_device ] -> backend device [= symbolic name for backend device]"

  if [ ${IGNORE_LOOP_DEVICES} = ${__FALSE} ] ; then

    LogHeader "# or"
  
    LogHeader "# Logical device = dm device -> loop device = backend file for the loop device "
  fi
  
  LogHeader ""
fi

RESULT_MESSAGES=""

for CUR_LOGICAL_DEVICE in ${LIST_OF_LOGICAL_DEVICES} ; do 
  LogInfo ""
  LogInfo "# Processing the logical device \"${CUR_LOGICAL_DEVICE}\" ..."

  CUR_OUTPUT_LINE=""

  if [[ ${CUR_LOGICAL_DEVICE} == dm-[0-9]* ]] ; then
    CUR_DM_DEVICE="${CUR_LOGICAL_DEVICE}"
   elif [ -r /dev/block/${CUR_LOGICAL_DEVICE} ] ; then
    CUR_DM_DEVICE="${CUR_LOGICAL_DEVICE##*/}"
  else   
    CUR_DM_DEVICE="$( ${SU_PREFIX} ${DMCTL} getpath ${CUR_LOGICAL_DEVICE} )"
    CUR_DM_DEVICE="${CUR_DM_DEVICE##*/}"
  fi
  
  if [ "${CUR_DM_DEVICE}"x = ""x ] ; then
    LogError "Can not detect the dm device for \"${CUR_LOGICAL_DEVICE}\" "
    continue
  fi
  
  CUR_DM_DEVICE_BACKEND="$( ${SU_PREFIX} ls /sys/block/${CUR_DM_DEVICE}/slaves )"
  
  CUR_OUTPUT_LINE="${CUR_LOGICAL_DEVICE} = ${CUR_DM_DEVICE} -> ${CUR_DM_DEVICE_BACKEND} "


  if [[ ${CUR_DM_DEVICE_BACKEND} == loop* ]] ; then  

    if [ ${IGNORE_LOOP_DEVICES} = ${__FALSE} ] ; then

      CUR_LOOP_DEVICE_BACKEND_FILE="$( ${SU_PREFIX} cat /sys/block/${CUR_DM_DEVICE_BACKEND}/loop/backing_file )"

      CUR_OUTPUT_LINE="${CUR_OUTPUT_LINE} = ${CUR_LOOP_DEVICE_BACKEND_FILE}"    
    else
      continue
    fi
    
  else
    if [[ ${CUR_DM_DEVICE_BACKEND} == dm* ]] ; then
      CUR_DM_DEVICE_BACKEND="$( ${SU_PREFIX} ls /sys/block/${CUR_DM_DEVICE_BACKEND}/slaves )"
      CUR_OUTPUT_LINE="${CUR_OUTPUT_LINE} -> ${CUR_DM_DEVICE_BACKEND} "
    fi
  
    CUR_DM_DEVICE_BACKEND_SYMBOLIC_NAME="$( ls  -l /dev/block/by-name/ | grep -e "/${CUR_DM_DEVICE_BACKEND}$" | awk '{ print $8 }' )"
    if [ "${CUR_DM_DEVICE_BACKEND_SYMBOLIC_NAME}"x != ""x ] ; then     
      CUR_OUTPUT_LINE="${CUR_OUTPUT_LINE} = \"${CUR_DM_DEVICE_BACKEND_SYMBOLIC_NAME}\""
    fi 
  fi

  RESULT_MESSAGES="${RESULT_MESSAGES}
${CUR_OUTPUT_LINE}"  

done

LogMsg "$( echo "${RESULT_MESSAGES}"  | sort -r )"
  
LogHeader ""
die 0


# ---------------------------------------------------------------------
