# clang19_toolchain_for_android
This repository contains a toolchain for **clang19** on **Android** running on a phone or tablet with an **arm64** CPU

The clang19 toolchain contains these programs:

The toolchain contains :

- clang 19.0 binaries and files
- make
- cmake
- ninja
- pkg-config, pkgconf
- the autoconf tools, libtool, and m4
- gnupatch
- bison
- flex
- perl
- python
- tcl
- gdb
- rsync
- wget
- curl
- sshd/ssh
- git
- gpg
- man
- bash
- nano
- vi

and some other tools -- all configured for the target directory **/data/local/tmp/sysroot**.
(see the file [README in the directory sysroot](https://github.com/bnsmb/clang19_toolchain_for_android/tree/main/sysroot/))

Most of the binaries in the tar file are compiled as static binary or as dynamic binary that only require the standard libraries from the Android OS.

The binaries should run on Android 12 and newer.

The **clang19 toolchain** can be used in adb shell sessions.


To use the **clang19 toolchain**, do the following:

Download or clone the repository and run the script 
```
sysroot/create_tar_archive.sh
```
from the repository. The script creates a tar file that needs to be copied to the phone.

**Note**

The usage for the script **create_tar_archive.sh** is
```
[ OmniRom 15 - xtrnaw7@t15g /data/develop/git_repos/clang19_toolchain_for_android/sysroot ] $ ./create_tar_archive.sh  -h
Usage: ./create_tar_archive.sh [target_dir_for_the_tar_file] [tar_file_description]
The default target directory is the directory with this script:  /data/develop/git_repos/clang19_toolchain_for_android
[ OmniRom 15 - xtrnaw7@t15g /data/develop/git_repos/clang19_toolchain_for_android/sysroot ] $ 
```


Then do this on the phone:

Unpack the tar file in the directory

**/data/local/tmp**

This command creates the directories with the **clang19 toolchain** in the directory 

**/data/local/tmp/sysroot**


Now execute the script to configure the environment for the  **clang19 toolchain**:
```
/data/local/tmp/sysroot/create_clang_env.sh
```
(This must be done only once)

To use the  **clang19 toolchain**, the environment must be initialized.
To initialize the environment **source** the file

**/data/local/tmp/sysroot/bin/init_clang19_env**

e.g.
```
 source /data/local/tmp/sysroot/bin/init_clang19_env
```

This must be performed once in each adb session using the **clang19 toolchain**

For more details see 

[http://bnsmb.de/My_HowTos_for_Android.html#How_to_install_a_Toolchain_for_clang_on_phones_without_root_access](http://bnsmb.de/My_HowTos_for_Android.html#How_to_install_a_Toolchain_for_clang_on_phones_without_root_access)

or

[https://xdaforums.com/t/guide-how-to-install-a-toolchain-for-clang-on-phones-without-root-access.4710235/](https://xdaforums.com/t/guide-how-to-install-a-toolchain-for-clang-on-phones-without-root-access.4710235/)

**Notes**

The unzip binary in some Android distributions does not create correct symbolic links . 
I therefore recommend unzipping the ZIP file with the unzip binary for Android from my homepage if this is done on the phone.
That unzip binary should run on any Android and is available here:

[https://bnsmb.de/files/public/Android/binaries_for_arm64/unzip](https://bnsmb.de/files/public/Android/binaries_for_arm64/unzip)

To check, if unzip has created correct symbolic links, check if ./sysroot/usr/lib/libcrypto.so is a symbolic link after after you have uncompressed the ZIP file.


The necessary files from the NDKs are part of the tar archive as a compressed tar archive and are unpacked by the script **create_clang_env.sh**.

As of **17.05.2025** the tar files with the NDK files are:

```
[ OmniRom 15 - xtrnaw7@t15g /data/develop/git_repos/clang19_toolchain_for_android/sysroot ] $ ls -l usr/ndk/*.tar.gz
-rw-r--r--. 1 xtrnaw7 xtrnaw7 58624967 Mar 30 13:16 usr/ndk/r27b.tar.gz
-rw-r--r--. 1 xtrnaw7 xtrnaw7 92588841 Mar 30 14:44 usr/ndk/r27c.tar.gz
[ OmniRom 15 - xtrnaw7@t15g /data/develop/git_repos/clang19_toolchain_for_android/sysroot ] $ 
```

