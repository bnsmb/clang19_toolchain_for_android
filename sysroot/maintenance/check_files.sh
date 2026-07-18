# 
CPU_TYPE="$( uname -m )"

echo "Checking the files in \"${PWD}\" ..."

echo "Searching executables not for aarch64 ..."

time find . -type f -exec file {} \; | grep "ELF 64-bit" | grep -v aarch64

echo "Searching scripts with wrong shebang ..."

OUTFILE="/tmp/filelist" 
rm "${OUTFILE}"
for FILE in $(  find . -type f -exec file {} \; | grep " script" | grep executable  | grep -v "./.git/" | cut -f1 -d":" ) ;do
  head -1 ${FILE}  | grep '#!/usr' &&  echo ${FILE} | tee -a "${OUTFILE}"
done
echo "File ${OUTFILE} written ( $( wc -l ${OUTFILE} ) lines )"



if [ ${CPU_TYPE}x = "aarch64"x ] ; then
  echo "Searching for executable with missing libraries ..."
  for i in $( find . -type f -exec file {} \; | grep "ELF shared object" | cut -f1 -d ":" ) ; do 
    ldd $PWD/$i >/dev/null || echo $i 
  done
fi

