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

#ifndef _STRING_H
#define _STRING_H

#include <sys/cdefs.h>
#include <stddef.h>
#include <xlocale.h>

#include <bits/strcasecmp.h>

__BEGIN_DECLS

#if defined(__USE_BSD) || defined(__USE_GNU)
#include <strings.h>
#endif

void* memccpy(void* __dst, const void* __src, int __stop_char, size_t __n) __THROW __attribute__((nonnull(1,2)));
void* memchr(const void* __s, int __ch, size_t __n) __THROW __attribute_pure__ __attribute__((nonnull(1)));
#if defined(__cplusplus)
extern "C++" void* memrchr(void* __s, int __ch, size_t __n) __REDIRECT_NTH(memrchr) __attribute_pure__ __attribute__((nonnull(1)));
extern "C++" const void* memrchr(const void* __s, int __ch, size_t __n) __REDIRECT_NTH(memrchr) __attribute_pure__ __attribute__((nonnull(1)));
#else
void* memrchr(const void* __s, int __ch, size_t __n) __THROW __attribute_pure__ __attribute__((nonnull(1)));
#endif
int memcmp(const void* __lhs, const void* __rhs, size_t __n) __THROW __attribute_pure__ __attribute__((nonnull(1,2)));
void* memcpy(void*, const void*, size_t) __THROW __attribute__((nonnull(1,2)));

#if defined(__USE_GNU)
void* mempcpy(void* __dst, const void* __src, size_t __n) __THROW __attribute__((nonnull(1,2)));
#endif

void* memmove(void* __dst, const void* __src, size_t __n) __THROW __attribute__((nonnull(1,2)));

/**
 * [memset(3)](https://man7.org/linux/man-pages/man3/memset.3.html) writes the
 * bottom 8 bits of the given int to the next `n` bytes of `dst`.
 *
 * Returns `dst`.
 */
void* memset(void* __dst, int __ch, size_t __n) __THROW __attribute__((nonnull(1)));

#if __ANDROID_API__ >= 34
/**
 * [memset_explicit(3)](https://man7.org/linux/man-pages/man3/memset_explicit.3.html)
 * writes the bottom 8 bits of the given int to the next `n` bytes of `dst`,
 * but won't be optimized out by the compiler.
 *
 * Returns `dst`.
 *
 * Available from API level 34, or with __ANDROID_UNAVAILABLE_SYMBOLS_ARE_WEAK__.
 */
void* memset_explicit(void* __dst, int __ch, size_t __n) __INTRODUCED_IN_API_U__ __attribute__((nonnull(1)));
#elif defined(__ANDROID_UNAVAILABLE_SYMBOLS_ARE_WEAK__)
#define __BIONIC_MEMSET_EXPLICIT_INLINE static __inline
#include <bits/memset_explicit_impl.h>
#undef __BIONIC_MEMSET_EXPLICIT_INLINE
#endif

void* memmem(const void* __haystack, size_t __haystack_size, const void* __needle, size_t __needle_size) __THROW __attribute_pure__ __attribute__((nonnull(1,3)));

char* strchr(const char* __s, int __ch) __THROW __attribute_pure__ __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(18)
char* __strchr_chk(const char* __s, int __ch, size_t __n) __INTRODUCED_IN_API_J_MR2__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(18) */

#if defined(__USE_GNU) && __BIONIC_AVAILABILITY_GUARD(24)
#if defined(__cplusplus)
extern "C++" char* strchrnul(char* __s, int __ch) __REDIRECT_NTH(strchrnul) __attribute_pure__ __INTRODUCED_IN_API_N__;
extern "C++" const char* strchrnul(const char* __s, int __ch) __REDIRECT_NTH(strchrnul) __attribute_pure__ __INTRODUCED_IN_API_N__;
#else
char* strchrnul(const char* __s, int __ch) __THROW __attribute_pure__ __INTRODUCED_IN_API_N__;
#endif
#endif

char* strrchr(const char* __s, int __ch) __THROW __attribute_pure__ __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(18)
char* __strrchr_chk(const char* __s, int __ch, size_t __n) __INTRODUCED_IN_API_J_MR2__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(18) */

