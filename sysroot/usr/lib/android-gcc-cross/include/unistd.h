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

#include <errno.h>
#include <stddef.h>
#include <sys/types.h>
#include <sys/select.h>

#include <bits/fcntl.h>
#include <bits/getentropy.h>
#include <bits/getopt.h>
#include <bits/ioctl.h>
#include <bits/lockf.h>
#include <bits/posix_limits.h>
#include <bits/seek_constants.h>
#include <bits/sysconf.h>

__BEGIN_DECLS

#define STDIN_FILENO	0
#define STDOUT_FILENO	1
#define STDERR_FILENO	2

#define F_OK 0
#define X_OK 1
#define W_OK 2
#define R_OK 4

#define _PC_FILESIZEBITS 0
#define _PC_LINK_MAX 1
#define _PC_MAX_CANON 2
#define _PC_MAX_INPUT 3
#define _PC_NAME_MAX 4
#define _PC_PATH_MAX 5
#define _PC_PIPE_BUF 6
#define _PC_2_SYMLINKS 7
#define _PC_ALLOC_SIZE_MIN 8
#define _PC_REC_INCR_XFER_SIZE 9
#define _PC_REC_MAX_XFER_SIZE 10
#define _PC_REC_MIN_XFER_SIZE 11
#define _PC_REC_XFER_ALIGN 12
#define _PC_SYMLINK_MAX 13
#define _PC_CHOWN_RESTRICTED 14
#define _PC_NO_TRUNC 15
#define _PC_VDISABLE 16
#define _PC_ASYNC_IO 17
#define _PC_PRIO_IO 18
#define _PC_SYNC_IO 19

/**
 * The current backing array for environment variables,
 * unsorted and terminated with a null pointer.
 *
 * This is only safe for use in single-threaded code.
 *
 * Calls to putenv()/setenv()/unsetenv() may implicitly free this array,
 * so even in single-threaded code it's unsafe to store a copy of this pointer.
 *
 * Pointers in this array are valid for the lifetime of the process.
 *
 * All environment variables can be unset at once by setting `environ` to null,
 * but new code should call clearenv() instead, for thread safety.
 */
extern char* * environ;

__noreturn void _exit(int __status);

/**
 * [fork(2)](https://man7.org/linux/man-pages/man2/fork.2.html) creates a new
 * process. fork() runs any handlers set by pthread_atfork().
 *
 * Returns 0 in the child, the pid of the child in the parent,
 * and returns -1 and sets `errno` on failure.
 */
pid_t fork(void)__THROWNL ;

#if __BIONIC_AVAILABILITY_GUARD(35)
/**
 * _Fork() creates a new process. _Fork() differs from fork() in that it does
 * not run any handlers set by pthread_atfork(). In addition to any user-defined
 * ones, bionic uses pthread_atfork() handlers to ensure consistency of its own
 * state, so the child should only call
 * [POSIX async-safe](https://man7.org/linux/man-pages/man7/signal-safety.7.html)
 * functions.
 *
 * Returns 0 in the child, the pid of the child in the parent,
 * and returns -1 and sets `errno` on failure.
 *
 * Available since API level 35.
 */
pid_t _Fork(void) __THROW __INTRODUCED_IN_API_V__;
#endif

/**
 * [vfork(2)](https://man7.org/linux/man-pages/man2/vfork.2.html) creates a new
 * process. vfork() differs from fork() in that it does not run any handlers
 * set by pthread_atfork(), and the parent is suspended until the child calls
 * exec() or exits.
 *
 * Returns 0 in the child, the pid of the child in the parent,
 * and returns -1 and sets `errno` on failure.
 */
pid_t vfork(void) __THROW __returns_twice;

/**
 * [getpid(2)](https://man7.org/linux/man-pages/man2/getpid.2.html) returns
 * the caller's process ID.
 *
 * Returns the caller's process ID.
 */
pid_t  getpid(void)__THROW ;

/**
 * [gettid(2)](https://man7.org/linux/man-pages/man2/gettid.2.html) returns
 * the caller's thread ID.
 *
 * Returns the caller's thread ID.
 */
pid_t  gettid(void)__THROW ;

