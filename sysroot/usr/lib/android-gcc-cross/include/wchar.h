/*
 * Copyright (C) 2008 The Android Open Source Project
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

#ifndef _WCHAR_H_
#define _WCHAR_H_

#include <sys/cdefs.h>
#include <stdio.h>

#include <stdarg.h>
#include <stddef.h>
#include <time.h>
#include <xlocale.h>

#include <bits/bionic_multibyte_result.h>
#include <bits/mbstate_t.h>
#include <bits/wchar_limits.h>
#include <bits/wctype.h>

__BEGIN_DECLS

int fwprintf(FILE* __fp, const wchar_t* __fmt, ...) __attribute__((nonnull(1,2)));
int fwscanf(FILE* __fp, const wchar_t* __fmt, ...) __attribute__((nonnull(1,2)));
wint_t fgetwc(FILE* __fp) __attribute__((nonnull(1)));
wchar_t* fgetws(wchar_t* __buf, int __size, FILE* __fp) __attribute__((nonnull(1,3)));
wint_t fputwc(wchar_t __wc, FILE* __fp) __attribute__((nonnull(2)));
int fputws(const wchar_t* __s, FILE* __fp) __attribute__((nonnull(1,2)));

/**
 * [fwide(3)](https://www.man7.org/linux/man-pages/man3/fwide.3.html)
 * gets/sets the orientation of a stream.
 *
 * Use a positive value to set wide character orientation,
 * a negative value to set byte orientation,
 * or 0 to leave the orientation unset if it hasn't already been set.
 *
 * ISO C says that byte operations "shall not" be applied to a wide character
 * stream and vice versa, but Android -- and other BSD-derived stdio
 * implementations -- do not enforce this.
 * On Android orientation is largely meaningless, and only tells you whether
 * the first operation on the stream was a byte or a wide character operation.
 *
 * Returns a positive value for a wide stream,
 * a negative value for a byte stream,
 * or 0 if the orientation has not yet been set.
 */
int fwide(FILE* __fp, int __mode) __THROW __attribute__((nonnull(1)));

wint_t getwc(FILE* __fp) __attribute__((nonnull(1)));
wint_t getwchar(void);
int mbsinit(const mbstate_t* __ps)__THROW ;
size_t mbrlen(const char* __s, size_t __n, mbstate_t* __ps)__THROW ;
size_t mbrtowc(wchar_t* __buf, const char* __s, size_t __n, mbstate_t* __ps)__THROW ;
size_t mbsrtowcs(wchar_t* __dst, const char* * __src, size_t __dst_n, mbstate_t* __ps) __THROW __attribute__((nonnull(2)));
size_t mbsrtowcs_l(wchar_t* __dst, const char* * __src, size_t __dst_n, mbstate_t* __ps, locale_t __l) __RENAME(mbsrtowcs) __attribute__((nonnull(2,5)));

#if __BIONIC_AVAILABILITY_GUARD(21)
size_t mbsnrtowcs(wchar_t* __dst, const char* *  __src, size_t __src_n, size_t __dst_n, mbstate_t* __ps) __THROW __INTRODUCED_IN_API_L__;
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

wint_t putwc(wchar_t __wc, FILE* __fp) __attribute__((nonnull(2)));
wint_t putwchar(wchar_t __wc);
int swprintf(wchar_t* __buf, size_t __n, const wchar_t* __fmt, ...) __THROW __attribute__((nonnull(1,3)));
int swscanf(const wchar_t* __s, const wchar_t* __fmt, ...) __THROW __attribute__((nonnull(1,2)));
wint_t ungetwc(wint_t __wc, FILE* __fp) __attribute__((nonnull(2)));
int vfwprintf(FILE* __fp, const wchar_t* __fmt, va_list __args) __attribute__((nonnull(1,2)));

