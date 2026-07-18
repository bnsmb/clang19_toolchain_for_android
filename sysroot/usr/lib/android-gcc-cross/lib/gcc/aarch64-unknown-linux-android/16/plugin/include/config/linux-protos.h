/* Prototypes.
   Copyright (C) 2013-2026 Free Software Foundation, Inc.

This file is part of GCC.

GCC is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3, or (at your option)
any later version.

GCC is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GCC; see the file COPYING3.  If not see
<http://www.gnu.org/licenses/>.  */

extern bool linux_has_ifunc_p (void);

extern bool linux_libc_has_function (enum function_class fn_class, tree);

extern unsigned linux_libm_function_max_error (unsigned, machine_mode, bool);
extern unsigned linux_fortify_source_default_level ();

/* TARGET_C_AVAILABILITY_* hooks for Android.  Defined in
   gcc/config/android.cc and only meaningful for Android triples.
   See gcc/c-family/c-availability.cc for the consumer.  */
extern const char *android_availability_platform_name (void);
extern bool android_availability_min_version (unsigned *, unsigned *, unsigned *);
extern int android_availability_platform_id (void);
