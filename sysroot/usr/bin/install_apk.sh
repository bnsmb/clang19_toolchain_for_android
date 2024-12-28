# no shebang because the location for the shell on the PC and the phone are different

# Simple script to install one or more apk files on an Android phone 
#
# The script can run either on the phone or on a PC with an adb connection to a phone
#
#h#
#h# Usage:
#h#
#h# install_apk.sh [options_for_adb -- ] [options_for_pm_install] [--old] [apk1|dir1 ... apk#|dir#]
#h#
#h# Use the parameter "-h -v" to print the detailed usage help
#h#
#H# "options_for_adb" are the options for the command "adb". The parameter "--" is mandatory if adb options are specified in the parameter.
#H# The options for adb are optional; the script does not check the options for adb. options for adb are not allowed if running a shell on the phone.
#H#
#H# "options_for_pm" are the options for the command "pm install". the script does not check the options for the "pm install" command.
#H#
#H# "--old" is a short cut for the "pm install" command option "--bypass-low-target-sdk-block"; this option is necessary to install apks build for 
#H# outdated sdk versions.
#H#
#H# apk# is the name of an apk file to install; dir# is a directory with apk files
#H# If a parameter is a directory the script installs all files with the extension .apk from that directory
#H#
#H# The number of apk files or directories is only limited by the  maxium parameter supported by the used shell.
#H#
#H# Additional parameter for the "pm install" command can also be defined in the environment variable PM_INSTALL_OPTIONS before starting the script.
#H#
#H# Usefull options for "pm install":
#H#
#H#  --bypass-low-target-sdk-block   -> install apk file with outdated sdk version
#H#
#H#  -g                              -> apply all runtime permissions
#H#
#H#  -r -d                           -> downgrade an apk (this only works if the pm command is executed as root user)
#H#                                     examples: su - -c 'PM_INSTALL_OPTIONS="-r -d " /data/local/tmp/install_apk.sh  /sdcard/Download/com.machiav3lli.backup_8316.apk '  
#H#                                            or su - -c "/data/local/tmp/install_apk.sh  -r -d /sdcard/Download/com.machiav3lli.backup_8316.apk "  
#H# --enable-rollback                -> using this parameter the current app version can later be restored using using "pm rollback-app"
#H#                                     Use the command " device_config get rollback_boot rollback_lifetime_in_millis  " to get the time in milliseconds the rollback version
#H#                                     will be kept
#H#
#H# To use adb via WLAN enable adb via WiFi on the phone, start the adb for WLAN on the PC, example:
#H# 
#H#   adb -e -L tcp:localhost:5237 connect 192.168.1.148:6666
#H# 
#H# and then use a command like this to install apks using the script:
#H# 
#H#   ./install_apk.sh -e -L tcp:localhost:5237 -- /data/Downloads/com.machiav3lli.backup_8317.apk
#H# 
#H#
# 
# Prerequisites
#   The packages to install must exist as file either on the PC or on the phone
#   A shell on the phone or a connection via adb command to the phone is required
#   No root access is neccessary (except for downgrading an app)
#
# Note
#
# The script does not check for duplicate parameter
#
# History
#   04.07.2022 /bs
#     initial release
#
#   04.08.2022 /bs
#     fixed a minor bug (ERROR: The file "" does not exist or is not readable)
#
#   08.01.2023 /bs
#     the script now ends with a return code not zero if one or more apps could not be found or could not be installed
#
#   24.12.2023 /bs
#     added a hint to the error message about how to ignore outdated SDKs if using Android 14 or newer
#
#   04.02.2024 /bs
#     replaced "LogMsg" with "echo" (the function LogMsg is not defined in this script)
#
#   02.05.2024 /bs
#     the script failed to handle symbolic links correct -- fixed
#
#   04.08.2024 2.0.0 /bs
#     added parameter to define the options for the "pm install" command
#     added an extended usage help; use "-h -v" to view the extended usage help
#

# read the script version from the script source code
#
SCRIPT_VERSION="$( grep -E "^#.*/bs" $0 | tail -1 | awk '{ print $3 }' )"

SCRIPT_NAME="${0##*/}"


# constants
#
__TRUE=0
__FALSE=1

# for debugging
#
#PREFIX="echo"
#PREFIX=""

