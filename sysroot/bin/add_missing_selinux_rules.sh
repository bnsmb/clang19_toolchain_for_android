#!/system/bin/sh

SEPOLICY_INJECT="${SEPOLICY_INJECT:=$( which sepolicy-inject )}"

LOAD_POLICY="${LOAD_POLICY:=$( which load_policy )}"

TMP_SEPOLICY_FILE="${TMP_SEPOLICY_FILE:=/data/local/tmp/policy}"


if  [ "${SEPOLICY_INJECT}"x != ""x -a "${LOAD_POLICY}"x != ""x ] ; then
  echo "Copying the current SELinux policy to \"${TMP_SEPOLICY_FILE}\" ..."

  cp /sys/fs/selinux/policy "${TMP_SEPOLICY_FILE}"
  if [ $? -eq 0 ] ; then

    echo "Enabling socket access for the user \"shell\" (this is necessary to use tmux)..."
	  
# allow shell shell_data_file sock_file { create getattr setattr write unlink }
#
    sepolicy-inject -s shell -t shell_data_file -c sock_file -p create,getattr,setattr,write,unlink -P "${TMP_SEPOLICY_FILE}" -o "${TMP_SEPOLICY_FILE}"

# allow shell devpts chr_file { read write open }	
#
    sepolicy-inject -s shell -t devpts -c chr_file -p read,write,open -P "${TMP_SEPOLICY_FILE}" -o "${TMP_SEPOLICY_FILE}"

    echo "Enabling hard links for the user \"shell\" ..."

# allow shell shell_data_file file link	
#
    sepolicy-inject -s shell -t shell_data_file -c file -p link -P "${TMP_SEPOLICY_FILE}" -o "${TMP_SEPOLICY_FILE}"


    echo "Enabling creating and using fifos for the user \"shell\" ..."
    
# allow shell shell_data_file fifo_file { create read open write getattr unlink ioctl }	
#
    sepolicy-inject -s shell -t shell_data_file -c fifo_file -p create,read,open,write,getattr,unlink,ioctl -P "${TMP_SEPOLICY_FILE}" -o "${TMP_SEPOLICY_FILE}"  


# allow shell port icmp_socket { name_bind }
#
    echo "Enabling icmp_socket access for the user \"shell\" (this is necessary to use mtr)..."
    sepolicy-inject -s shell -t port -c icmp_socket -p name_bind -P "${TMP_SEPOLICY_FILE}" -o "${TMP_SEPOLICY_FILE}" 


    echo "Reloading the SELinux policy from the file \"${TMP_SEPOLICY_FILE}\" ..."   
    cp "${TMP_SEPOLICY_FILE}" /sys/fs/selinux/policy  && \
      /system/bin/load_policy "${TMP_SEPOLICY_FILE}" 
    if [ $? -eq 0 ] ; then
      echo " ... updated SELinux policy successfully loaded"
    else
      echo "ERROR: Error loading the updated SELinux policy"
    fi
  else
    echo "ERROR: Error copying the current SELinux policy to \"${TMP_SEPOLICY_FILE}\" ..."

  fi
else
  echo "ERROR: The executables sepolicy-inject and/or load_policy are not available via PATH"
fi