#if __BIONIC_AVAILABILITY_GUARD(21)
int vfwscanf(FILE* __fp, const wchar_t* __fmt, va_list __args) __INTRODUCED_IN_API_L__ __attribute__((nonnull(1,2)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

int vswprintf(wchar_t* __buf, size_t __n, const wchar_t* __fmt, va_list __args) __THROW __attribute__((nonnull(1,3)));

#if __BIONIC_AVAILABILITY_GUARD(21)
int vswscanf(const wchar_t* __s, const wchar_t* __fmt, va_list __args) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1,2)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

int vwprintf(const wchar_t* __fmt, va_list __args) __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(21)
int vwscanf(const wchar_t* __fmt, va_list __args) __INTRODUCED_IN_API_L__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

wchar_t* wcpcpy(wchar_t* __dst, const wchar_t* __src) __THROW __attribute__((nonnull(1,2)));
wchar_t* wcpncpy(wchar_t* __dst, const wchar_t* __src, size_t __n) __THROW __attribute__((nonnull(1,2)));
size_t wcrtomb(char* __buf, wchar_t __wc, mbstate_t* __ps)__THROW ;
int wcscasecmp(const wchar_t* __lhs, const wchar_t* __rhs) __THROW __attribute__((nonnull(1,2)));

#if __BIONIC_AVAILABILITY_GUARD(23)
int wcscasecmp_l(const wchar_t* __lhs, const wchar_t* __rhs, locale_t __l) __THROW __INTRODUCED_IN_API_M__ __attribute__((nonnull(1,2,3)));
#endif

wchar_t* wcscat(wchar_t* __dst, const wchar_t* __src) __THROW __attribute__((nonnull(1,2)));
wchar_t* wcschr(const wchar_t * __s, wchar_t __wc) __THROW __attribute__((nonnull(1)));
int wcscmp(const wchar_t* __lhs, const wchar_t* __rhs) __THROW __attribute__((nonnull(1,2)));
wchar_t* wcscpy(wchar_t* __dst, const wchar_t* __src) __THROW __attribute__((nonnull(1,2)));
size_t wcscspn(const wchar_t* __s, const wchar_t* __accept) __THROW __attribute__((nonnull(1,2)));
size_t wcsftime(wchar_t* __buf, size_t __n, const wchar_t* __fmt, const struct tm* __tm) __THROW __attribute__((nonnull(1,4)));

#if __BIONIC_AVAILABILITY_GUARD(28)
size_t wcsftime_l(wchar_t* __buf, size_t __n, const wchar_t* __fmt, const struct tm* __tm, locale_t __l) __THROW __INTRODUCED_IN_API_P__ __attribute__((nonnull(1,4,5)));
#endif

size_t wcslen(const wchar_t* __s) __THROW __attribute__((nonnull(1)));
int wcsncasecmp(const wchar_t* __lhs, const wchar_t* __rhs, size_t __n) __THROW __attribute__((nonnull(1,2)));

#if __BIONIC_AVAILABILITY_GUARD(23)
int wcsncasecmp_l(const wchar_t* __lhs, const wchar_t* __rhs, size_t __n, locale_t __l) __THROW __INTRODUCED_IN_API_M__ __attribute__((nonnull(1,2,4)));
#endif

wchar_t* wcsncat(wchar_t* __dst, const wchar_t* __src, size_t __n) __THROW __attribute__((nonnull(1,2)));
int wcsncmp(const wchar_t* __lhs, const wchar_t* __rhs, size_t __n) __THROW __attribute__((nonnull(1,2)));
wchar_t* wcsncpy(wchar_t* __dst, const wchar_t* __src, size_t __n) __THROW __attribute__((nonnull(1,2)));

#if __BIONIC_AVAILABILITY_GUARD(21)
size_t wcsnrtombs(char* __dst, const wchar_t* * __src, size_t __src_n, size_t __dst_n, mbstate_t* __ps) __THROW __INTRODUCED_IN_API_L__;
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

wchar_t* wcspbrk(const wchar_t* __s, const wchar_t* __accept) __THROW __attribute__((nonnull(1,2)));
wchar_t* wcsrchr(const wchar_t* __s, wchar_t __wc) __THROW __attribute__((nonnull(1)));
size_t wcsrtombs(char* __dst, const wchar_t* * __src, size_t __dst_n, mbstate_t* __ps)__THROW ;
size_t wcsrtombs_l(char* __dst, const wchar_t* * __src, size_t __dst_n, mbstate_t* __ps, locale_t __l) __RENAME(wcsrtombs) __attribute__((nonnull(5)));
size_t wcsspn(const wchar_t* __s, const wchar_t* __accept) __THROW __attribute__((nonnull(1,2)));
wchar_t* wcsstr(const wchar_t* __haystack, const wchar_t* __needle) __THROW __attribute__((nonnull(1,2)));
double wcstod(const wchar_t* __s, wchar_t* * __end_ptr) __THROW __attribute__((nonnull(1)));
double wcstod_l(const wchar_t* __s, wchar_t* * __end_ptr, locale_t __l) __REDIRECT_NTH(wcstod) __attribute__((nonnull(1,3)));

#if __BIONIC_AVAILABILITY_GUARD(21)
float wcstof(const wchar_t* __s, wchar_t* * __end_ptr) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

float wcstof_l(const wchar_t* __s, wchar_t* * __end_ptr, locale_t __l) __REDIRECT_NTH(wcstof) __attribute__((nonnull(1,3)));
wchar_t* wcstok(wchar_t* __s, const wchar_t* __delimiter, wchar_t* * __ptr) __THROW __attribute__((nonnull(2,3)));
long wcstol(const wchar_t* __s, wchar_t* * __end_ptr, int __base) __THROW __attribute__((nonnull(1)));
long wcstol_l(const wchar_t* __s, wchar_t* * __end_ptr, int __base, locale_t __l) __REDIRECT_NTH(wcstol) __attribute__((nonnull(1,4)));

#if __BIONIC_AVAILABILITY_GUARD(21)
long long wcstoll(const wchar_t* __s, wchar_t* * __end_ptr, int __base) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

long double wcstold(const wchar_t* __s, wchar_t* * __end_ptr) __THROW __attribute__((nonnull(1)));
unsigned long wcstoul(const wchar_t* __s, wchar_t* * __end_ptr, int __base) __THROW __attribute__((nonnull(1)));
unsigned long wcstoul_l(const wchar_t* __s, wchar_t* * __end_ptr, int __base, locale_t __l) __REDIRECT_NTH(wcstoul) __attribute__((nonnull(1,4)));

#if __BIONIC_AVAILABILITY_GUARD(21)
unsigned long long wcstoull(const wchar_t* __s, wchar_t* * __end_ptr, int __base) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

int wcswidth(const wchar_t* __s, size_t __n) __THROW __attribute__((nonnull(1)));
int wcwidth(wchar_t __wc)__THROW ;
wchar_t* wmemchr(const wchar_t* __src, wchar_t __wc, size_t __n) __THROW __attribute__((nonnull(1)));
int wmemcmp(const wchar_t* __lhs, const wchar_t* __rhs, size_t __n)__THROW ;
wchar_t* wmemcpy(wchar_t* __dst, const wchar_t* __src, size_t __n) __THROW __attribute__((nonnull(1,2)));

#if defined(__USE_GNU) && __BIONIC_AVAILABILITY_GUARD(23)
wchar_t* wmempcpy(wchar_t* __dst, const wchar_t* __src, size_t __n) __THROW __INTRODUCED_IN_API_M__ __attribute__((nonnull(1,2)));
#endif

wchar_t* wmemmove(wchar_t* __dst, const wchar_t* __src, size_t __n) __THROW __attribute__((nonnull(1,2)));
wchar_t* wmemset(wchar_t* __dst, wchar_t __wc, size_t __n) __THROW __attribute__((nonnull(1)));
int wprintf(const wchar_t* __fmt, ...) __attribute__((nonnull(1)));
int wscanf(const wchar_t* __fmt, ...) __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(21)
long long wcstoll_l(const wchar_t* __s, wchar_t* * __end_ptr, int __base, locale_t __l) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1,4)));
unsigned long long wcstoull_l(const wchar_t* __s, wchar_t* * __end_ptr, int __base, locale_t __l) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1,4)));
long double wcstold_l(const wchar_t* __s, wchar_t* * __end_ptr, locale_t __l) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1,3)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

