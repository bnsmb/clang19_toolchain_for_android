

[ $# -eq 0 ] && set -- usr/libexec/git-core usr/bin

while [ $# -ne 0 ] ; do
	CUR_DIR="$1"
	shift

	echo 
	echo "*** Processing the perl and python scripts in \"${CUR_DIR}\" ..."
	if [ -d "${CUR_DIR}" ] ; then
		(	
		cd "${CUR_DIR}" && \
			${PREFIX} sed -i \
			  -e "s#/usr/bin/perl#/usr/local/tmp/sysroot/usr/bin/perl#g" \
			  -e "s#/usr/bin/python#/usr/local/tmp/sysroot/bin/python#g"  $( file * | grep "script$" | cut -f1 -d":" )
	        ) 
	else
	  echo "WARNING: Directory \"${CUR_DIR}\" not found"	
	fi
done


