
export PYTHONPYCACHEPREFIX=/data/local/tmp/pycache
export TMPDIR=/data/local/tmp/tmp
export HOME=/data/local/tmp/ 

mkdir -p $PYTHONPYCACHEPREFIX $TMPDIR

# export LD_LIBRARY_PATH=$PWD:/data/local/tmp/develop/sysroot/usr/lib  

TESTS_TO_EXCLUDE=" test_capi test_code test_ctypes test_frame test_threading test_android test_grp  test_tarfile test_logging"


if [ "$1"x != "-h"x -a "$1"x != "--help"x ] ; then

  set -x
  ${PREFIX} python3 -X faulthandler -m test $* --tempdir=$TMPDIR 
  set +x
else
  echo
  echo "Usage: $0 [parameter_for_the_python_test_program]"
  echo

  echo "
Use 

${PREFIX} python3 -X faulthandler -m test $* --tempdir=$TMPDIR --list-tests

to list the tests that would be executed

Use the parameter

-x <testname>

to exclude a test

Tests to be known not to run on Android are:

${TESTS_TO_EXCLUDE}

To exclude these tests use these parameter:


$( printf "${TESTS_TO_EXCLUDE}" | sed "/^#/d"  | tr "\n" " " | tr -s " " |  sed "s/ / -x /g" )

Note:

The tests

test.test_pydoc.test_pydoc
test_py_compile
test_import
test_importlib
test_compileall    

only work for non-root user in permissive SELinux mode!

Some tests only work if the test directory being used is still located within the same directory structure as the Python source files.
"
fi
