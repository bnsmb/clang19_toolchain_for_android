#
# delete all temporary files and config files in the directory tree /data/local/tmp/sysroot
#
# History
#   24.12.2024 1.0.0 /bs
#     initial version
#   21.01.2026 1.1.0 /bs
#     the files and sub directories for ./home are now copied from ./etc/template/home
#
SYSROOT="${SYSROOT:=/data/local/tmp/sysroot}"

if [ "$1"x != "-x"x -o $# -ne 1  ] ; then
  echo "Usage: $0 [-x]"
  echo "The script deletes all config files in the clang environment in ${SYSROOT} if called with the parameter \"-x\" "
  exit 1
fi

getprop ro.serialno 2>/dev/null >/dev/null
if [ $? -eq 0 ] ; then
  echo "The running OS seems to be Android ...."
  cd ${SYSROOT}
else
  echo "The running OS is not Android"
fi


echo "Removing all config files and temporary files in \"${SYSROOT}\" ...."
\rm -f helloworld_in_c++ 
\rm -f helloworld_in_c
\rm -f helloworld_in_c_with_gcc
\rm -f helloworld_in_c++_with_g++
\rm -f helloworld_in_c++_with_g++_*
\rm -f helloworld_in_c_with_gcc_*
\rm -f ls etc/ssh/*key*
\rm -f etc/security/ca-certificates.crt
\rm -rf etc/security/cacerts/*
\rm -rf var/tmp/*
\rm -rf var/run/*
\rm -rf var/log/*
\rm -rf tmp/*

\rm -rf var/cache/python/*
find usr/lib -name __pycache__ -exec \rm -rf {} +

find var/cache -type f -exec \rm {} +


\rm -rf ./home/shell/.ssh/known_hosts
\rm -rf ./etc/ssh/ssh_config.d/*
\rm -f  ./etc/ssh/ssh_config
\rm -f  ./etc/ssh/sshd_config


\rm -rf home/
\cp -r etc/template/home home

echo " ... done."



