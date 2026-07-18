/*
 * Copyright (C) 2017 The Android Open Source Project
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
#error "Never include this file directly; instead, include <string.h>"
#endif

#if __BIONIC_AVAILABILITY_GUARD(23)
void* __memchr_chk(const void*, int, size_t, size_t) __INTRODUCED_IN_API_M__ __attribute__((nonnull(1)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(23)
void* __memrchr_chk(const void*, int, size_t, size_t) __INTRODUCED_IN_API_M__ __attribute__((nonnull(1)));
#endif

char* __stpncpy_chk2(char*, const char*, size_t, size_t, size_t) __attribute__((nonnull(1,2)));
char* __strncpy_chk2(char*, const char*, size_t, size_t, size_t) __attribute__((nonnull(1,2)));
size_t __strlcpy_chk(char*, const char*, size_t, size_t) __attribute__((nonnull(1,2)));
size_t __strlcat_chk(char*, const char*, size_t, size_t) __attribute__((nonnull(1,2)));

#if defined(__BIONIC_FORTIFY)

/* hwasan intercepts memcpy() but not the _chk variant. */
#if __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED && !__has_feature(hwaddress_sanitizer)
/* No diag -- clang diagnoses misuses of this on its own.  */
__BIONIC_FORTIFY_INLINE
void* memcpy(void* const dst __pass_object_size0, const void* src, size_t copy_amount)
        __diagnose_as_builtin(__builtin_memcpy, 1, 2, 3)
        __overloadable {
    return __builtin___memcpy_chk(dst, src, copy_amount, __bos0(dst));
}
#endif

/* hwasan intercepts memmove() but not the _chk variant. */
#if __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED && !__has_feature(hwaddress_sanitizer)
/* No diag -- clang diagnoses misuses of this on its own.  */
__BIONIC_FORTIFY_INLINE
void* memmove(void* const dst __pass_object_size0, const void* src, size_t len)
        __diagnose_as_builtin(__builtin_memmove, 1, 2, 3)
        __overloadable {
    return __builtin___memmove_chk(dst, src, len, __bos0(dst));
}
#endif

/* TODO: remove __clang_warning_if when https://issuetracker.google.com/400937647 is fixed. */
__BIONIC_FORTIFY_INLINE
void* memset(void* const s __pass_object_size0, int c, size_t n)
        __diagnose_as_builtin(__builtin_memset, 1, 2, 3)
        __overloadable
        /* If you're a user who wants this warning to go away: use `(&memset)(foo, bar, baz)`. */
        __clang_warning_if(!n, "'memset' will set 0 bytes; maybe the arguments got flipped?") {
/* hwasan intercepts memset() but not the _chk variant. */
#if __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED && !__has_feature(hwaddress_sanitizer)
    return __builtin___memset_chk(s, c, n, __bos0(s));
#else
    return __builtin_memset(s, c, n);
#endif
}

#if defined(__USE_GNU) && __ANDROID_API__ >= 30
__BIONIC_FORTIFY_INLINE
void* mempcpy(void* const dst __pass_object_size0, const void* src, size_t copy_amount)
        __diagnose_as_builtin(__builtin_mempcpy, 1, 2, 3)
        __overloadable {
#if __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED
    size_t bos_dst = __bos0(dst);
    if (!__bos_trivially_ge(bos_dst, copy_amount)) {
        return __builtin___mempcpy_chk(dst, src, copy_amount, bos_dst);
    }
#endif
    return __builtin_mempcpy(dst, src, copy_amount);
}
#endif

__BIONIC_FORTIFY_INLINE
char* stpcpy(char* const dst __pass_object_size, const char* src)
        __overloadable
        __clang_error_if(__bos_unevaluated_le(__bos(dst), __builtin_strlen(src)),
                         "'stpcpy' called with string bigger than buffer") {
#if __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED
    return __builtin___stpcpy_chk(dst, src, __bos(dst));
#else
    return __builtin_stpcpy(dst, src);
#endif
}

__BIONIC_FORTIFY_INLINE
char* strcpy(char* const dst __pass_object_size, const char* src)
        __diagnose_as_builtin(__builtin_strcpy, 1, 2)
        __overloadable {
#if __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED
    return __builtin___strcpy_chk(dst, src, __bos(dst));
#else
    return __builtin_strcpy(dst, src);
#endif
}

__BIONIC_FORTIFY_INLINE
char* strcat(char* const dst __pass_object_size, const char* src)
        __overloadable
        __clang_error_if(__bos_unevaluated_le(__bos(dst), __builtin_strlen(src)),
                         "'strcat' called with string bigger than buffer") {
#if __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED
    return __builtin___strcat_chk(dst, src, __bos(dst));
#else
    return __builtin_strcat(dst, src);
#endif
}

#if __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED
/* No diag -- clang diagnoses misuses of this on its own.  */
__BIONIC_FORTIFY_INLINE
char* strncat(char* const dst __pass_object_size, const char* src, size_t n)
       __diagnose_as_builtin(__builtin_strncat, 1, 2, 3)
       __overloadable {
    return __builtin___strncat_chk(dst, src, n, __bos(dst));
}
#endif

