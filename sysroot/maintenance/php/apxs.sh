#!/bin/sh

OUTFILE="/data/local/tmp/develop/php815/apx_output"

echo "$*" >>"${OUTFILE}"

case $1 in
  -q )
    case $2 in 
     CFLAGS )
       RESULT_STRING="-fstack-protector-strong -Oz"
       ;;
     
    INCLUDEDIR )
       RESULT_STRING="/data/local/tmp/develop/php815/apache/include/apache"
       ;;
     
    SBINDIR )
       RESULT_STRING="/data/local/tmp/develop/php815"
       ;;
     
    TARGET )
       RESULT_STRING="httpd_wrapper"
       ;;
             
    APU_BINDIR )
       RESULT_STRING="/data/local/tmp/develop/php815"
       ;;
     
    APR_BINDIR )
       RESULT_STRING="/data/local/tmp/develop/php815"
       ;;
     
    APR_CONFIG )
       RESULT_STRING="/data/local/tmp/develop/php815/apr-config"
       ;;
     
    APU_CONFIG )
       RESULT_STRING="/data/local/tmp/develop/php815/apu-config"
       ;;
     
   HTTPD_VERSION )
       RESULT_STRING="2.4.71"
       ;;
     
    esac
    ;;
esac

echo "Resultstring is: \"${RESULT_STRING}\" " >>"${OUTFILE}"

echo ${RESULT_STRING}