size_t strlen(const char* __s) __THROW __attribute_pure__ __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(17)
size_t __strlen_chk(const char* __s, size_t __n) __INTRODUCED_IN_API_J_MR1__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(17) */

int strcmp(const char* __lhs, const char* __rhs) __THROW __attribute_pure__ __attribute__((nonnull(1,2)));

#if __BIONIC_AVAILABILITY_GUARD(21)
char* stpcpy(char* __dst, const char* __src) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1,2)));
#else
__static_inline__ char* __attribute__((nonnull(1,2))) stpcpy(char* __dst, const char* __src) { return __builtin_stpcpy(__dst, __src); }
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

char* strcpy(char* __dst, const char* __src) __THROW __attribute__((nonnull(1,2)));
char* strcat(char* __dst, const char* __src) __THROW __attribute__((nonnull(1,2)));
char* strdup(const char* __s) __THROW __attribute__((nonnull(1)));

char* strstr(const char* __haystack, const char* __needle) __THROW __attribute_pure__ __attribute__((nonnull(1,2)));
char* strcasestr(const char* __haystack, const char* __needle) __THROW __attribute_pure__ __attribute__((nonnull(1,2)));

/**
 * [strtok(3)](https://man7.org/linux/man-pages/man3/strtok.3.html)
 * extracts non-empty tokens from strings.
 *
 * Code on Android should use strtok_r() instead,
 * since strtok() isn't thread-safe.
 *
 * See strsep() if you want empty tokens returned too.
 */
char* strtok(char* __s, const char* __delimiter)
    __THROW __attribute__((__deprecated__("strtok() is not thread-safe; use strtok_r() instead")));

/**
 * [strtok_r(3)](https://man7.org/linux/man-pages/man3/strtok_r.3.html)
 * extracts non-empty tokens from strings.
 *
 * See strsep() if you want empty tokens returned too.
 */
char* strtok_r(char* __s, const char* __delimiter, char* * __pos_ptr) __THROW __attribute__((nonnull(2,3)));

/**
 * [strerror(3)](https://man7.org/linux/man-pages/man3/strerror.3.html)
 * returns a string describing the given errno value.
 * `strerror(EINVAL)` would return "Invalid argument", for example.
 *
 * On Android, unknown errno values return a string such as "Unknown error 666".
 * These unknown errno value strings live in thread-local storage, and are valid
 * until the next call of strerror() on the same thread.
 *
 * Returns a pointer to a string.
 */
char* strerror(int __errno_value)__THROW ;

/**
 * Equivalent to strerror() on Android where only C/POSIX locales are available.
 */
char* strerror_l(int __errno_value, locale_t __l) __REDIRECT_NTH(strerror) __attribute__((nonnull(2)));

#if defined(__USE_GNU) && __ANDROID_API__ >= 23
/**
 * [strerror_r(3)](https://man7.org/linux/man-pages/man3/strerror_r.3.html)
 * writes a string describing the given errno value into the given buffer.
 *
 * There are two variants of this function, POSIX and GNU.
 * The GNU variant returns a pointer to the buffer.
 * The POSIX variant returns 0 on success or an errno value on failure.
 *
 * The GNU variant is available since API level 23 if `_GNU_SOURCE` is defined.
 * The POSIX variant is available otherwise.
 */
char* strerror_r(int __errno_value, char* __buf, size_t __n) __REDIRECT_NTH(__gnu_strerror_r) __INTRODUCED_IN_API_M__;
#else /* POSIX */
int strerror_r(int __errno_value, char* __buf, size_t __n) __THROW __attribute__((nonnull(2)));
#endif

#if defined(__USE_GNU) && __BIONIC_AVAILABILITY_GUARD(35)
/**
 * [strerrorname_np(3)](https://man7.org/linux/man-pages/man3/strerrorname_np.3.html)
 * returns the name of the errno constant corresponding to its argument.
 * `strerrorname_np(38)` would return "ENOSYS", because `ENOSYS` is errno 38. This
 * is mostly useful for error reporting in cases where a string like "ENOSYS" is
 * more readable than a string like "Function not implemented", which would be
 * returned by strerror().
 *
 * Returns a pointer to a string, or null for unknown errno values.
 *
 * Available since API level 35 when compiling with `_GNU_SOURCE`.
 */
