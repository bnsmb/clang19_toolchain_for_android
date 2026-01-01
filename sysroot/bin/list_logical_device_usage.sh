#!/system/bin/sh
#
# list_logical_device_usage.sh - list logical devices configured on a physical device
#
#h#
#h# Usage: list_logical_device_usage.sh [var=value] [--verbose|-v] [--help|-h] [--short] [--noheader] [--noloop] [physical_device]
#h#
#h# Parameter: 
#h#   --verbose | -v  print more messages
#h#   --help | -h     print this usage help
#h#   --short         do not print infos about unknown disk parts
#h#   --noheader      print only the results
#h#   --noloop        ignore loop devices
#h#
#h# "physical_device" is the name of the physical device, example: "sda19", "/dev/block/sda19", or "super"
#h# The default physical device is "super"
#h#
#
# History
#   05.09.2024 1.0.0 /bs
#     initial release
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

typeset -a OUTPUT

typeset -i OUTPUT_COUNT=0

typeset -a DMCTL_TABLE_ENTRIES
typeset -i DMCTL_TABLE_ENTRIES_COUNT=0

CUR_PHYSICAL_DEVICE=""
DEFAULT_PHYSICAL_DEVICE="super"

TMPFILE="${TMPFILE:=/data/local/tmp/tmpfile.$$}"

PRINT_INFOS_ABOUT_UNKNOWN_PARTS=${__TRUE}

PRINT_HEADER=${PRINT_HEADER=${__TRUE}}

IGNORE_LOOP_DEVICES=${__FALSE}

# ---------------------------------------------------------------------

function cleanup {
  typeset THISRC=0
  
  typeset CUR_TIMESTAMP="$( date +"%Y-%m-%d %H:%M:%S" )"

  if [ "${TMPFILE}"x != ""x ] ; then
    [ -r "${TMPFILE}" ] && \rm -f "${TMPFILE}"
  fi
  
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
      IGNORE_LOOP_DEVICES=${__FALSE} 
      ;;

    --noheader | --no_header | --no-header )
      PRINT_HEADER=${__FALSE}
      ;;
  
    -v | --verbose )
      VERBOSE=${__TRUE}
      ;;

    -h | --help )
      PRINT_HELP=${__TRUE}
      ;;

    --short )
      PRINT_INFOS_ABOUT_UNKNOWN_PARTS=${__FALSE}
      ;;

    *=* )
      CUR_VAR="${CUR_PARAMETER%%=*}"
      CUR_VALUE="${CUR_PARAMETER#*=}"
      eval ${CUR_VAR}=\"${CUR_VALUE}\"
      ;;

    * )
      if [ "${CUR_PHYSICAL_DEVICE}"x != ""x ] ; then
        die 100 "Unknown parameter found: ${CUR_PARAMETER}"
      else
        CUR_PHYSICAL_DEVICE="${CUR_PARAMETER}"
      fi
      ;;

  esac
done

# ---------------------------------------------------------------------

LogHeader ""
LogHeader "${SCRIPT_NAME} ${SCRIPT_VERSION} - list logical devices configured on a physical device"

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

CUR_COMMENT=""
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
    LogError " root access to the phone does not work"
    ERRORS_FOUND=${__TRUE}
  fi
fi

# check that the necessary executables exist

if [ "${DMCTL}"x = ""x ] ; then
  echo "ERROR: Executable \"dmctl\" not found"
  ERRORS_FOUND=${__TRUE}
elif ! ${SU_PREFIX} test -x "${DMCTL}"  ; then
  LogError "The file \"${DMCTL}\" is not an executable"
  ERRORS_FOUND=${__TRUE}
fi


[ "${CUR_PHYSICAL_DEVICE}"x = ""x ] && CUR_PHYSICAL_DEVICE="${DEFAULT_PHYSICAL_DEVICE}"

