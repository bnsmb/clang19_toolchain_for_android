/*
   +----------------------------------------------------------------------+
   | Copyright (c) The PHP Group                                          |
   +----------------------------------------------------------------------+
   | This source file is subject to version 3.01 of the PHP license,      |
   | that is bundled with this package in the file LICENSE, and is        |
   | available through the world-wide-web at the following url:           |
   | https://www.php.net/license/3_01.txt                                 |
   | If you did not receive a copy of the PHP license and are unable to   |
   | obtain it through the world-wide-web, please send a note to          |
   | license@php.net so we can mail you a copy immediately.               |
   +----------------------------------------------------------------------+
   | Author: Stig Sæther Bakken <ssb@php.net>                             |
   +----------------------------------------------------------------------+
*/

#define CONFIGURE_COMMAND " './configure'  'CFLAGS= -I/data/local/tmp/sysroot/usr/include -I/data/local/tmp/sysroot/usr/clang19/include -I/data/local/tmp/sysroot/usr/ndk/r27d/include -I/data/local/tmp/sysroot/usr/ndk/r27d/sysroot/usr/include/aarch64-linux-android -I/data/local/tmp/sysroot/usr/ndk/r27d/sysroot/usr/include -I/data/local/tmp/develop/sysroot/usr/include --sysroot=/data/local/tmp/sysroot/usr/ndk/r27d/sysroot -Wno-implicit-function-declaration -Wno-int-conversion ' 'LDFLAGS= -L/data/local/tmp/sysroot/usr/lib -L/data/local/tmp/sysroot/usr/ndk/r27d/sysroot/usr/lib/aarch64-linux-android/31 -L/data/local/tmp/sysroot/usr/ndk/r27d/sysroot/usr/lib/aarch64-linux-android -L/data/local/tmp/develop/sysroot/usr/lib -B/data/local/tmp/sysroot/usr/ndk/r27d/sysroot/usr/lib/aarch64-linux-android/31/ --sysroot=/data/local/tmp/sysroot/usr/ndk/r27d/sysroot -lc ' '--prefix=/data/local/tmp/sysroot' '--exec-prefix=/data/local/tmp/sysroot/usr/bin' '--bindir=/data/local/tmp/sysroot/usr/bin' '--sbindir=/data/local/tmp/sysroot/usr/bin' '--libexecdir=/data/local/tmp/sysroot/usr/libexec' '--sysconfdir=/data/local/tmp/sysroot/etc' '--sharedstatedir=/data/local/tmp/sysroot/usr/share/com' '--localstatedir=/data/local/tmp/sysroot/var' '--runstatedir=/data/local/tmp/sysroot/usr/run' '--libdir=/data/local/tmp/sysroot/usr/lib' '--includedir=/data/local/tmp/sysroot/usr/include' '--oldincludedir=/data/local/tmp/sysroot/usr/include' '--datarootdir=/data/local/tmp/sysroot/usr/share' '--datadir=/data/local/tmp/sysroot/usr/share' '--infodir=/data/local/tmp/sysroot/usr/share/info' '--localedir=/data/local/tmp/sysroot/usr/share/locale' '--mandir=/data/local/tmp/sysroot/usr/share/man' '--docdir=/data/local/tmp/sysroot/usr/share/doc/php815' '--htmldir=/data/local/tmp/sysroot/usr/share/doc/php815' '--dvidir=/data/local/tmp/sysroot/usr/share/doc/php815' '--pdfdir=/data/local/tmp/sysroot/usr/share/doc/php815' '--psdir=/data/local/tmp/sysroot/usr/share/doc/php815' 'ac_cv_func_res_nsearch=no' 'ac_cv_func_res_search=no' 'ac_cv_func_dns_search=no' 'ac_cv_header_resolv_h=no' 'ac_cv_phpdbg_userfaultfd_writefault=no' 'php_cv_lib_gd_gdImageCreateFromPng=yes' 'php_cv_lib_gd_gdImageCreateFromAvif=yes' 'php_cv_lib_gd_gdImageCreateFromWebp=yes' 'php_cv_lib_gd_gdImageCreateFromJpeg=yes' 'php_cv_lib_gd_gdImageCreateFromBmp=yes' 'php_cv_lib_gd_gdImageCreateFromTga=yes' '--enable-bcmath' '--enable-calendar' '--enable-exif' '--enable-mbstring' '--with-capstone' '--enable-pcntl' '--enable-sockets' '--with-bz2=/data/local/tmp/develop/sysroot/usr/' '--with-config-file-path=/data/local/tmp/sysroot/etc/php' '--with-config-file-scan-dir=/data/local/tmp/sysroot/etc/php/conf.d' '--with-curl' '--with-openssl' '--with-readline' '--with-sodium=shared' '--with-zlib' '--with-mysqli=mysqlnd' '--with-pdo-mysql=mysqlnd' '--with-mysql-sock=/data/local/tmp/mysqld.sock' '--with-iconv=/data/local/tmp/develop/sysroot/usr' '--enable-fpm' '--enable-gd=shared' '--with-external-gd' '--with-external-pcre' '--with-zip' '--with-xsl' '--with-gmp' '--with-ffi' '--enable-intl' '--with-tidy=/data/local/tmp/develop/sysroot/usr/' '--sbindir=/data/local/tmp/develop/sysroot/bin' '--disable-dns' 'php_cv_iconv_errno=yes' 'php_with_readline=yes' '--disable-phpdbg' '--without-pcre-jit' '--disable-opcache-jit' '--with-apxs2=/data/local/tmp/develop/php815/apxs.sh' '--disable-zts' '--enable-zts=no' 'PKG_CONFIG=/data/local/tmp/sysroot/usr/clang19/bin/pkg-config' 'PKG_CONFIG_PATH=:/data/local/tmp/sysroot/usr/lib/pkgconfig/:/data/local/tmp/develop/sysroot/usr/lib/pkgconfig/' 'CPPFLAGS= -I/data/local/tmp/sysroot/usr/include -I/data/local/tmp/sysroot/usr/clang19/include -I/data/local/tmp/sysroot/usr/ndk/r27d/include -I/data/local/tmp/sysroot/usr/ndk/r27d/sysroot/usr/include/aarch64-linux-android -I/data/local/tmp/sysroot/usr/ndk/r27d/sysroot/usr/include -I/data/local/tmp/develop/sysroot/usr/include --sysroot=/data/local/tmp/sysroot/usr/ndk/r27d/sysroot ' 'CPP=/data/local/tmp/sysroot/usr/clang19/bin/clang-cpp' 'CXXFLAGS= -I/data/local/tmp/sysroot/usr/include -I/data/local/tmp/sysroot/usr/clang19/include -I/data/local/tmp/sysroot/usr/ndk/r27d/include -I/data/local/tmp/sysroot/usr/ndk/r27d/sysroot/usr/include/aarch64-linux-android -I/data/local/tmp/sysroot/usr/ndk/r27d/sysroot/usr/include -I/data/local/tmp/develop/sysroot/usr/include --sysroot=/data/local/tmp/sysroot/usr/ndk/r27d/sysroot -Wno-implicit-function-declaration -Wno-int-conversion ' 'CXXCPP=/data/local/tmp/sysroot/usr/clang19/bin/clang-cpp'"
#define PHP_PROG_SENDMAIL	"/usr/sbin/sendmail"
#define PEAR_INSTALLDIR         ""
#define PHP_INCLUDE_PATH	".:"
#define PHP_EXTENSION_DIR       "/data/local/tmp/sysroot/usr/lib/extensions/no-debug-non-zts-20250925"
#define PHP_PREFIX              "/data/local/tmp/sysroot"
#define PHP_BINDIR              "/data/local/tmp/sysroot/usr/bin"
#define PHP_SBINDIR             "/data/local/tmp/develop/sysroot/bin"
#define PHP_MANDIR              "/data/local/tmp/sysroot/usr/share/man"
#define PHP_LIBDIR              "/data/local/tmp/sysroot/usr/lib"
#define PHP_DATADIR             "/data/local/tmp/sysroot/usr/share"
#define PHP_SYSCONFDIR          "/data/local/tmp/sysroot/etc"
#define PHP_LOCALSTATEDIR       "/data/local/tmp/sysroot/var"
#define PHP_CONFIG_FILE_PATH    "/data/local/tmp/sysroot/etc/php"
#define PHP_CONFIG_FILE_SCAN_DIR    "/data/local/tmp/sysroot/etc/php/conf.d"
#define PHP_SHLIB_SUFFIX        "so"
#define PHP_SHLIB_EXT_PREFIX    ""