pid_t  getpgid(pid_t __pid)__THROW ;
int    setpgid(pid_t __pid, pid_t __pgid)__THROW ;
pid_t  getppid(void)__THROW ;
pid_t  getpgrp(void)__THROW ;
int    setpgrp(void)__THROW ;

#if __BIONIC_AVAILABILITY_GUARD(17)
pid_t  getsid(pid_t __pid) __THROW __INTRODUCED_IN_API_J_MR1__;
#endif /* __BIONIC_AVAILABILITY_GUARD(17) */

pid_t  setsid(void)__THROW ;

int execv(const char* __path, char* const* __argv) __THROW __attribute__((nonnull(1)));
int execvp(const char* __file, char* const* __argv) __THROW __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(21)
int execvpe(const char* __file, char* const* __argv, char* const* __envp) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

int execve(const char* __file, char* const* __argv, char* const* __envp) __THROW __attribute__((nonnull(1)));
int execl(const char* __path, const char* __arg0, ...) __THROW __attribute__((__sentinel__));
int execlp(const char* __file, const char* __arg0, ...) __THROW __attribute__((__sentinel__));
int execle(const char* __path, const char* __arg0, ... /*,  char* const* __envp */)
    __THROW __attribute__((__sentinel__(1)));

#if __BIONIC_AVAILABILITY_GUARD(28)
int fexecve(int __fd, char* const* __argv, char* const* __envp) __THROW __INTRODUCED_IN_API_P__;
#endif

int nice(int __incr)__THROW ;

/**
 * [setegid(2)](https://man7.org/linux/man-pages/man2/setegid.2.html) sets
 * the effective group ID.
 *
 * On Android, this function only affects the calling thread, not all threads
 * in the process.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int setegid(gid_t __gid)__THROW ;

/**
 * [seteuid(2)](https://man7.org/linux/man-pages/man2/seteuid.2.html) sets
 * the effective user ID.
 *
 * On Android, this function only affects the calling thread, not all threads
 * in the process.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int seteuid(uid_t __uid)__THROW ;

/**
 * [setgid(2)](https://man7.org/linux/man-pages/man2/setgid.2.html) sets
 * the group ID.
 *
 * On Android, this function only affects the calling thread, not all threads
 * in the process.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int setgid(gid_t __gid)__THROW ;

/**
 * [setregid(2)](https://man7.org/linux/man-pages/man2/setregid.2.html) sets
 * the real and effective group IDs (use -1 to leave an ID unchanged).
 *
 * On Android, this function only affects the calling thread, not all threads
 * in the process.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int setregid(gid_t __rgid, gid_t __egid)__THROW ;

/**
 * [setresgid(2)](https://man7.org/linux/man-pages/man2/setresgid.2.html) sets
 * the real, effective, and saved group IDs (use -1 to leave an ID unchanged).
 *
 * On Android, this function only affects the calling thread, not all threads
 * in the process.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int setresgid(gid_t __rgid, gid_t __egid, gid_t __sgid)__THROW ;

/**
 * [setresuid(2)](https://man7.org/linux/man-pages/man2/setresuid.2.html) sets
 * the real, effective, and saved user IDs (use -1 to leave an ID unchanged).
 *
 * On Android, this function only affects the calling thread, not all threads
 * in the process.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int setresuid(uid_t __ruid, uid_t __euid, uid_t __suid)__THROW ;

/**
 * [setreuid(2)](https://man7.org/linux/man-pages/man2/setreuid.2.html) sets
 * the real and effective group IDs (use -1 to leave an ID unchanged).
 *
 * On Android, this function only affects the calling thread, not all threads
 * in the process.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int setreuid(uid_t __ruid, uid_t __euid)__THROW ;

/**
 * [setuid(2)](https://man7.org/linux/man-pages/man2/setuid.2.html) sets
 * the user ID.
 *
 * On Android, this function only affects the calling thread, not all threads
 * in the process.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int setuid(uid_t __uid)__THROW ;

uid_t getuid(void)__THROW ;
uid_t geteuid(void)__THROW ;
gid_t getgid(void)__THROW ;
gid_t getegid(void)__THROW ;
int getgroups(int __size, gid_t* __list)__THROW ;
int setgroups(size_t __size, const gid_t* __list)__THROW ;
int getresuid(uid_t* __ruid, uid_t* __euid, uid_t* __suid) __THROW __attribute__((nonnull(1,2,3)));
int getresgid(gid_t* __rgid, gid_t* __egid, gid_t* __sgid) __THROW __attribute__((nonnull(1,2,3)));
char* getlogin(void);

#if __BIONIC_AVAILABILITY_GUARD(28)
int getlogin_r(char* __buffer, size_t __buffer_size) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1)));
#endif

long fpathconf(int __fd, int __name)__THROW ;
long pathconf(const char* __path, int __name) __THROW __attribute__((nonnull(1)));

int access(const char* __path, int __mode) __THROW __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(16)
int faccessat(int __dirfd, const char* __path, int __mode, int __flags) __THROW __INTRODUCED_IN_API_J__ __attribute__((nonnull(2)));
#endif /* __BIONIC_AVAILABILITY_GUARD(16) */