if [[ ${CUR_PHYSICAL_DEVICE} != /* ]] ; then

  if  ${SU_PREFIX} test -r "/dev/block/${CUR_PHYSICAL_DEVICE}" ; then
    CUR_PHYSICAL_DEVICE="/dev/block/${CUR_PHYSICAL_DEVICE}"
  elif  ${SU_PREFIX} test -r "/dev/block/by-name/${CUR_PHYSICAL_DEVICE}"  ; then
    CUR_COMMENT="( = ${CUR_PHYSICAL_DEVICE} )"

    CUR_PHYSICAL_DEVICE="$( ls -l "/dev/block/by-name/${CUR_PHYSICAL_DEVICE}"  | awk '{ print $NF}' )"
  fi
fi

if ! ${SU_PREFIX} test -r "${CUR_PHYSICAL_DEVICE}" ; then
  LogError "The device \"${CUR_PHYSICAL_DEVICE}\" does not exist"
  ERRORS_FOUND=${__TRUE}
fi  
  
[ ${ERRORS_FOUND} = ${__TRUE} ] && die 10 "One or more errors found"


# ---------------------------------------------------------------------



LogHeader ""

CUR_PHYSICAL_DEVICE_NAME="${CUR_PHYSICAL_DEVICE##*/}"

LogHeader "Retrieving the logical device usage map for the device ${CUR_PHYSICAL_DEVICE} ${CUR_COMMENT} ..."


for j in $( for i in $( ${SU_PREFIX} ls -1d /sys/block/dm-*/slaves/${CUR_PHYSICAL_DEVICE_NAME}  | cut -f4 -d "/" ); do ls -l /dev/block/mapper | grep -e "/${i}$"  | awk '{ print $8 };' ; done  ); do 

  LogInfo ""
  LogInfo "Processing the logical devices \"${j}\" ..."

  CUR_LOGICAL_PARTITION_EXTENDS="$( ${SU_PREFIX} ${DMCTL} table $j | tail -n +2 )" ; 

  LogInfo "The table for this logical device is : " && \
    LogMsg "" \
    LogMsg "${CUR_LOGICAL_PARTITION_EXTENDS}"  \
    LogMsg ""

  echo "${CUR_LOGICAL_PARTITION_EXTENDS}" >"${TMPFILE}"
  
  while read CUR_ENTRY ; do

    LogInfo "Processing the extend \"${CUR_ENTRY}\" ...."

    (( DMCTL_TABLE_ENTRIES_COUNT = DMCTL_TABLE_ENTRIES_COUNT + 1 ))
    DMCTL_TABLE_ENTRIES[${DMCTL_TABLE_ENTRIES_COUNT}]="${CUR_ENTRY}"
    
    CUR_LOGICAL_DEVICE_START="$( echo "${CUR_ENTRY}" | awk '{ print $NF} ' )"
    if [[ ${CUR_LOGICAL_DEVICE_START} != [0-9]* ]] ; then
      die 200 "This logical partition type is not supported by this script: \"${CUR_ENTRY}\" "
    fi


    LOGICAL_SIZE="$( echo "${CUR_ENTRY}" | cut -f1 -d ":" )"
    LOGICAL_START="${LOGICAL_SIZE%-*}"
    LOGICAL_END="${LOGICAL_SIZE#*-}"
    ((  CUR_LOGICAL_DEVICE_LENGTH = LOGICAL_END - LOGICAL_START ))
    
    (( CUR_LOGICAL_DEVICE_END = CUR_LOGICAL_DEVICE_START + CUR_LOGICAL_DEVICE_LENGTH ))

    ENTRY_ALREADY_EXIST=${__FALSE}


    CUR_OUTPUT_LINE="$( printf "%-10s %-10s %-10s" ${CUR_LOGICAL_DEVICE_START}  ${CUR_LOGICAL_DEVICE_LENGTH} ${CUR_LOGICAL_DEVICE_END} )"

    i=0
    while [ $i -lt ${OUTPUT_COUNT} ] ; do
      (( i = i + 1 ))    
      
      if [[ ${OUTPUT[$i]} == ${CUR_OUTPUT_LINE}* ]] ; then
        LogInfo "There is already an entry for this extend: \"${OUTPUT[$i]}\" "
        OUTPUT[$i]="${OUTPUT[$i]} = ${j}"
        ENTRY_ALREADY_EXIST=${__TRUE}
        break        
      fi
    done      
    
    if [ ${ENTRY_ALREADY_EXIST} != ${__TRUE} ]; then
      (( OUTPUT_COUNT = OUTPUT_COUNT + 1 ))
      OUTPUT[${OUTPUT_COUNT}]="${CUR_OUTPUT_LINE} $j"
    fi
  done   <"${TMPFILE}" 
done 
  
LogHeader ""

i=0 

while [ $i -lt ${OUTPUT_COUNT} ] ; do
  (( i = i + 1 ))
  echo "${OUTPUT[${i}]}"
done | sort -n  >"${TMPFILE}" 

LAST_END=""

  LogInfo "The list of known logical devices for the device are: " 

  LogInfo "-" "$( printf "%-10s %-10s %-10s %s\n" "Start" "Length" "End" "Used for the Logical Device" )"
  LogInfo "-" " ------------------------------------------------------------- "

  LogInfo "-" 
  LogInfo "-" "$( cat "${TMPFILE}" )"
  LogInfo "-"


LogHeader ""
LogHeader "Logical device usage map for the device ${CUR_PHYSICAL_DEVICE} ${CUR_COMMENT}"
LogHeader ""

LogHeader "$( printf "%-10s %-10s %-10s %s\n" "Start" "Length" "End" "Used for the Logical Device" )"
LogHeader "$(printf "-------------------------------------------------------------\n" )"

while read CUR_LINE ; do

  if [ "${LAST_END}"x != ""x ] ; then
    CUR_START="$( echo "${CUR_LINE}" | awk '{ print $1 }' )"
    if [ "${CUR_START}"x != "${LAST_END}"x ] ; then
      (( CUR_LENGTH = CUR_START - LAST_END ))

      if [ ${PRINT_INFOS_ABOUT_UNKNOWN_PARTS} = ${__TRUE} ] ; then
        printf "%-10s %-10s %-10s %s\n" "${LAST_END}" "${CUR_LENGTH}" "${CUR_START}" "unknown usage"
      fi
    fi
  fi
  LAST_END="$( echo "${CUR_LINE}" | awk '{ print $3 }' )"

  echo "${CUR_LINE}"
done <"${TMPFILE}" 

LogHeader ""

die 0
