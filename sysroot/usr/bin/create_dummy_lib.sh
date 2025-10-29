#!/system/bin/sh

if [[ $* == *-h* || $* == *--help* ]] ; then
  echo "Usage: $0 [libname] [...]"
  exit 1
fi

if [ "$CC"x = ""x ] ; then
  echo "ERROR: The environment variable CC is not set"
  exit 3
fi

if [ "$AR"x = ""x ] ; then
  echo "ERROR: The environment variable AR is not set"
  exit 4
fi


while [ $# -ne 0 ] ; do
  CUR_LIB="$1"
  shift

  [[ ${CUR_LIB}  != lib* ]] && CUR_LIB="lib${CUR_LIB}"

  CUR_LIB="${CUR_LIB%%.*}"

  if [ -r ${CUR_LIB}.so -o -r ${CUR_LIB}.a ] ; then
    echo "The library \"${CUR_LIB}.*\" alread exists:"
    echo
    ls -l ${CUR_LIB}*
    echo
    continue
  fi

  echo "Creating the library \"${CUR_LIB}\" ...."

  cat<<EOT >foo.c
// foo.c  - make sure to use a unique name for this dummy function!
int __bs_function_${CUR_LIB}_42() {
    return 42;
}

EOT

   $CC -fPIE -fPIC -c foo.c && \
  $AR rcs ${CUR_LIB}.a foo.o && \
  $CC $LDFLAGS -shared -o ${CUR_LIB}.so foo.o && \
   ls -l ${CUR_LIB}*
done


