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

#if DEFAULT_LIBC == LIBC_BIONIC
extern void android_driver_init(unsigned int*, struct cl_decoded_option**);
#define GCC_DRIVER_HOST_INITIALIZATION android_driver_init(&decoded_options_count, &decoded_options)

extern void android_override_options(void);
#define SUBTARGET_OVERRIDE_OPTIONS android_override_options()
#endif

#define BIONIC_PAGE_SIZE_4K "0x1000"
#define BIONIC_PAGE_SIZE_16K "0x4000"

#if !defined(ANDROID_MIN_SDK_VERSION)
/* Minimum Android API level supported across all architectures. */
#define ANDROID_MIN_SDK_VERSION "21"
#endif

#if !defined(BIONIC_PAGE_SIZE)
/* This is the default for all architectures except AArch64 and x86_64. */
#define BIONIC_PAGE_SIZE BIONIC_PAGE_SIZE_4K
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

#if defined(ENABLE_DEFAULT_PIE)
#define ANDROID_PIE_SPEC ""
#else
/* Enable PIE on Android 4.1+ (API level 16). */
#define ANDROID_PIE_SPEC \
  "%{!static: %{!shared: %{!no-pie: %{!fno-pie: %{!fno-PIE: %{!pie: %{!fpie: %{!fPIE: " \
  "%:version-compare(!> 15 mandroid-version-min= -no-pie) " \
  "%:version-compare(>= 16 mandroid-version-min= -pie) " \
  "}}}}}}}} "
#endif

/*
* Enable DT_RELR packed relocations on Android 9+ (API level 28).
*/
#define ANDROID_RELR_SPEC \
  "%{fuse-ld=lld|fuse-ld=mold: " \
  " %:version-compare(>= 23 mandroid-version-min= --pack-dyn-relocs=android) " \
  " %:version-compare(>= 28 mandroid-version-min= --use-android-relr-tags) " \
  " %:version-compare(>= 28 mandroid-version-min= --pack-dyn-relocs=android+relr) " \
  " ;: " \
  " %:version-compare(>= 30 mandroid-version-min= -z) " \
  " %:version-compare(>= 30 mandroid-version-min= pack-relative-relocs) " \
  " } "

/* Use read-only segments on Android 10+ (API level 29). */
#define ANDROID_ROSEGMENT_SPEC \
  "%:version-compare(!> 28 mandroid-version-min= --no-rosegment) " \
  "%:version-compare(>= 29 mandroid-version-min= -z) " \
  "%:version-compare(>= 29 mandroid-version-min= separate-code) " \
  "%:version-compare(>= 29 mandroid-version-min= --rosegment) "

#define ANDROID_LINK_SPEC \
  "-z noexecstack " \
  "-z relro " \
  "-z now " \
  "-z max-page-size=" BIONIC_PAGE_SIZE " " \
  "%{!no-eh-frame-hdr: --eh-frame-hdr} " \
  "--enable-new-dtags " \
  "--undefined-version " \
  ANDROID_PIE_SPEC \
  ANDROID_RELR_SPEC \
  ANDROID_ROSEGMENT_SPEC

#define ANDROID_CC1_SPEC \
  "%{!mglibc: %{!muclibc: %{!mbionic: -mbionic}}} "			\
  "%{!fno-pic: %{!fno-PIC: %{!fpic: %{!fPIC: -fPIC}}}} "			\
  "%{D__ANDROID_API__*|D__ANDROID_MIN_SDK_VERSION__*: %esetting the platform version using the '__ANDROID_API__' or '__ANDROID_MIN_SDK_VERSION__' macros is not supported: use '-mandroid-version-min=<value>' instead} " \
  "%{D__ANDROID_UNAVAILABLE_SYMBOLS_ARE_WEAK__*: %eenabling support for weak symbols using the '__ANDROID_UNAVAILABLE_SYMBOLS_ARE_WEAK__' macro is not supported: use '-mandroid-weak-symbols' instead} " \
  "%{mandroid-version-min=*: -D __ANDROID_MIN_SDK_VERSION__=%* -D __ANDROID_API__=__ANDROID_MIN_SDK_VERSION__} " \
  "%{mandroid-weak-symbols: -D __ANDROID_UNAVAILABLE_SYMBOLS_ARE_WEAK__} "

#define ANDROID_LIB_SPEC \
  "%{!static: -ldl} -landroid-stb"

#define ANDROID_STARTFILE_SPEC						\
  "%{shared: crtbegin_so%O%s;:"						\
  "  %{static|static-pie: crtbegin_static%O%s;: crtbegin_dynamic%O%s}}"

#define ANDROID_ENDFILE_SPEC \
  "%{shared: crtend_so%O%s;: crtend_android%O%s}"

/* __builtin_available hooks for the Linux/Android target.  These
   overrides are in scope whenever linux-android.h is included in
   tm_file (i.e. all *-*-linux*-android* triples), and they consult the
   -mandroid-version-min option recorded in `android_version_min` by
   gcc/config/linux-android.opt.  See gcc/c-family/c-availability.cc for
   the consumer and clang/lib/Basic/Targets/OSTargets.h:364-374 (which
   sets Clang's PlatformName to "android") for the Clang analog.  */
#undef TARGET_C_AVAILABILITY_PLATFORM_NAME
#define TARGET_C_AVAILABILITY_PLATFORM_NAME android_availability_platform_name
#undef TARGET_C_AVAILABILITY_MIN_VERSION
#define TARGET_C_AVAILABILITY_MIN_VERSION android_availability_min_version

/* Intentionally do NOT override TARGET_C_AVAILABILITY_PLATFORM_ID: Android
   uses the non-Darwin runtime helper __isOSVersionAtLeast (major, minor,
   sub) rather than __isPlatformVersionAtLeast (platform_id, ...), so the
   default hook returning 0 gives the correct behavior in
   c_build_builtin_available.  */