const char* strerrorname_np(int __errno_value) __THROW __INTRODUCED_IN_API_V__;
#endif

#if defined(__USE_GNU)
/**
 * [strerrordesc_np(3)](https://man7.org/linux/man-pages/man3/strerrordesc_np.3.html)
 * is like strerror() but without localization. Since Android's strerror()
 * does not localize, this is the same as strerror() on Android.
 *
 * Returns a pointer to a string.
 *
 * Available when compiling with `_GNU_SOURCE`.
 */
const char* strerrordesc_np(int __errno_value) __REDIRECT_NTH(strerror);
#endif

size_t strnlen(const char* __s, size_t __n) __THROW __attribute_pure__ __attribute__((nonnull(1)));
char* strncat(char* __dst, const char* __src, size_t __n) __THROW __attribute__((nonnull(1,2)));
char* strndup(const char* __s, size_t __n) __THROW __attribute__((nonnull(1)));
int strncmp(const char* __lhs, const char* __rhs, size_t __n) __THROW __attribute_pure__ __attribute__((nonnull(1,2)));

char* stpncpy(char* __dst, const char* __src, size_t __n) __THROW __attribute__((nonnull(1,2)));
char* strncpy(char* __dst, const char* __src, size_t __n) __THROW __attribute__((nonnull(1,2)));

size_t strlcat(char* __dst, const char* __src, size_t __n) __THROW __attribute__((nonnull(1,2)));
size_t strlcpy(char* __dst, const char* __src, size_t __n) __THROW __attribute__((nonnull(1,2)));

/**
 * [strcspn(3)](https://man7.org/linux/man-pages/man3/strcspn.3.html)
 * returns the length of the prefix containing only characters _not_ in
 * the reject set.
 */
size_t strcspn(const char* __s, const char* __reject) __THROW __attribute_pure__ __attribute__((nonnull(1,2)));

/**
 * [strpbrk(3)](https://man7.org/linux/man-pages/man3/strpbrk.3.html)
 * returns a pointer to the first character in the string that's
 * in the accept set, or null.
 *
 * See strspn() if you want an index instead.
 */
char* strpbrk(const char* __s, const char* __accept) __THROW __attribute_pure__ __attribute__((nonnull(1,2)));

/**
 * [strsep(3)](https://man7.org/linux/man-pages/man3/strsep.3.html)
 * extracts tokens (including empty ones) from strings.
 *
 * See strtok_r() if you don't want empty tokens.
 */
char* strsep(char* * __s_ptr, const char* __delimiter) __THROW __attribute__((nonnull(1,2)));

/**
 * [strspn(3)](https://man7.org/linux/man-pages/man3/strspn.3.html)
 * returns the length of the prefix containing only characters in
 * the accept set.
 *
 * See strpbrk() if you want a pointer instead.
 */
size_t strspn(const char* __s, const char* __accept) __THROW __attribute__((nonnull(1,2)));

/**
 * [strsignal(3)](https://man7.org/linux/man-pages/man3/strsignal.3.html)
 * converts the integer corresponding to SIGSEGV (say) into a string
 * like "Segmentation violation".
 *
 * Use sig2str() instead to convert the integer corresponding to SIGSEGV (say)
 * into a string like "SEGV".
 *
 * Returns a pointer to a string. For invalid signals, the string is in TLS.
 */
char* strsignal(int __signal)__THROW ;

/** Equivalent to strcmp() on Android. */
int strcoll(const char* __lhs, const char* __rhs) __THROW __attribute_pure__ __attribute__((nonnull(1,2)));

#if __BIONIC_AVAILABILITY_GUARD(21)
/** Equivalent to strcmp() on Android. */
int strcoll_l(const char* __lhs, const char* __rhs, locale_t __l) __THROW __attribute_pure__ __INTRODUCED_IN_API_L__;
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

/** Equivalent to strlcpy() on Android. */
size_t strxfrm(char* __dst, const char* __src, size_t __n) __THROW __attribute__((nonnull(2)));

#if __BIONIC_AVAILABILITY_GUARD(21)
/** Equivalent to strlcpy() on Android. */
size_t strxfrm_l(char* __dst, const char* __src, size_t __n, locale_t __l) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(2,4)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

