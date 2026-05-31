/* Configuration file for Linux Android targets.
   Copyright (C) 2026 Free Software Foundation, Inc.

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
/* Android requires thread-local variables on ARM targets to be aligned to (BITS_PER_WORD * 8) bits. */
#undef DATA_ABI_ALIGNMENT
#define DATA_ABI_ALIGNMENT(TYPE, ALIGN)  (targetm.have_tls && DECL_THREAD_LOCAL_P (decl) ? BITS_PER_WORD * 8 : (ALIGN))

/* Android reserves the x18 register for ShadowCallStack. */
#undef FIXED_X18
#define FIXED_X18 1
#endif