int link(const char* __old_path, const char* __new_path) __THROW __attribute__((nonnull(1,2)));

#if __BIONIC_AVAILABILITY_GUARD(21)
int linkat(int __old_dir_fd, const char* __old_path, int __new_dir_fd, const char* __new_path, int __flags) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(2,4)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

int unlink(const char* __path) __THROW __attribute__((nonnull(1)));
int unlinkat(int __dirfd, const char* __path, int __flags) __THROW __attribute__((nonnull(2)));

/**
 * [chdir(2)](https://man7.org/linux/man-pages/man2/chdir.2.html) changes
 * the current working directory to the given path.
 *
 * This function affects all threads in the process, so is generally a bad idea
 * on Android where most code will be running in a multi-threaded context.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int chdir(const char* __path) __THROW __attribute__((nonnull(1)));

/**
 * [fchdir(2)](https://man7.org/linux/man-pages/man2/fchdir.2.html) changes
 * the current working directory to the given fd.
 *
 * This function affects all threads in the process, so is generally a bad idea
 * on Android where most code will be running in a multi-threaded context.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int fchdir(int __fd)__THROW ;

int rmdir(const char* __path) __THROW __attribute__((nonnull(1)));

/**
 * [pipe(2)](https://man7.org/linux/man-pages/man2/pipe.2.html) creates a pipe.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int pipe(int __fds[2]) __THROW __attribute__((nonnull(1)));

/**
 * [pipe2(2)](https://man7.org/linux/man-pages/man2/pipe2.2.html) creates a pipe,
 * with flags.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int pipe2(int __fds[2], int __flags) __THROW __attribute__((nonnull(1)));

int chroot(const char* __path) __THROW __attribute__((nonnull(1)));
int symlink(const char* __old_path, const char* __new_path) __THROW __attribute__((nonnull(1,2)));

#if __BIONIC_AVAILABILITY_GUARD(21)
int symlinkat(const char* __old_path, int __new_dir_fd, const char* __new_path) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1,3)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

ssize_t readlink(const char* __path, char* __buf, size_t __buf_size) __THROW __attribute__((nonnull(1,2)));

#if __BIONIC_AVAILABILITY_GUARD(21)
ssize_t readlinkat(int __dir_fd, const char* __path, char* __buf, size_t __buf_size) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(2,3)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

int chown(const char* __path, uid_t __owner, gid_t __group) __THROW __attribute__((nonnull(1)));
int fchown(int __fd, uid_t __owner, gid_t __group)__THROW ;
int fchownat(int __dir_fd, const char* __path, uid_t __owner, gid_t __group, int __flags) __THROW __attribute__((nonnull(2)));
int lchown(const char* __path, uid_t __owner, gid_t __group) __THROW __attribute__((nonnull(1)));
char* getcwd(char* __buf, size_t __size)__THROW ;

/**
 * [sync(2)](https://man7.org/linux/man-pages/man2/sync.2.html) syncs changes
 * to disk, for all file systems.
 */
void sync(void)__THROW ;

#if defined(__USE_GNU) && __BIONIC_AVAILABILITY_GUARD(28)
/**
 * [syncfs(2)](https://man7.org/linux/man-pages/man2/sync.2.html) syncs changes
 * to disk, for the file system corresponding to the given file descriptor.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 *
 * Available since API level 28 when compiling with `_GNU_SOURCE`.
 */
