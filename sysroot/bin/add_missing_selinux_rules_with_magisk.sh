#!/system/bin/sh

  MAGISKPOLICY="${MAGISKPOLICY:=$( which magiskpolicy 2>/dev/null )}"

  OS_VERSION="${OS_VERSION:=$( getprop ro.build.version.release  )}"

# use a dummy OS_VERSION if the property does not exist  
#
  OS_VERSION="${OS_VERSION:=99}"
  
  CUR_USER="$( id -un )"
  if [ "${CUR_USER}"x != "root"x ] ; then
    echo "ERROR: $0 must be executed by the user root"
    THISRC=5
  else
  
    if  [ "${MAGISKPOLICY}"x = ""x ] ; then
      echo "ERROR: magiskpolicy not found"
      THISRC=1
    elif [ ! -r "${MAGISKPOLICY}" ] ; then
      echo "ERROR: \"${MAGISKPOLICY}\" does not exist"
      THISRC=2    
    elif [ ! -x "${MAGISKPOLICY}" ] ; then
      echo "ERROR: \"${MAGISKPOLICY}\" is not executable"
      THISRC=3
    else
      echo "Adding missing SELinux policies using \"${MAGISKPOLICY}\" ..."
  
      echo "Enabling socket access for the user \"shell\" (this is necessary to use tmux or ssh-agent)..."
  
      ${MAGISKPOLICY} --live "allow shell shell_data_file sock_file { create getattr setattr write unlink }"  
      ${MAGISKPOLICY} --live "allow shell devpts chr_file { read write open }"
  
      if which mtr 2>/dev/null 1>dev/null ; then
        echo "Enabling icmp_socket access for the user \"shell\" (this is necessary to use mtr)..."
        ${MAGISKPOLICY} --live "allow shell port icmp_socket { name_bind }"    
      fi
  
      echo "Enabling hard links for the user \"shell\" ..."
      ${MAGISKPOLICY} --live "allow shell shell_data_file file link" 
   
  
      echo "Enabling access to proc for the user \"shell\" ..."
      ${MAGISKPOLICY} --live "allow shell proc_swaps file { read open }" 
  
      if [ ${OS_VERSION} -gt 13 ] ; then
        echo "Enabling creating and using fifos for the user \"shell\" ..."
        ${MAGISKPOLICY} --live "allow shell shell_data_file fifo_file { create read open write getattr unlink ioctl }" 
      fi
    fi
  fi
  
  exit ${THISRC}
  
