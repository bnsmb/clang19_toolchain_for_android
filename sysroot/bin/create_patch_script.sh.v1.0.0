#!/bin/sh
# 
# simple script to create a script with the commands to patch the source file for all patch files (*.patch) in the current directory
#
# I use this script to apply the patches from Termux for the various tools
#
# History
#   24.12.2024 v1.0.0 /bs
#     initial version
#

PATCH_SCRIPT="${PWD}/apply_patches.sh"

PATCH_SCRIPT_CONTENTS='#!/bin/sh

function mycp {

  if [ ! -r $2 ] ; then
    cp $1 $2
  else
    echo "$2 already exist"
  fi
}
'

for CUR_PATCH in *.patch ;do
  echo
  echo "Processing the patch \"${CUR_PATCH}\" ..."


  TARGET_FILE="$( grep "^+++" "${CUR_PATCH}" | head -1 | awk '{ print $2 }' )"
  if [ "${TARGET_FILE}"x = ""x ] ; then
    echo "ERROR: No file to patch found in the file \"${CUR_PATCH}\" "
    continue
  fi

  SOURCE_FILE="${TARGET_FILE}"

  while [ "${SOURCE_FILE}"x != ""x ] ; do
    [ -r "../${SOURCE_FILE}" ] && break
    if [[ ${SOURCE_FILE} != */* ]] ; then
      SOURCE_FILE=""
      break
    fi 
    SOURCE_FILE="${SOURCE_FILE#*/}"
  done

  if [ "${SOURCE_FILE}"x = ""x ] ; then

    SOURCE_FILE="$( grep "^---" "${CUR_PATCH}" | head -1 | awk '{ print $2 }' )"
    while [ "${SOURCE_FILE}"x != ""x ] ; do
      [ -r "../${SOURCE_FILE}" ] && break
      if [[ ${SOURCE_FILE} != */* ]] ; then
        SOURCE_FILE=""
        break
      fi
      SOURCE_FILE="${SOURCE_FILE#*/}"
    done
  fi

  if [ "${SOURCE_FILE}"x = ""x ] ; then
    echo "WARNING: The file \"${TARGET_FILE}\" does not exist"
    LINE_START="#"
  else
    echo "The patch is for the file \"${SOURCE_FILE}\" "
    LINE_START=""
  fi    

  PATCH_SCRIPT_CONTENTS="${PATCH_SCRIPT_CONTENTS}
echo 
echo \"*** Patch: ${CUR_PATCH}\"
${LINE_START} \${PREFIX} mycp \"../${SOURCE_FILE}\" \"../${SOURCE_FILE}.org\"
${LINE_START} \${PREFIX} patch \"../${SOURCE_FILE}\" \"${CUR_PATCH}\"
"

done
echo 

if [ -r "${PATCH_SCRIPT}" ] ; then
  PATCH_SCRIPT_BACKUP="${PATCH_SCRIPT}.$$.bkp"
  echo "Creating a backup of the patch script in \"${PATCH_SCRIPT_BACKUP}\" ..."
  mv "${PATCH_SCRIPT}" "${PATCH_SCRIPT_BACKUP}"
fi

echo "Creating the patch script in \"${PATCH_SCRIPT}\" ..."

echo "${PATCH_SCRIPT_CONTENTS}" >"${PATCH_SCRIPT}" && chmod 755 "${PATCH_SCRIPT}"
echo
ls -l "${PATCH_SCRIPT}"
echo  