/** Equivalent to wcscmp() on Android. */
int wcscoll(const wchar_t* __lhs, const wchar_t* __rhs) __THROW __attribute__((nonnull(1,2)));

#if __BIONIC_AVAILABILITY_GUARD(21)
/** Equivalent to wcscmp() on Android. */
int wcscoll_l(const wchar_t* __lhs, const wchar_t* __rhs, locale_t __l) __THROW __attribute_pure__ __INTRODUCED_IN_API_L__;
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

/** Equivalent to wcslcpy() on Android. */
size_t wcsxfrm(wchar_t* __dst, const wchar_t* __src, size_t __n) __THROW __attribute__((nonnull(2)));

#if __BIONIC_AVAILABILITY_GUARD(21)
/** Equivalent to wcslcpy() on Android. */
size_t wcsxfrm_l(wchar_t* __dst, const wchar_t* __src, size_t __n, locale_t __l) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(2,4)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

size_t wcslcat(wchar_t* __dst, const wchar_t* __src, size_t __n) __THROW __attribute__((nonnull(1,2)));
size_t wcslcpy(wchar_t* __dst, const wchar_t* __src, size_t __n) __THROW __attribute__((nonnull(1,2)));

#if __BIONIC_AVAILABILITY_GUARD(23)
FILE* open_wmemstream(wchar_t* * __ptr, size_t*  __size_ptr) __THROW __INTRODUCED_IN_API_M__ __attribute__((nonnull(1,2)));
#endif

wchar_t* wcsdup(const wchar_t* __s) __THROW __attribute__((nonnull(1)));
size_t wcsnlen(const wchar_t* __s, size_t __n) __THROW __attribute__((nonnull(1)));

/** ASCII-only; use mbtowc() instead. */
wint_t btowc(int __ch) __THROW __attribute__((__deprecated__("ASCII-only; use mbtowc() instead")));
/** ASCII-only; use wctomb() instead. */
int wctob(wint_t __wc) __THROW __attribute__((__deprecated__("ASCII-only; use wctomb() instead")));

__END_DECLS

#endif