#if __ANDROID_API__ >= 23 && __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED
__BIONIC_FORTIFY_INLINE
void* memchr(const void* const s __pass_object_size, int c, size_t n) __overloadable {
    size_t bos = __bos(s);

    if (__bos_trivially_ge(bos, n)) {
        return __builtin_memchr(s, c, n);
    }

    return __memchr_chk(s, c, n, bos);
}

void* __memrchr_real(const void*, int, size_t) __RENAME(memrchr) __attribute__((nonnull(1)));

__BIONIC_FORTIFY_INLINE
void* __memrchr_fortify(const void* const __pass_object_size s, int c, size_t n) __overloadable {
    size_t bos = __bos(s);

    if (__bos_trivially_ge(bos, n)) {
        return __memrchr_real(s, c, n);
    }

    return __memrchr_chk(s, c, n, bos);
}
#endif

#if __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED
/* No diag -- clang diagnoses misuses of this on its own.  */
__BIONIC_FORTIFY_INLINE
char* stpncpy(char* const dst __pass_object_size, const char* const src __pass_object_size, size_t n)
        __diagnose_as_builtin(__builtin_stpncpy, 1, 2, 3)
        __overloadable {
    size_t bos_dst = __bos(dst);
    size_t bos_src = __bos(src);

    /* Ignore dst size checks; they're handled in strncpy_chk */
    if (bos_src == __BIONIC_FORTIFY_UNKNOWN_SIZE) {
        return __builtin___stpncpy_chk(dst, src, n, bos_dst);
    }

    return __stpncpy_chk2(dst, src, n, bos_dst, bos_src);
}

/* No diag -- clang diagnoses misuses of this on its own.  */
__BIONIC_FORTIFY_INLINE
char* strncpy(char* const dst __pass_object_size, const char* const src __pass_object_size, size_t n)
        __diagnose_as_builtin(__builtin_strncpy, 1, 2, 3)
        __overloadable {
    size_t bos_dst = __bos(dst);
    size_t bos_src = __bos(src);

    /* Ignore dst size checks; they're handled in strncpy_chk */
    if (bos_src == __BIONIC_FORTIFY_UNKNOWN_SIZE) {
        return __builtin___strncpy_chk(dst, src, n, bos_dst);
    }

    return __strncpy_chk2(dst, src, n, bos_dst, bos_src);
}
#endif

__BIONIC_FORTIFY_INLINE
size_t strlcpy(char* const dst __pass_object_size, const char* src, size_t size)
        __overloadable
        __clang_error_if(__bos_unevaluated_lt(__bos(dst), size),
                         "'strlcpy' called with size bigger than buffer") {
#if __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED
    return __strlcpy_chk(dst, src, size, __bos(dst));
#else
    return __call_bypassing_fortify(strlcpy)(dst, src, size);
#endif
}

__BIONIC_FORTIFY_INLINE
size_t strlcat(char* const dst __pass_object_size, const char* src, size_t size)
        __overloadable
        __clang_error_if(__bos_unevaluated_lt(__bos(dst), size),
                         "'strlcat' called with size bigger than buffer") {
#if __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED
    return __strlcat_chk(dst, src, size, __bos(dst));
#else
    return __call_bypassing_fortify(strlcat)(dst, src, size);
#endif
}

#if __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED
/*
 * Clang, when parsing C, can fold strlen to a constant without LLVM's help.
 * This doesn't apply to overloads of strlen, so write this differently. We
 * can't use `__pass_object_size0` here, but that's fine: it doesn't help much
 * on __always_inline functions.
 */
extern __always_inline __inline__ __attribute__((gnu_inline)) size_t __attribute__((nonnull(1))) strlen(const char* s) {
    return __strlen_chk(s, __bos0(s));
}
#endif

__BIONIC_FORTIFY_INLINE
char* strchr(const char* const s __pass_object_size, int c) __overloadable {
#if __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED
    size_t bos = __bos(s);

    if (bos != __BIONIC_FORTIFY_UNKNOWN_SIZE) {
        return __strchr_chk(s, c, bos);
    }
#endif
    return __builtin_strchr(s, c);
}

__BIONIC_FORTIFY_INLINE
char* strrchr(const char* const s __pass_object_size, int c) __overloadable {
#if __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED
    size_t bos = __bos(s);

    if (bos != __BIONIC_FORTIFY_UNKNOWN_SIZE) {
        return __strrchr_chk(s, c, bos);
    }
#endif
    return __builtin_strrchr(s, c);
}

#if __ANDROID_API__ >= 23 && __BIONIC_FORTIFY_RUNTIME_CHECKS_ENABLED
#if defined(__cplusplus)
extern "C++" {
__BIONIC_FORTIFY_INLINE
void* __attribute__((nonnull(1))) memrchr(void* const __pass_object_size s, int c, size_t n) {
    return __memrchr_fortify(s, c, n);
}

__BIONIC_FORTIFY_INLINE
const void* __attribute__((nonnull(1))) memrchr(const void* const __pass_object_size s, int c, size_t n) {
    return __memrchr_fortify(s, c, n);
}
}
#else
__BIONIC_FORTIFY_INLINE
void* memrchr(const void* const __pass_object_size s, int c, size_t n) __overloadable {
    return __memrchr_fortify(s, c, n);
}
#endif
#endif /* __ANDROID_API__ >= 23 */

#endif /* defined(__BIONIC_FORTIFY) */
