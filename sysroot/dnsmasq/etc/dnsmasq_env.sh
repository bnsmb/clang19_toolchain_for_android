
# environment variables for the scripts in the Magisk Module with dnsmasq
#
# History
#  04.04.2026 /bs
#   initial release
#
# Usage:
#    source /data/local/tmp/sysroot/dnsmasq/etc/dnsmasq_env.sh
#
# or to print one or more variables :
#
#    sh /data/local/tmp/sysroot/dnsmasq/etc/dnsmasq_env.sh <varname>
#

SYSROOT_DIRECTORY="/data/local/tmp/sysroot"

DNSMASQ_BASE_DIRECTORY="${SYSROOT_DIRECTORY}/dnsmasq"

DNSMASQ_ETC_DIRECTORY="${DNSMASQ_BASE_DIRECTORY}/etc"

DNSMASQ_DNSMASQ_D_DIRECTORY="${DNSMASQ_ETC_DIRECTORY}/dnsmasq.d"

DNSMASQ_VAR_DIRECTORY="${DNSMASQ_BASE_DIRECTORY}/var"

DNSMASQ_TFTP_DIRECTORY="${DNSMASQ_BASE_DIRECTORY}/tftp"

DNSMASQ_TFTP_CFG_DIRECTORY="${DNSMASQ_TFTP_DIRECTORY}/pxelinux.cfg"

PID_FILE="${DNSMASQ_BASE_DIRECTORY}/var/run/dnsmasq.pid"

DNSMASQ_DIRECTORIES="
${DNSMASQ_ETC_DIRECTORY}
${DNSMASQ_VAR_DIRECTORY}
${DNSMASQ_TFTP_DIRECTORY}
${DNSMASQ_DNSMASQ_D_DIRECTORY}
#
${DNSMASQ_TFTP_CFG_DIRECTORY}
${DNSMASQ_TFTP_DIRECTORY}/memtest
"

DNSMASQ_START_OPTIONS_FILE="${DNSMASQ_ETC_DIRECTORY}/dnsmasq_options"


DNSMASQ_FILES="
${DNSMASQ_ETC_DIRECTORY}/ethers
${DNSMASQ_ETC_DIRECTORY}/hosts
${DNSMASQ_ETC_DIRECTORY}/resolv.conf
${DNSMASQ_ETC_DIRECTORY}/dnsmasq.conf
${DNSMASQ_ETC_DIRECTORY}/dhcp.conf
${DNSMASQ_ETC_DIRECTORY}/tftp.conf
${DNSMASQ_ETC_DIRECTORY}/dhcp-fix-leases
#
${DNSMASQ_START_OPTIONS_FILE}
#
${DNSMASQ_TFTP_DIRECTORY}/pxelinux.0
#
${DNSMASQ_TFTP_DIRECTORY}/ldlinux.c32  
${DNSMASQ_TFTP_DIRECTORY}/libcom32.c32  
${DNSMASQ_TFTP_DIRECTORY}/libutil.c32  
${DNSMASQ_TFTP_DIRECTORY}/menu.c32 
${DNSMASQ_TFTP_DIRECTORY}/vesamenu.c32
#
${DNSMASQ_TFTP_CFG_DIRECTORY}/graphics.conf
${DNSMASQ_TFTP_CFG_DIRECTORY}/default
#
${DNSMASQ_TFTP_DIRECTORY}/memdisk  
#
${DNSMASQ_TFTP_DIRECTORY}/memtest/memtest 
#
"

DNSMASQ_TEMPLATE_DIR="${MODPATH}/system/usr/share/dnsmasq"

DNSMQASQ_BOOT_IMAGE_DIR="${MODPATH}/system/usr/share/dnsmasq/boot_images"

# The script service.sh does not start the dnsmasq if this file exists
#
DNSMASQ_STOP_FILE="${DNSMASQ_ETC_DIRECTORY}/DO_NOT_START_DNSMASQ"

# dnsmasq binary
#
DNSMASQ_BINARY="/data/local/tmp/sysroot/usr/bin/dnsmasq"


# ---------------------------------------------------------------------
# the next statement must be the last statement in this file!

DNSMASQ_ENV_INITIALIZED=0

# ---------------------------------------------------------------------
# print the values of requsted variables
#
while [ $# -ne 0 ] ; do
  eval echo "\$$1"
  shift
done

# ---------------------------------------------------------------------