int syncfs(int __fd) __THROW __INTRODUCED_IN_API_P__;
#endif

int close(int __fd);

/**
 * [read(2)](https://man7.org/linux/man-pages/man2/read.2.html) reads
 * up to `__count` bytes from file descriptor `__fd` into `__buf`.
 *
 * Note: `__buf` is not normally nullable, but may be null in the
 * special case of a zero-length read(), which while not generally
 * useful may be meaningful to some device drivers.
 *
 * Returns the number of bytes read on success, and returns -1 and sets `errno` on failure.
 */
ssize_t read(int __fd, void* __buf, size_t __count);

/**
 * [write(2)](https://man7.org/linux/man-pages/man2/write.2.html) writes
 * up to `__count` bytes to file descriptor `__fd` from `__buf`.
 *
 * Note: `__buf` is not normally nullable, but may be null in the
 * special case of a zero-length write(), which while not generally
 * useful may be meaningful to some device drivers.
 *
 * Returns the number of bytes written on success, and returns -1 and sets `errno` on failure.
 */
ssize_t write(int __fd, const void* __buf, size_t __count);

int dup(int __old_fd)__THROW ;
int dup2(int __old_fd, int __new_fd)__THROW ;
#if __BIONIC_AVAILABILITY_GUARD(21)
int dup3(int __old_fd, int __new_fd, int __flags) __THROW __INTRODUCED_IN_API_L__;
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */
int fsync(int __fd);
int fdatasync(int __fd);

/* See https://android.googlesource.com/platform/bionic/+/main/docs/32-bit-abi.md */

#if defined(__USE_FILE_OFFSET64)
int truncate(const char* __path, off_t __length) __REDIRECT_NTH(truncate64) __attribute__((nonnull(1)));
off_t lseek(int __fd, off_t __offset, int __whence) __REDIRECT_NTH(lseek64);
ssize_t pread(int __fd, void* __buf, size_t __count, off_t __offset) __RENAME(pread64) __attribute__((nonnull(2)));
ssize_t pwrite(int __fd, const void* __buf, size_t __count, off_t __offset) __RENAME(pwrite64) __attribute__((nonnull(2)));
int ftruncate(int __fd, off_t __length) __REDIRECT_NTH(ftruncate64);
#else
int truncate(const char* __path, off_t __length) __THROW __attribute__((nonnull(1)));
off_t lseek(int __fd, off_t __offset, int __whence)__THROW ;
ssize_t pread(int __fd, void* __buf, size_t __count, off_t __offset) __attribute__((nonnull(2)));
ssize_t pwrite(int __fd, const void* __buf, size_t __count, off_t __offset) __attribute__((nonnull(2)));
int ftruncate(int __fd, off_t __length)__THROW ;
#endif

#if __BIONIC_AVAILABILITY_GUARD(21)
int truncate64(const char* __path, off64_t __length) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

off64_t lseek64(int __fd, off64_t __offset, int __whence)__THROW ;
ssize_t pread64(int __fd, void* __buf, size_t __count, off64_t __offset) __attribute__((nonnull(2)));
ssize_t pwrite64(int __fd, const void* __buf, size_t __count, off64_t __offset) __attribute__((nonnull(2)));
int ftruncate64(int __fd, off64_t __length)__THROW ;

int pause(void);
unsigned int alarm(unsigned int __seconds)__THROW ;
unsigned int sleep(unsigned int __seconds);
int usleep(useconds_t __microseconds);

