#!/system/bin/sh
#
#  ./create_empty_library.sh - create an empty library with a random function
#  
#   Usage: ./create_empty_library.sh [libname]
#
case $1 in
  -h | --help  | "" )
     echo "Usage: $0 [libname]"
     exit 4
     ;;
esac

if [ "$CC"x = ""x ] ; then
  if [ -r /data/local/tmp/sysroot/bin/init_clang19_env ] ; then
    source /data/local/tmp/sysroot/bin/init_clang19_env -- >/dev/null 
  else
   echo "ERROR: The environment variable CC is not defined and the file /data/local/tmp/sysroot/bin/init_clang19_env does not exist"
   exit 10
  fi
fi

while [ $# -ne 0 ] ; do
   CUR_LIB="$1"
   shift
   
   [[ ${CUR_LIB} != lib* ]] && CUR_LIB="lib${CUR_LIB}"

   [[ ${CUR_LIB} = *.so ]] && CUR_LIB="${CUR_LIB%*.so}"
   [[ ${CUR_LIB} = *.a ]] && CUR_LIB="${CUR_LIB%*.a}"

   echo "Creating the library \"${CUR_LIB}.so\" ..."

   CUR_DATE="$( date +%s )"

cat<<EOT >foo.c
// foo.c  - make sure to use a unique name for this dummy function!
int __bs_function_${CUR_DATE}() {
    return 42;
}

EOT

  $PREFIX $CC -fPIE -fPIC -c foo.c && \
  $PREFIX $AR rcs "${CUR_LIB}".a foo.o && \
  $PREFIX $CC $LDFLAGS -shared -o "${CUR_LIB}.so" foo.o

  if [ $?  = 0 ] ; then
    echo "Library \"${CUR_LIB}\" successfully created:"
    $PREFIX ls -l "${CUR_LIB}".*

    \rm  foo.c foo.o
  else
    echo "Error creating the library \"${CUR_LIB}\"  "
  fi

done
