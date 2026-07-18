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

#pragma once

#include <sys/cdefs.h>
#include <sys/types.h>
#include <linux/memfd.h>
#include <linux/mman.h>
#include <linux/uio.h>

__BEGIN_DECLS

/** Alternative spelling of the `MAP_ANONYMOUS` flag for mmap(). */
#define MAP_ANON MAP_ANONYMOUS

/** Return value for mmap(). */
#define MAP_FAILED __BIONIC_CAST(reinterpret_cast, void*, -1)

#if defined(__USE_FILE_OFFSET64)
/**
 * [mmap(2)](https://man7.org/linux/man-pages/man2/mmap.2.html)
 * creates a memory mapping for the given range.
 *
 * Returns the address of the mapping on success,
 * and returns `MAP_FAILED` and sets `errno` on failure.
 */
void* mmap(void* __addr, size_t __size, int __prot, int __flags, int __fd, off_t __offset) __REDIRECT_NTH(mmap64);
#else
void* mmap(void* __addr, size_t __size, int __prot, int __flags, int __fd, off_t __offset)__THROW ;
#endif

/**
 * mmap64() is a variant of mmap() that takes a 64-bit offset even on LP32.
 *
 * See https://android.googlesource.com/platform/bionic/+/main/docs/32-bit-abi.md
 */
void* mmap64(void* __addr, size_t __size, int __prot, int __flags, int __fd, off64_t __offset)__THROW ;

/**
 * [munmap(2)](https://man7.org/linux/man-pages/man2/munmap.2.html)
 * deletes a memory mapping for the given range.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int munmap(void* __addr, size_t __size) __THROW __attribute__((nonnull(1)));

/**
 * [msync(2)](https://man7.org/linux/man-pages/man2/msync.2.html)
 * flushes changes to a memory-mapped file to disk.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int msync(void* __addr, size_t __size, int __flags) __attribute__((nonnull(1)));

/**
 * [mprotect(2)](https://man7.org/linux/man-pages/man2/mprotect.2.html)
 * sets the protection on a memory region.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int mprotect(void* __addr, size_t __size, int __prot) __THROW __attribute__((nonnull(1)));

/**
 * [mremap(2)](https://man7.org/linux/man-pages/man2/mremap.2.html)
 * expands or shrinks an existing memory mapping.
 *
 * Returns the address of the mapping on success,
 * and returns `MAP_FAILED` and sets `errno` on failure.
 */
void* mremap(void* __old_addr, size_t __old_size, size_t __new_size, int __flags, ...) __THROW __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(17)
/**
 * [mlockall(2)](https://man7.org/linux/man-pages/man2/mlockall.2.html)
 * locks pages (preventing swapping).
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int mlockall(int __flags) __THROW __INTRODUCED_IN_API_J_MR1__;

/**
 * [munlockall(2)](https://man7.org/linux/man-pages/man2/munlockall.2.html)
 * unlocks pages (allowing swapping).
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int munlockall(void) __THROW __INTRODUCED_IN_API_J_MR1__;
#endif /* __BIONIC_AVAILABILITY_GUARD(17) */

/**
 * [mlock(2)](https://man7.org/linux/man-pages/man2/mlock.2.html)
 * locks pages (preventing swapping).
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int mlock(const void* __addr, size_t __size) __THROW __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(30)
/**
 * [mlock2(2)](https://man7.org/linux/man-pages/man2/mlock2.2.html)
 * locks pages (preventing swapping), with optional flags.
 *
 * Available since API level 30.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int mlock2(const void* __addr, size_t __size, int __flags) __THROW __INTRODUCED_IN_API_R__ __attribute__((nonnull(1)));
#endif

/**
 * [munlock(2)](https://man7.org/linux/man-pages/man2/munlock.2.html)
 * unlocks pages (allowing swapping).
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int munlock(const void* __addr, size_t __size) __THROW __attribute__((nonnull(1)));

/**
 * [mincore(2)](https://man7.org/linux/man-pages/man2/mincore.2.html)
 * tests whether pages are resident in memory.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int mincore(void* __addr, size_t __size, unsigned char* __vector) __THROW __attribute__((nonnull(1,3)));

/**
 * [madvise(2)](https://man7.org/linux/man-pages/man2/madvise.2.html)
 * gives the kernel advice about future usage patterns.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int madvise(void* __addr, size_t __size, int __advice) __THROW __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(31)
/**
 * [process_madvise(2)](https://man7.org/linux/man-pages/man2/process_madvise.2.html)
 * works just like madvise(2) but applies to the process specified by the given
 * PID file descriptor.
 *
 * Available since API level 31. Its sibling process_mrelease() does not have a
 * libc wrapper and should be called using syscall() instead. Given the lack of
 * widespread applicability of this system call and the absence of wrappers in
 * other libcs, it was probably a mistake to have added this wrapper to bionic.
 *
 * Returns the number of bytes advised on success, and returns -1 and sets `errno` on failure.
 */
ssize_t process_madvise(int __pid_fd, const struct iovec* __iov, size_t __count, int __advice, unsigned __flags) __THROW __INTRODUCED_IN_API_S__ __attribute__((nonnull(2)));
#endif

#if defined(__USE_GNU) && __BIONIC_AVAILABILITY_GUARD(30)
/**
 * [memfd_create(2)](https://man7.org/linux/man-pages/man2/memfd_create.2.html)
 * creates an anonymous file.
 *
 * Returns an fd on success, and returns -1 and sets `errno` on failure.
 *
 * Available since API level 30 when compiling with `_GNU_SOURCE`.
 */
int memfd_create(const char* __name, unsigned __flags) __THROW __INTRODUCED_IN_API_R__ __attribute__((nonnull(1)));
#endif

#if __ANDROID_API__ >= 23

/*
 * Some third-party code uses the existence of POSIX_MADV_NORMAL to detect the
 * availability of posix_madvise. This is not correct, since having up-to-date
 * UAPI headers says nothing about the C library, but for the time being we
 * don't want to harm adoption of the unified headers.
 *
 * https://github.com/android-ndk/ndk/issues/395
 */

/** Flag for posix_madvise(). */
#define POSIX_MADV_NORMAL     MADV_NORMAL
/** Flag for posix_madvise(). */
#define POSIX_MADV_RANDOM     MADV_RANDOM
/** Flag for posix_madvise(). */
#define POSIX_MADV_SEQUENTIAL MADV_SEQUENTIAL
/** Flag for posix_madvise(). */
#define POSIX_MADV_WILLNEED   MADV_WILLNEED
/** Flag for posix_madvise(). */
#define POSIX_MADV_DONTNEED   MADV_DONTNEED

#endif

#if __BIONIC_AVAILABILITY_GUARD(23)
/**
 * [posix_madvise(3)](https://man7.org/linux/man-pages/man3/posix_madvise.3.html)
 * gives the kernel advice about future usage patterns.
 *
 * Available since API level 23.
 * See also madvise() which is available at all API levels.
 *
 * Returns 0 on success, and returns a positive error number on failure.
 */
int posix_madvise(void* __addr, size_t __size, int __advice) __THROW __INTRODUCED_IN_API_M__ __attribute__((nonnull(1)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(36)
/**
 * [mseal(2)](https://man7.org/linux/man-pages/man2/mseal.2.html)
 * seals the given range to prevent modifications such as mprotect() calls.
 *
 * Available since API level 36.
 * Requires a Linux 6.10 or newer kernel.
 * Always fails for 32-bit processes.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int mseal(void* __addr, size_t __size, unsigned long __flags) __INTRODUCED_IN_API_W__ __attribute__((nonnull(1)));
#endif

__END_DECLS