typeset THISRC=${__TRUE}

# check if we're running on a phone
#
CUR_PHONE_MODEL="$(  getprop ro.product.odm.model 2>/dev/null )"
CUR_PHONE_SERIAL="$( getprop ro.serialno 2>/dev/null )"

if [ "${CUR_PHONE_SERIAL}"x != ""x ] ; then
  SCRIPT_IS_RUNNING_ON_A_PHONE=${__TRUE}
else
  SCRIPT_IS_RUNNING_ON_A_PHONE=${__FALSE}
fi

# check for the usage parameter
#  
if [ "$1"x = "-h"x -o "$1"x = "--help"x  -o $# -eq 0 ] ; then
  grep "^#h#" $0 | cut -c4-
 
  if [[ " $* " == *\ --verbose\ * || " $* " == *\ -v\ * ]] ; then
    grep "^#H#" $0 | cut -c4-
  fi
  exit 1
fi


echo "${SCRIPT_NAME} ${SCRIPT_VERSION} started on $( date )"

# default : Android Version unknown
#
ANDROID_VERSION=0
 
if [ ${SCRIPT_IS_RUNNING_ON_A_PHONE} = ${__TRUE} ] ; then
  echo "Running on a phone"

  ADB_COMMAND=""

  if [[ $* == *\ --\ * ]] ; then
    echo "ERROR: adb parameter are not supported if running on a phone"
    exit 6
  fi

  ANDROID_VERSION="$( getprop ro.build.version.release )"

else
  echo "Running on a PC"
  ADB="$( which adb 2>/dev/null )"
  if [ "${ADB}"x = ""x ] ; then
    echo "ERROR: adb executable not found"
    exit 5
  fi

  ADB_OPTIONS=""

  
# get the parameter for adb if any 
#
  if [[ $* == *\ --\ * ]] ; then
    while [ $# -ne 0 ] ; do
      CUR_PARAMETER="$1"
      shift
      [ "${CUR_PARAMETER}"x = "--"x ] && break
      
      ADB_OPTIONS="${ADB_OPTIONS} ${CUR_PARAMETER}"
    done
  fi

  if [ "${ADB_OPTIONS}"x != ""x ] ; then
    echo "Using adb with the options \"${ADB_OPTIONS}\" to install the packages "
  else
    echo "Using adb to install the packages"
  fi    
  
  ADB_COMMAND="${ADB} ${ADB_OPTIONS} shell "

  ANDROID_VERSION="$( ${ADB_COMMAND} getprop ro.build.version.release )"
  
  CUR_OUTPUT="$( ${PREFIX} ${ADB_COMMAND} uname -a 2>&1 )"
  if [ $? -ne 0 ] ; then
    echo "${CUR_OUTPUT}"
    echo ""
    echo "ERROR: No connected phone found"
    exit 100
  fi

  CUR_PHONE_MODEL="$( ${ADB_COMMAND} getprop ro.product.odm.model 2>/dev/null )"
  CUR_PHONE_SERIAL="$( ${ADB_COMMAND} getprop ro.serialno 2>/dev/null )"
fi

# init the global variables
#   
APKS_INSTALLED=""
NO_OF_APKS_INSTALLED=0

APKS_NOT_INSTALLED=""
NO_OF_APKS_NOT_INSTALLED=0

APKS_NOT_FOUND=""
NO_OF_APKS_NOT_FOUND=0

# check for directories in the parameter
#
APKS_TO_INSTALL=""

PARAMETER_FOR_PM=""

for CUR_PARAMETER in $* ; do
  
  if [[ ${CUR_PARAMETER} == --old || ${CUR_PARAMETER} == -old ]] ; then
    PARAMETER_FOR_PM="${PARAMETER_FOR_PM} --bypass-low-target-sdk-block"   
  elif [[ ${CUR_PARAMETER} == -* ]] ; then
    PARAMETER_FOR_PM="${PARAMETER_FOR_PM} ${CUR_PARAMETER}"   
  elif [ -d "${CUR_PARAMETER}"  ] ; then
    echo "Directory found in the parameter: Installing all apk files found in the directory \"${CUR_PARAMETER}\" "
    APKS_TO_INSTALL="${APKS_TO_INSTALL} $( find ${CUR_PARAMETER} -name "*.apk"  )"
  else
    APKS_TO_INSTALL="${APKS_TO_INSTALL} 
${CUR_PARAMETER}"
  fi
  shift
done

echo "The apks will be installed on the phone model ${CUR_PHONE_MODEL} with the serial number ${CUR_PHONE_SERIAL} "


echo "Installing these apks "
echo "${APKS_TO_INSTALL}"
echo ""


if [ "${PARAMETER_FOR_PM}"x != ""x ] ; then
  echo "The parameter for the commmand \"pm install\" found in the script parameter are: \"${PARAMETER_FOR_PM}\" "
fi

if [ "${PM_INSTALL_OPTIONS}"x != ""x ] ; then
  echo "The additional parameter for the command \"pm install\" found in the environment variable PM_INSTALL_OPTIONS are: \"${PM_INSTALL_OPTIONS}\" "
fi

CUR_PM_PARAMETER="${PM_INSTALL_OPTIONS} ${PARAMETER_FOR_PM}"

echo "${APKS_TO_INSTALL}
##EXIT##" | while read CUR_APK ; do
  
  if [ "${CUR_APK}"x = "##EXIT##"x ] ; then
#
# ##EXIT## is the end marker
#
# the while loop is running in a sub shell so that the variables used for the statistics are not available outside the sub shell
# the construct with the subshell is used to support filenames with whitespaces
#
  
    echo ""
    echo "Installation summary"
    echo "===================="

    if [ ${NO_OF_APKS_INSTALLED} != 0 ] ; then
      echo ""
      echo "${NO_OF_APKS_INSTALLED} package(s) successfully installed:"
      echo "${APKS_INSTALLED}"
      echo ""
    fi

    if [ ${NO_OF_APKS_NOT_INSTALLED} != 0 ] ; then
      echo ""
      echo "${NO_OF_APKS_NOT_INSTALLED} package(s) not installed:"
      echo "${APKS_NOT_INSTALLED}"
      echo ""

      if [  ${ANDROID_VERSION} -ge 14 ] ; then 

        echo "Note:
        
To ignore the error about outdated SDKs, e.g.

\"Failure [INSTALL_FAILED_DEPRECATED_SDK_VERSION: App package must target at least SDK version 23, but found 19]\"

use the script parameter \"--old\" or set the environment variable PM_INSTALL_OPTIONS to \"--bypass-low-target-sdk-block\" before starting the script
"
      fi

      THISRC=${__FALSE}
    fi

    if [ ${NO_OF_APKS_NOT_FOUND} != 0 ] ; then
      echo ""
      echo "${NO_OF_APKS_NOT_FOUND} package(s) not found:"
      echo "${APKS_NOT_FOUND}"
      echo ""
      THISRC=${__FALSE}
    fi
  
    break
  fi
  
  echo ""
  [ "${CUR_APK}"x = ""x ] && continue
  if [ ! -r "${CUR_APK}" ] ; then
    echo "ERROR: The file \"${CUR_APK}\" does not exist or is not readable"
    APKS_NOT_FOUND="${APKS_NOT_FOUND} 
${CUR_APK}"
    (( NO_OF_APKS_NOT_FOUND = NO_OF_APKS_NOT_FOUND +1 ))
    continue
  fi

  CUR_APK_SIZE="$( ls -lL "${CUR_APK}" | awk '{ print $5 }' )"
  echo "Installing the apk \"${CUR_APK}\" ..."
  cat "${CUR_APK}" | ${PREFIX} ${ADB_COMMAND} pm install ${CUR_PM_PARAMETER} -S ${CUR_APK_SIZE}
#
  if [ $? -eq 0 ] ; then
    echo "\"${CUR_APK}\" succcessfully installed"

    APKS_INSTALLED="${APKS_INSTALLED} 
${CUR_APK}"
    (( NO_OF_APKS_INSTALLED = NO_OF_APKS_INSTALLED +1 ))
  else
    echo "ERROR: Error installing the apk  \"${CUR_APK}\" "

    APKS_NOT_INSTALLED="${APKS_NOT_INSTALLED} 
${CUR_APK}"
    (( NO_OF_APKS_NOT_INSTALLED = NO_OF_APKS_NOT_INSTALLED +1 ))

  fi
  
done

echo ""

exit ${THISRC}
