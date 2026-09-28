
FS=$1
FS=${FS:=50M}

echo "Searching files bigger then $FS ..."
 find . -type f -size $FS -exec ls -lh {} +

