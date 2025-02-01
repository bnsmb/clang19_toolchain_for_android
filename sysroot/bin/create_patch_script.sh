#!/bin/sh
# 
# simple script to create a script with the commands to patch the source file for all patch files (*.patch) in the current directory
#
# I use this script to apply the patches from Termux for the various tools
#
# History
#   24.12.2024 v1.0.0 /bs
#     initial version
#   01.02.2025 v1.1.0 /bs
#     the script now uses "patch -p1 <patchfile" to apply the patches
#     in the previous version the patch script created by this script only applied the 1st patch from patch files with more then one patch
#

__TRUE=0
__FALSE=1


# the target patch script
#
PATCH_SCRIPT="${PWD}/apply_patches.sh"

# the directory with the patches
#
PATCH_DIR="$( pwd )"

# the header of the patch script
#
PATCH_SCRIPT_CONTENTS='#!/bin/sh

function mycp {

  if [ -r $1 ] ; then
    if [ ! -r $2 ] ; then
      cp $1 $2
    else
      echo "The target file $2 already exists"
    fi
  else
    echo "The source file $1 does not exist"
  fi
}

PATCH="$( which gnupatch || which patch )"

echo "Using the patch binary $PATCH"

'

PATCHES_FOUND=${__FALSE}
for CUR_PATCH in *.patch ;do
  [[ ${CUR_PATCH} == '*.patch' ]] && break

  PATCHES_FOUND=${__TRUE}
  echo
  echo "Processing the patch \"${CUR_PATCH}\" ..."

  TARGET_FILES="$( egrep -- "^--- " "${CUR_PATCH}"  | awk '{ print $2 }' | cut -f2- -d/  )"

  PATCH_SCRIPT_CONTENTS="${PATCH_SCRIPT_CONTENTS}
echo \"*** Patch: ${CUR_PATCH}\"
"

  for i in ${TARGET_FILES} ; do
    PATCH_SCRIPT_CONTENTS="${PATCH_SCRIPT_CONTENTS}
mycp ${i} ${i}.org
"
  done

  PATCH_SCRIPT_CONTENTS="${PATCH_SCRIPT_CONTENTS}
\${PREFIX} \${PATCH} -p1 <${PATCH_DIR}/${CUR_PATCH}
"
done
echo 

if [ ${PATCHES_FOUND} = ${__TRUE} ] ; then
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
  echo "Doing a syntax check for the script \"${PATCH_SCRIPT}\" ..."
  sh -x -n "${PATCH_SCRIPT}"
  if [ $? -eq 0 ] ; then
    echo "OK, no syntax errors found"
  else
    echo "ERROR: Something went wrong creating the patch script"
  fi
else
  echo "ERROR: No patches found in the current directory"
fi