/*
 * glibc has a basename in <string.h> that's different to the POSIX one in <libgen.h>.
 * It doesn't modify its argument, and in C++ it's const-correct.
 */
#if defined(__USE_GNU) && __BIONIC_AVAILABILITY_GUARD(23) && !defined(basename)
#if defined(__cplusplus)
extern "C++" char* basename(char* __path) __REDIRECT_NTH(__gnu_basename) __INTRODUCED_IN_API_M__;
extern "C++" const char* basename(const char* __path) __REDIRECT_NTH(__gnu_basename) __INTRODUCED_IN_API_M__ __attribute__((nonnull(1)));
#else
char* basename(const char* __path) __RENAME(__gnu_basename) __INTRODUCED_IN_API_M__ __attribute__((nonnull(1)));
#endif
#endif

#if defined(__BIONIC_INCLUDE_FORTIFY_HEADERS)
#include <bits/fortify/string.h>
#endif

/* Const-correct overloads. Placed after FORTIFY so we call those functions, if possible. */
#if defined(__cplusplus) && defined(__clang__)
/* libcxx tries to provide these. Suppress that, since libcxx's impl doesn't respect FORTIFY. */
#define __CORRECT_ISO_CPP_STRING_H_PROTO
/* Used to make these preferable over regular <string.h> signatures for overload resolution. */
#define __prefer_this_overload __enable_if(true, "")
extern "C++" {
inline __always_inline
void* __attribute__((nonnull(1))) __bionic_memchr(const void* const s __pass_object_size, int c, size_t n) {
    return memchr(s, c, n);
}

inline __always_inline
const void* memchr(const void* const s __pass_object_size, int c, size_t n)
        __prefer_this_overload {
    return __bionic_memchr(s, c, n);
}

inline __always_inline
void* memchr(void* const s __pass_object_size, int c, size_t n) __prefer_this_overload {
    return __bionic_memchr(s, c, n);
}

inline __always_inline
char* __attribute__((nonnull(1))) __bionic_strchr(const char* const s __pass_object_size, int c) {
    return strchr(s, c);
}

inline __always_inline
const char* strchr(const char* const s __pass_object_size, int c)
        __prefer_this_overload {
    return __bionic_strchr(s, c);
}

inline __always_inline
char* strchr(char* const s __pass_object_size, int c)
        __prefer_this_overload {
    return __bionic_strchr(s, c);
}

inline __always_inline
char* __attribute__((nonnull(1))) __bionic_strrchr(const char* const s __pass_object_size, int c) {
    return strrchr(s, c);
}

inline __always_inline
const char* strrchr(const char* const s __pass_object_size, int c) __prefer_this_overload {
    return __bionic_strrchr(s, c);
}

inline __always_inline
char* strrchr(char* const s __pass_object_size, int c) __prefer_this_overload {
    return __bionic_strrchr(s, c);
}

/* Functions with no FORTIFY counterpart. */

inline __always_inline
char* __attribute__((nonnull(1,2))) __bionic_strcasestr(const char* h, const char* n) {
    return strcasestr(h, n);
}

inline __always_inline
const char* strcasestr(const char* h, const char* n) __prefer_this_overload {
    return __bionic_strcasestr(h, n);
}

inline __always_inline
char* strcasestr(char* h, const char* n) __prefer_this_overload {
    return __bionic_strcasestr(h, n);
}

inline __always_inline
char* __attribute__((nonnull(1,2))) __bionic_strstr(const char* h, const char* n) {
    return strstr(h, n);
}

inline __always_inline
const char* strstr(const char* h, const char* n) __prefer_this_overload {
    return __bionic_strstr(h, n);
}

inline __always_inline
char* strstr(char* h, const char* n) __prefer_this_overload {
    return __bionic_strstr(h, n);
}

inline __always_inline
char* __attribute__((nonnull(1,2))) __bionic_strpbrk(const char* h, const char* n) { return strpbrk(h, n); }

inline __always_inline
char* strpbrk(char* h, const char* n) __prefer_this_overload {
    return __bionic_strpbrk(h, n);
}

inline __always_inline
const char* strpbrk(const char* h, const char* n) __prefer_this_overload {
    return __bionic_strpbrk(h, n);
}
}
#undef __prefer_this_overload
#endif

__END_DECLS

#endif
