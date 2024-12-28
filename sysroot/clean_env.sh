#!/system/bin/sh
#
# delete all temporary files and config files in the directory tree /data/local/tmp/sysroot
#
# History
#   24.12.2024 1.0.0 /bs
#     initial version
#
SYSROOT="/data/local/tmp/sysroot"

if [ "$1"x != "-x"x -o $# -ne 1  ] ; then
  echo "Usage: $0 [-x]"
  echo "The script deletes all config files in the clang environment in ${SYSROOT} if called with the parameter \"-x\" "
  exit 1
fi

echo "Removing all config files and temporary files in \"${SYSROOT}\" ...."
\rm -f helloworld_in_c++ helloworld_in_c
\rm -f ls etc/ssh/*key*
\rm -f etc/security/ca-certificates.crt
\rm -rf etc/security/cacerts/*
\rm -rf var/tmp/*
\rm -rf var/run/*
\rm -rf var/log/*
\rm -rf tmp/*

\rm -rf var/cache/python/*

find var/cache -type f -exec \rm {} +

\rm -rf /data/local/tmp/sysroot/home/shell/.ssh/known_hosts
\rm -rf /data/local/tmp/sysroot/etc/ssh/ssh_config.d/*


\rm -rf home/shell
mkdir  -p home/shell
cp etc/.bashrc home/shell

mkdir /data/local/tmp/sysroot/home/shell/.ssh

echo " ... done."



