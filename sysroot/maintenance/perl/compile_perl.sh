cc -o perl -pie -L/data/local/tmp/sysroot/usr/lib -L/data/local/tmp/sysroot/usr/ndk/r27d/sysroot/usr/lib/aarch64-linux-android/31 -L/data/local/tmp/sysroot/usr/ndk/r27d/sysroot/usr/lib/aarch64-linux-android -L/data/local/tmp/develop/sysroot/usr/lib -B/data/local/tmp/sysroot/usr/ndk/r27d/sysroot/usr/lib/aarch64-linux-android/31/ --sysroot=/data/local/tmp/sysroot/usr/ndk/r27d/sysroot -lc  -fstack-protector-strong -Wl,-E perlmain.o   libperl.a `cat ext.libs` -ldl -lm  -lc  \ 
/data/local/tmp/develop/sysroot/usr/lib/libcrypt_sysroot.a /data/local/tmp/develop/sysroot/usr/lib/libz.a


echo
ls -l perl
echo 
ldd $PWD/perl
