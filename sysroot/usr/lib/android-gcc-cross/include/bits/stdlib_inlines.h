/*
 * Copyright (C) 2024 The Android Open Source Project
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
 * OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
 * OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#pragma once

#include <errno.h>
#include <float.h>
#include <stdlib.h>
#include <xlocale.h>
#include <sys/cdefs.h>

__BEGIN_DECLS

#if __ANDROID_API__ < 21
__static_inline__ float strtof(const char* nptr, char** endptr) {
  double d = strtod(nptr, endptr);
  if (d > FLT_MAX) {
    errno = ERANGE;
    return __builtin_huge_valf();
  } else if (d < -FLT_MAX) {
    errno = ERANGE;
    return -__builtin_huge_valf();
  }
  return __BIONIC_CAST(static_cast, float, d);
}

__static_inline__ double atof(const char *nptr) { return (strtod(nptr, NULL)); }

__static_inline__ int abs(int __n) { return __builtin_abs(__n); }

__static_inline__ long labs(long __n) { return __builtin_labs(__n); }

__static_inline__ long long llabs(long long __n) { return __builtin_llabs(__n); }

__static_inline__ int rand(void) { return (int) lrand48(); }

__static_inline__ void srand(unsigned int __s) { srand48(__s); }

__static_inline__ long random(void) { return lrand48(); }

__static_inline__ void srandom(unsigned int __s) { srand48(__s); }

__static_inline__ int grantpt(int __fd __attribute((unused))) {
  return 0; /* devpts does this all for us! */
}
#endif /* __ANDROID_API__ < 21 */

__END_DECLS
