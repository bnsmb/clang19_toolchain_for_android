/* Configuration file for Linux Android targets.
   Copyright (C) 2008-2026 Free Software Foundation, Inc.
   Contributed by Doug Kwan (dougkwan@google.com)
   Rewritten by CodeSourcery, Inc.

   This file is part of GCC.

   GCC is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published
   by the Free Software Foundation; either version 3, or (at your
   option) any later version.

   GCC is distributed in the hope that it will be useful, but WITHOUT
   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
   or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
   License for more details.

   You should have received a copy of the GNU General Public License
   along with GCC; see the file COPYING3.  If not see
   <http://www.gnu.org/licenses/>.  */

#if !defined(USED_FOR_TARGET)
extern void android_driver_init(unsigned int*, struct cl_decoded_option**);
#define GCC_DRIVER_HOST_INITIALIZATION android_driver_init(&decoded_options_count, &decoded_options)

extern void android_override_options(void);
#define SUBTARGET_OVERRIDE_OPTIONS android_override_options()
#endif

#define BIONIC_PAGE_SIZE_4K "0x1000"
#define BIONIC_PAGE_SIZE_16K "0x4000"

#if !defined(ANDROID_MIN_SDK_VERSION)
 /* This is the minimum Android version supported on all architectures */
#define ANDROID_MIN_SDK_VERSION "21"
#endif

#if !defined(BIONIC_PAGE_SIZE)
/* This is the default for all architectures except AArch64 and x86_64. */
#define BIONIC_PAGE_SIZE BIONIC_PAGE_SIZE_4K
#endif

#if defined(ENABLE_DEFAULT_PIE)
#define ANDROID_PIE_SPEC ""
#endif

#define ANDROID_TARGET_OS_CPP_BUILTINS()			\
    do {							\
	  if (TARGET_ANDROID) {					\
	    builtin_define ("__ANDROID__");			\
	  }			\
    } while (0)

#if ANDROID_DEFAULT
# define NOANDROID "mno-android"
#else
# define NOANDROID "!mandroid"
#endif

#define LINUX_OR_ANDROID_CC(LINUX_SPEC, ANDROID_SPEC) \
  "%{" NOANDROID "|tno-android-cc:" LINUX_SPEC ";:" ANDROID_SPEC "}"

#define LINUX_OR_ANDROID_LD(LINUX_SPEC, ANDROID_SPEC) \
  "%{" NOANDROID "|tno-android-ld:" LINUX_SPEC ";:" ANDROID_SPEC "}"

#define ANDROID_IF_NOT_PIE(spec) \
    "%{!static: %{!static-pie: %{!shared: %{!no-pie: %{!fno-pie: %{!fno-PIE: %{!pie: %{!fpie: %{!fPIE: " spec " }}}}}}}}} "

#define ANDROID_IF_NOT_LLD(spec) \
    "%{!fuse-ld=lld: %{!fuse-ld=mold: " spec " }} "

#define ANDROID_IF_LLD(spec) \
    "%{fuse-ld=lld|fuse-ld=mold: " spec " } "

#define ANDROID_BFD_RELR_SPEC \
	ANDROID_IF_NOT_LLD("%:version-compare(>= 28 mandroid-version-min= -z)") \
	ANDROID_IF_NOT_LLD("%:version-compare(>= 28 mandroid-version-min= pack-relative-relocs)")

#define ANDROID_LLD_RELR_SPEC \
	ANDROID_IF_LLD("%:version-compare(>= 28 mandroid-version-min= --use-android-relr-tags)") \
	ANDROID_IF_LLD("%:version-compare(>= 28 mandroid-version-min= --pack-dyn-relocs=relr)")

/*
* Position Independent Executable (PIE) on Android
* 
* - Android 4.0.4 (API level 15) and below: PIE is not supported.
* - Android 4.1 (API level 16) to Android 4.4W (API level 20): PIE is supported, but not mandatory.
* - Android 5.0 (API level 21) and above: PIE is supported and mandatory.
*/
#if !defined(ANDROID_PIE_SPEC)
#define ANDROID_PIE_SPEC \
    ANDROID_IF_NOT_PIE("%:version-compare(!> 15 mandroid-version-min= -no-pie)") \
    ANDROID_IF_NOT_PIE("%:version-compare(>= 16 mandroid-version-min= -pie)")
#endif

/*
* DT_RELR (relative relocation format) on Android
* 
* - Android 9 (API level 28) and above: DT_RELR is supported and optional.
*/
#define ANDROID_RELR_SPEC \
  ANDROID_BFD_RELR_SPEC \
  ANDROID_LLD_RELR_SPEC

#define ANDROID_LINK_SPEC \
  "-z noexecstack " \
  "-z relro " \
  "-z now " \
  "-z text " \
  "-z separate-code " \
  "-z max-page-size=" BIONIC_PAGE_SIZE " " \
  "%{!no-eh-frame-hdr: --eh-frame-hdr} " \
  ANDROID_PIE_SPEC \
  ANDROID_RELR_SPEC \
  "%:version-compare(!> 28 mandroid-version-min= --no-rosegment) " \
  "%:version-compare(>= 29 mandroid-version-min= --rosegment) " \
  "%{%:sanitize(hwaddress): %{!shared: %:version-compare(>= 34 mandroid-version-min= --dynamic-linker=" BIONIC_DYNAMIC_LINKER_HWSAN64 ")}} " \
  "--enable-new-dtags " \
  "--undefined-version "

#define ANDROID_CC1_SPEC \
  "%{!mglibc: %{!muclibc: %{!mbionic: -mbionic}}} "			\
  "%{!fno-pic: %{!fno-PIC: %{!fpic: %{!fPIC: -fPIC}}}} "			\
  "%{D__ANDROID_API__*|D__ANDROID_MIN_SDK_VERSION__*: %esetting the platform version using the '__ANDROID_API__' or '__ANDROID_MIN_SDK_VERSION__' macros is not supported: use '-mandroid-version-min=<value>' instead} " \
  "%{D__ANDROID_UNAVAILABLE_SYMBOLS_ARE_WEAK__*: %eenabling support for weak symbols using the '__ANDROID_UNAVAILABLE_SYMBOLS_ARE_WEAK__' macro is not supported: use '-mandroid-weak-symbols' instead} " \
  "%{mandroid-version-min=*: -D __ANDROID_MIN_SDK_VERSION__=%* -D __ANDROID_API__=__ANDROID_MIN_SDK_VERSION__} " \
  "%{mandroid-weak-symbols: -D __ANDROID_UNAVAILABLE_SYMBOLS_ARE_WEAK__} "

#define ANDROID_CC1PLUS_SPEC ""

#define ANDROID_ASM_SPEC \
  "--noexecstack"

#define ANDROID_LIB_SPEC \
  "%{!static: -ldl} -landroid-stb"

#define ANDROID_STARTFILE_SPEC						\
  "%{shared: crtbegin_so%O%s;:"						\
  "  %{static|static-pie: crtbegin_static%O%s;: crtbegin_dynamic%O%s}}"

#define ANDROID_ENDFILE_SPEC \
  "%{shared: crtend_so%O%s;: crtend_android%O%s}"
