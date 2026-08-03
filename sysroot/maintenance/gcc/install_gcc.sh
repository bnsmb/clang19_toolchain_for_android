echo
echo "Installing the GCC ..."
echo

${CMD_PREFIX} wget https://cdn.jsdelivr.net/gh/AmanoTeam/android-gcc-cross@master/tools/termux-install.sh
${CMD_PREFIX} sed -i -e "s/--symbolic/-s/g" -e "s/--force/-f/g" -e "s/--recursive/-r/g" gcc-install.sh
${CMD_PREFIX} sed -i -e "s#/data/data/com.termux/files/usr/bin/bash#/data/local/tmp/sysroot/usr/bin/bash#g" gcc-install.sh 
${CMD_PREFIX} sed -i -e "s#/data/data/com.termux/files/usr/lib/android-gcc-cross#/data/local/tmp/sysroot/usr/lib/android-gcc-cross#g" gcc-install.sh 

export PREFIX=/data/local/tmp/sysroot/usr/gcc
export HOME=/data/local/tmp/sysroot/home

${CMD_PREFIX} mkdir -p ${CMD_PREFIX}/bin ${CMD_PREFIX}/usr/lib/ ${CMD_PREFIX}/home
${CMD_PREFIX} chmod 755 /data/local/tmp/gcc-install.sh
( ${CMD_PREFIX} cd / && ${CMD_PREFIX} /data/local/tmp/gcc-install.sh )

echo
echo "Use the script ./maintenance/fix_gcc_installation.sh to delete all files not neccessary for arm64 CPUs and create the correct symbolic links"
echo

