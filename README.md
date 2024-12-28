# clang19_toolchain_for_android
This repository contains a toolchain for **clang19** on **Android** on a **arm64** CPU

The clang19 toolchain contains these programs:

The toolchain contains :

- clang 19.0 binaries and files
- make
- cmake
- ninja
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
- man
- bash
- nano
-  vi

and some other tools -- all configured for the target directory **/data/local/tmp/sysroot**.

Most of the binaries in the tar file are compiled as static binary or as dynamic binary that only require the standard libraries from the Android OS.


To use the **clang19 toolchain**, do the following:

Download or clone the repository and run the script 
```
sysroot/create_tar_archive.sh
```
from the repository. The script creates a tar file that needs to be copied to the phone.

**Note**

The usage for the script **create_tar_archive.sh** is
```
[ OmniRom 14 Dev - xtrnaw7@t15g /data/develop/git_repos/clang19_toolchain_for_android/sysroot ] $   ./create_tar_archive.sh  -h
Usage: ./create_tar_archive.sh [target_dir_for_the_tar_file] [tar_file_descriptions]
The default target directory is /data/develop/git_repos/clang19_toolchain_for_android
[ OmniRom 14 Dev - xtrnaw7@t15g /data/develop/git_repos/clang19_toolchain_for_android/sysroot ] $ 
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