#if __BIONIC_AVAILABILITY_GUARD(26)
/**
 * [getdomainname(2)](https://man7.org/linux/man-pages/man2/getdomainname.2.html)
 * copies the system's domain name into the supplied buffer.
 *
 * A buffer of size SYS_NMLN from <sys/utsname.h> is guaranteed large enough,
 * because this is just a wrapper for uname().
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int getdomainname(char* __buf, size_t __buf_size) __THROW __INTRODUCED_IN_API_O__ __attribute__((nonnull(1)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(26)
int setdomainname(const char* __name, size_t __n) __THROW __INTRODUCED_IN_API_O__ __attribute__((nonnull(1)));
#endif

/**
 * [gethostname(2)](https://man7.org/linux/man-pages/man2/gethostname.2.html)
 * copies the system's host name into the supplied buffer.
 *
 * Contrary to POSIX, this implementation fails if the buffer is too small.
 * A buffer of size SYS_NMLN from <sys/utsname.h> is guaranteed large enough,
 * because this is just a wrapper for uname().
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int gethostname(char* _buf, size_t __buf_size) __THROW __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(23)
int sethostname(const char* __name, size_t __n) __THROW __INTRODUCED_IN_API_M__ __attribute__((nonnull(1)));
#endif

int brk(void* __addr) __THROW __attribute__((nonnull(1)));
void* sbrk(ptrdiff_t __increment)__THROW ;

int isatty(int __fd)__THROW ;
char* ttyname(int __fd)__THROW ;
int ttyname_r(int __fd, char* __buf, size_t __buf_size) __THROW __attribute__((nonnull(2)));

int acct(const char* __path)__THROW ;

#if __BIONIC_AVAILABILITY_GUARD(21)
/**
 * [getpagesize(2)](https://man7.org/linux/man-pages/man2/getpagesize.2.html)
 * returns the system's page size. This is slightly faster than going via
 * sysconf(), and avoids the linear search in getauxval().
 *
 * Returns the system's page size in bytes.
 */
int getpagesize(void) __THROW __attribute_const__ __INTRODUCED_IN_API_L__;
#else
__static_inline__ int getpagesize(void) {
	long value = sysconf(_SC_PAGESIZE);
	return (int) value;
}
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

long syscall(long __number, ...)__THROW ;

int daemon(int __no_chdir, int __no_close)__THROW ;

#if defined(__arm__) || (defined(__mips__) && !defined(__LP64__))
/**
 * New code should use __builtin___clear_cache() instead, which works on
 * all architectures.
 */
int cacheflush(long __addr, long __nbytes, long __cache);
#endif

pid_t tcgetpgrp(int __fd)__THROW ;
int tcsetpgrp(int __fd, pid_t __pid)__THROW ;

/* Used to retry syscalls that can return EINTR. */
#define TEMP_FAILURE_RETRY(exp) ({         \
    __typeof__(exp) _rc;                   \
    do {                                   \
        _rc = (exp);                       \
    } while (_rc == -1 && errno == EINTR); \
    _rc; })

#if __BIONIC_AVAILABILITY_GUARD(34)
/**
 * [copy_file_range(2)](https://man7.org/linux/man-pages/man2/copy_file_range.2.html) copies
 * a range of data from one file descriptor to another.
 *
 * Available since API level 34.
 *
 * Returns the number of bytes copied on success, and returns -1 and sets
 * `errno` on failure.
 */
ssize_t copy_file_range(int __fd_in, off64_t* __off_in, int __fd_out, off64_t* __off_out, size_t __length, unsigned int __flags) __INTRODUCED_IN_API_U__;
#endif

#if __ANDROID_API__ >= 28
void swab(const void* __src, void* __dst, ssize_t __byte_count) __THROW __INTRODUCED_IN_API_P__ __attribute__((nonnull(1,2)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(34)
/**
 * [close_range(2)](https://man7.org/linux/man-pages/man2/close_range.2.html)
 * performs an action (which depends on value of flags) on an inclusive range
 * of file descriptors.
 *
 * Available since API level 34.
 *
 * Note: there is no emulation on too old kernels, hence this will fail with
 * -1/ENOSYS on pre-5.9 kernels, -1/EINVAL for unsupported flags.  In particular
 * CLOSE_RANGE_CLOEXEC requires 5.11, though support was backported to Android
 * Common Kernel 5.10-T.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int close_range(unsigned int __min_fd, unsigned int __max_fd, int __flags) __THROW __INTRODUCED_IN_API_U__;
#endif

#if defined(__BIONIC_INCLUDE_FORTIFY_HEADERS)
#define _UNISTD_H_
#include <bits/fortify/unistd.h>
#undef _UNISTD_H_
#endif

__END_DECLS

#include <android/legacy_unistd_inlines.h>
