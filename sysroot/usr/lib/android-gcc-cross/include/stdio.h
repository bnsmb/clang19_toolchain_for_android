/*	$OpenBSD: stdio.h,v 1.35 2006/01/13 18:10:09 miod Exp $	*/
/*	$NetBSD: stdio.h,v 1.18 1996/04/25 18:29:21 jtc Exp $	*/

/*-
 * Copyright (c) 1990 The Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Chris Torek.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)stdio.h	5.17 (Berkeley) 6/3/91
 */

#ifndef	_STDIO_H_
#define	_STDIO_H_

#include <sys/cdefs.h>
#include <sys/types.h>

#include <stdarg.h>
#include <stddef.h>

#include <bits/seek_constants.h>

#if __ANDROID_API__ < 24
#include <bits/struct_file.h>
#endif

__BEGIN_DECLS

typedef off_t fpos_t;
typedef off64_t fpos64_t;

struct __sFILE;
typedef struct __sFILE FILE;

#if __ANDROID_API__ >= 23
extern FILE* stdin __INTRODUCED_IN_API_M__;
extern FILE* stdout __INTRODUCED_IN_API_M__;
extern FILE* stderr __INTRODUCED_IN_API_M__;

/* C99 and earlier plus current C++ standards say these must be macros. */
#define stdin stdin
#define stdout stdout
#define stderr stderr
#else
/* Before M the actual symbols for stdin and friends had different names. */
extern FILE __sF[] /* __REMOVED_IN(23, "Use stdin/stdout/stderr") */;

#define stdin (&__sF[0])
#define stdout (&__sF[1])
#define stderr (&__sF[2])
#endif

/*
 * The following three definitions are for ANSI C, which took them
 * from System V, which brilliantly took internal interface macros and
 * made them official arguments to setvbuf(), without renaming them.
 * Hence, these ugly _IOxxx names are *supposed* to appear in user code.
 *
 * Although numbered as their counterparts above, the implementation
 * does not rely on this.
 */
#define	_IOFBF	0		/* setvbuf should set fully buffered */
#define	_IOLBF	1		/* setvbuf should set line buffered */
#define	_IONBF	2		/* setvbuf should set unbuffered */

#define	BUFSIZ	1024		/* size of buffer used by setbuf */
#define	EOF	(-1)

/*
 * FOPEN_MAX is a minimum maximum, and is the number of streams that
 * stdio can provide without attempting to allocate further resources
 * (which could fail).  Do not use this for anything.
 */
#define FOPEN_MAX 20
#define FILENAME_MAX 4096

#define L_tmpnam 4096
#define TMP_MAX 308915776

void clearerr(FILE* __fp) __THROW __attribute__((nonnull(1)));
int fclose(FILE* __fp) __attribute__((nonnull(1)));
__nodiscard int feof(FILE* __fp) __THROW __attribute__((nonnull(1)));
__nodiscard int ferror(FILE* __fp) __THROW __attribute__((nonnull(1)));
int fflush(FILE* __fp);
__nodiscard int fgetc(FILE* __fp) __attribute__((nonnull(1)));
char* fgets(char* __buf, int __size, FILE* __fp) __attribute__((nonnull(1,3)));
int fprintf(FILE* __fp , const char* __fmt, ...) __printflike(2, 3) __attribute__((nonnull(1,2)));
int fputc(int __ch, FILE* __fp) __attribute__((nonnull(2)));
int fputs(const char* __s, FILE* __fp) __attribute__((nonnull(1,2)));
size_t fread(void* __buf, size_t __size, size_t __count, FILE* __fp) __attribute__((nonnull(1,4)));

/**
 * [fscanf(3)](https://man7.org/linux/man-pages/man3/fscanf.3.html)
 * parses input from a file using a format string.
 *
 * Returns the number of successful matches,
 * or EOF if there are no matches before end of file.
 */
int fscanf(FILE* __fp, const char* __fmt, ...) __scanflike(2, 3) __attribute__((nonnull(1,2)));

size_t fwrite(const void* __buf, size_t __size, size_t __count, FILE* __fp) __attribute__((nonnull(1,4)));
__nodiscard int getc(FILE* __fp) __attribute__((nonnull(1)));
__nodiscard int getchar(void);

#if __BIONIC_AVAILABILITY_GUARD(18)
/**
 * [getdelim(2)](https://man7.org/linux/man-pages/man3/getdelim.3.html)
 * reads a delimited chunk from the given file.
 *
 * The memory to be used (and the size of the allocation) are the first
 * two arguments. Idiomatic code passes NULL on the first call,
 * and reuses the buffer on successive calls (hence the need to know its length).
 * Note in particular that the size of the allocation is generally _larger_
 * than the length of the chunk returned (hence the need to use the return value).
 *
 * Returns the length of the chunk (excluding the terminating NUL),
 * and returns -1 and sets `errno` on failure.
 */
ssize_t getdelim(char* * __line_ptr, size_t* __allocated_size_ptr, int __delimiter, FILE* __fp) __INTRODUCED_IN_API_J_MR2__ __attribute__((nonnull(1,2,4)));

/**
 * Equivalent to getdelim() with '\n' as the delimiter.
 */
ssize_t getline(char* * __line_ptr, size_t* __allocated_size_ptr, FILE* __fp) __INTRODUCED_IN_API_J_MR2__ __attribute__((nonnull(1,2,3)));
#endif /* __BIONIC_AVAILABILITY_GUARD(18) */

void perror(const char* __msg);
int printf(const char* __fmt, ...) __printflike(1, 2) __attribute__((nonnull(1)));
int putc(int __ch, FILE* __fp) __attribute__((nonnull(2)));
int putchar(int __ch);
int puts(const char* __s) __attribute__((nonnull(1)));
int remove(const char* __path) __THROW __attribute__((nonnull(1)));
void rewind(FILE* __fp) __attribute__((nonnull(1)));

/**
 * Equivalent to fscanf() with stdin as the file.
 */
int scanf(const char* __fmt, ...) __scanflike(1, 2) __attribute__((nonnull(1)));

void setbuf(FILE* __fp, char* __buf) __THROW __attribute__((nonnull(1)));
int setvbuf(FILE* __fp, char* __buf, int __mode, size_t __size) __THROW __attribute__((nonnull(1)));

/**
 * [sscanf(3)](https://man7.org/linux/man-pages/man3/sscanf.3.html)
 * parses input from a string using a format string.
 *
 * Note that many sscanf() implementations, including Android's,
 * call strlen() on the input which can lead to quadratic behavior on long strings.
 * In particular, this means that if you're working with a file,
 * you should prefer to call fscanf() rather than read a line into a string
 * and then using sscanf().
 *
 * Returns the number of successful matches,
 * or EOF if there are no matches before the end of the string.
 */
int sscanf(const char* __s, const char* __fmt, ...) __THROW __scanflike(2, 3) __attribute__((nonnull(1,2)));

int ungetc(int __ch, FILE* __fp) __attribute__((nonnull(2)));
int vfprintf(FILE* __fp, const char* __fmt, va_list __args) __printflike(2, 0) __attribute__((nonnull(1,2)));
int vprintf(const char* __fp, va_list __args) __printflike(1, 0) __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(21)
int dprintf(int __fd, const char* __fmt, ...) __printflike(2, 3) __INTRODUCED_IN_API_L__ __attribute__((nonnull(2)));
int vdprintf(int __fd, const char* __fmt, va_list __args) __printflike(2, 0) __INTRODUCED_IN_API_L__ __attribute__((nonnull(2)));
#else
int dprintf(int __fd, const char* __fmt, ...) __RENAME(fdprintf) __printflike(2, 3) __attribute__((nonnull(2)));
int vdprintf(int __fd, const char* __fmt, va_list __args) __RENAME(vfdprintf) __printflike(2, 0) __attribute__((nonnull(2)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

#if (defined(__STDC_VERSION__) && __STDC_VERSION__ < 201112L) || \
    (defined(__cplusplus) && __cplusplus < 201402L)
/**
 * gets() is an unsafe version of getline() for stdin.
 *
 * It was removed in C11 and C++14,
 * and should not be used by new code.
 */
char* gets(char* __buf) __attribute__((__deprecated__("gets() is unsafe, use getline() instead")));
#endif

int sprintf(char* __s, const char* __fmt, ...)
    __THROWNL __printflike(2, 3) __warnattr_strict("sprintf is often misused; please use snprintf") __attribute__((nonnull(2)));
int vsprintf(char* __s, const char* __fmt, va_list __args)
    __THROWNL __printflike(2, 0) __warnattr_strict("vsprintf is often misused; please use vsnprintf") __attribute__((nonnull(2)));
char* tmpnam(char* __s)
    __THROW __attribute__((__deprecated__("tmpnam is unsafe, use mkstemp or tmpfile instead")));
#define P_tmpdir "/tmp/" /* deprecated */
char* tempnam(const char* __dir, const char* __prefix)
    __THROW __attribute__((__deprecated__("tempnam is unsafe, use mkstemp or tmpfile instead")));

/**
 * [rename(2)](https://man7.org/linux/man-pages/man2/rename.2.html) changes
 * the name or location of a file.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int rename(const char* __old_path, const char* __new_path) __THROW __attribute__((nonnull(1,2)));

/**
 * [renameat(2)](https://man7.org/linux/man-pages/man2/renameat.2.html) changes
 * the name or location of a file, interpreting relative paths using an fd.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 */
int renameat(int __old_dir_fd, const char* __old_path, int __new_dir_fd, const char* __new_path) __THROW __attribute__((nonnull(2,4)));

#if defined(__USE_GNU)
/**
 * Flag for [renameat2(2)](https://man7.org/linux/man-pages/man2/renameat2.2.html)
 * to fail if the new path already exists.
 */
#define RENAME_NOREPLACE (1<<0)
#endif

#if defined(__USE_GNU)
/**
 * Flag for [renameat2(2)](https://man7.org/linux/man-pages/man2/renameat2.2.html)
 * to atomically exchange the two paths.
 */
#define RENAME_EXCHANGE (1<<1)
#endif

#if defined(__USE_GNU)
/**
 * Flag for [renameat2(2)](https://man7.org/linux/man-pages/man2/renameat2.2.html)
 * to create a union/overlay filesystem object.
 */
#define RENAME_WHITEOUT (1<<2)
#endif

#if defined(__USE_GNU) && __BIONIC_AVAILABILITY_GUARD(30)
/**
 * [renameat2(2)](https://man7.org/linux/man-pages/man2/renameat2.2.html) changes
 * the name or location of a file, interpreting relative paths using an fd,
 * with optional `RENAME_` flags.
 *
 * Returns 0 on success, and returns -1 and sets `errno` on failure.
 *
 * Available since API level 30 when compiling with `_GNU_SOURCE`.
 */
int renameat2(int __old_dir_fd, const char* __old_path, int __new_dir_fd, const char* __new_path, unsigned __flags) __THROW __INTRODUCED_IN_API_R__ __attribute__((nonnull(2,4)));
#endif

int fseek(FILE* __fp, long __offset, int __whence) __attribute__((nonnull(1)));
__nodiscard long ftell(FILE* __fp) __attribute__((nonnull(1)));

/* See https://android.googlesource.com/platform/bionic/+/main/docs/32-bit-abi.md */
#if defined(__USE_FILE_OFFSET64)

#if __BIONIC_AVAILABILITY_GUARD(24)
int fgetpos(FILE* __fp, fpos_t* __pos) __RENAME(fgetpos64) __INTRODUCED_IN_API_N__ __attribute__((nonnull(1,2)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(24)
int fsetpos(FILE* __fp, const fpos_t* __pos) __RENAME(fsetpos64) __INTRODUCED_IN_API_N__ __attribute__((nonnull(1,2)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(24)
int fseeko(FILE* __fp, off_t __offset, int __whence) __RENAME(fseeko64) __INTRODUCED_IN_API_N__ __attribute__((nonnull(1)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(24)
__nodiscard off_t ftello(FILE* __fp) __RENAME(ftello64) __INTRODUCED_IN_API_N__ __attribute__((nonnull(1)));
#endif

/* If __read_fn and __write_fn are both nullptr, it will cause EINVAL */
#if defined(__USE_BSD) && __BIONIC_AVAILABILITY_GUARD(24)
__nodiscard FILE* funopen(const void* __cookie,
              int (* __read_fn)(void*, char*, int),
              int (* __write_fn)(void*, const char*, int),
              fpos_t (* __seek_fn)(void*, fpos_t, int),
              int (* __close_fn)(void* )) __RENAME(funopen64) __INTRODUCED_IN_API_N__;
#endif

#else
int fgetpos(FILE* __fp, fpos_t* __pos) __attribute__((nonnull(1,2)));
int fsetpos(FILE* __fp, const fpos_t* __pos) __attribute__((nonnull(1,2)));
int fseeko(FILE* __fp, off_t __offset, int __whence) __attribute__((nonnull(1)));
__nodiscard off_t ftello(FILE* __fp) __attribute__((nonnull(1)));
#if defined(__USE_BSD)
/* If __read_fn and __write_fn are both nullptr, it will cause EINVAL */
__nodiscard FILE* funopen(const void* __cookie,
              int (* __read_fn)(void*, char*, int),
              int (* __write_fn)(void*, const char*, int),
              fpos_t (* __seek_fn)(void*, fpos_t, int),
              int (* __close_fn)(void* ));
#endif
#endif

#if __BIONIC_AVAILABILITY_GUARD(24)
int fgetpos64(FILE* __fp, fpos64_t* __pos) __INTRODUCED_IN_API_N__ __attribute__((nonnull(1,2)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(24)
int fsetpos64(FILE* __fp, const fpos64_t* __pos) __INTRODUCED_IN_API_N__ __attribute__((nonnull(1,2)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(24)
int fseeko64(FILE* __fp, off64_t __offset, int __whence) __INTRODUCED_IN_API_N__ __attribute__((nonnull(1)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(24)
__nodiscard off64_t ftello64(FILE* __fp) __INTRODUCED_IN_API_N__ __attribute__((nonnull(1)));
#endif

/* If __read_fn and __write_fn are both nullptr, it will cause EINVAL */
#if defined(__USE_BSD) && __BIONIC_AVAILABILITY_GUARD(24)
__nodiscard FILE* funopen64(const void* __cookie,
                int (* __read_fn)(void*, char*, int),
                int (* __write_fn)(void*, const char*, int),
                fpos64_t (* __seek_fn)(void*, fpos64_t, int),
                int (* __close_fn)(void* )) __INTRODUCED_IN_API_N__;
#endif

__nodiscard FILE* fopen(const char* __path, const char* __mode) __attribute__((nonnull(1,2)));

#if __BIONIC_AVAILABILITY_GUARD(24)
__nodiscard FILE* fopen64(const char* __path, const char* __mode) __INTRODUCED_IN_API_N__ __attribute__((nonnull(1,2)));
#endif

FILE* freopen(const char* __path, const char* __mode, FILE* __fp) __attribute__((nonnull(2,3)));

#if __BIONIC_AVAILABILITY_GUARD(24)
FILE* freopen64(const char* __path, const char* __mode, FILE* __fp) __INTRODUCED_IN_API_N__ __attribute__((nonnull(2,3)));
#endif

__nodiscard FILE* tmpfile(void);

#if __BIONIC_AVAILABILITY_GUARD(24)
__nodiscard FILE* tmpfile64(void) __INTRODUCED_IN_API_N__;
#endif

int snprintf(char* __buf, size_t __size, const char* __fmt, ...) __THROWNL __printflike(3, 4) __attribute__((nonnull(3)));
int vfscanf(FILE* __fp, const char* __fmt, va_list __args) __scanflike(2, 0) __attribute__((nonnull(1,2)));
int vscanf(const char* __fmt , va_list __args) __scanflike(1, 0) __attribute__((nonnull(1)));
int vsnprintf(char* __buf, size_t __size, const char* __fmt, va_list __args) __THROWNL __printflike(3, 0) __attribute__((nonnull(3)));
int vsscanf(const char* __s, const char* __fmt, va_list __args) __THROW __scanflike(2, 0) __attribute__((nonnull(1,2)));

#define L_ctermid 1024 /* size for ctermid() */

#if __BIONIC_AVAILABILITY_GUARD(26)
char* ctermid(char* __buf) __THROW __INTRODUCED_IN_API_O__;
#endif

__nodiscard FILE* fdopen(int __fd, const char* __mode) __THROW __attribute__((nonnull(2)));
__nodiscard int fileno(FILE* __fp) __THROW __attribute__((nonnull(1)));
int pclose(FILE* __fp) __attribute__((nonnull(1)));
__nodiscard FILE* popen(const char* __command, const char* __mode) __attribute__((nonnull(1,2)));
void flockfile(FILE*  __fp) __THROW __attribute__((nonnull(1)));
int ftrylockfile(FILE* __fp) __THROW __attribute__((nonnull(1)));
void funlockfile(FILE* __fp) __THROW __attribute__((nonnull(1)));
__nodiscard int getc_unlocked(FILE* __fp) __attribute__((nonnull(1)));
__nodiscard int getchar_unlocked(void);
int putc_unlocked(int __ch, FILE* __fp) __attribute__((nonnull(2)));
int putchar_unlocked(int __ch);

#if __BIONIC_AVAILABILITY_GUARD(23)
__nodiscard FILE* fmemopen(void* __buf, size_t __size, const char* __mode) __THROW __INTRODUCED_IN_API_M__ __attribute__((nonnull(3)));
#endif
#if __BIONIC_AVAILABILITY_GUARD(23)
__nodiscard FILE* open_memstream(char* * __ptr, size_t* __size_ptr) __THROW __INTRODUCED_IN_API_M__ __attribute__((nonnull(1,2)));
#endif

int  asprintf(char* * __s_ptr, const char* __fmt, ...) __THROWNL __printflike(2, 3) __attribute__((nonnull(1,2)));

/**
 * fgetln() is a less portable and harder to use variant of getline().
 * In particular, fgetln() does not guarantee a terminating NUL byte.
 *
 * New code should use getline().
 */
char* fgetln(FILE* __fp, size_t* __length_ptr) __attribute__((nonnull(1,2)));

int fpurge(FILE* __fp) __attribute__((nonnull(1)));
void setbuffer(FILE* __fp, char* __buf, int __size) __THROW __attribute__((nonnull(1)));
int setlinebuf(FILE* __fp) __THROW __attribute__((nonnull(1)));
int vasprintf(char* * __s_ptr, const char* __fmt, va_list __args) __THROWNL __printflike(2, 0) __attribute__((nonnull(1,2)));

#if __BIONIC_AVAILABILITY_GUARD(23)
void clearerr_unlocked(FILE* __fp) __THROW __INTRODUCED_IN_API_M__ __attribute__((nonnull(1)));
#endif
#if __BIONIC_AVAILABILITY_GUARD(23)
__nodiscard int feof_unlocked(FILE* __fp) __THROW __INTRODUCED_IN_API_M__ __attribute__((nonnull(1)));
#endif
#if __BIONIC_AVAILABILITY_GUARD(23)
__nodiscard int ferror_unlocked(FILE* __fp) __THROW __INTRODUCED_IN_API_M__ __attribute__((nonnull(1)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(24)
__nodiscard int fileno_unlocked(FILE* __fp) __THROW __INTRODUCED_IN_API_N__ __attribute__((nonnull(1)));
#endif

#define fropen(cookie, fn) funopen(cookie, fn, 0, 0, 0)
#define fwopen(cookie, fn) funopen(cookie, 0, fn, 0, 0)

#if defined(__USE_BSD) && __BIONIC_AVAILABILITY_GUARD(28)
int fflush_unlocked(FILE* __fp) __INTRODUCED_IN_API_P__;
#endif

#if defined(__USE_BSD) && __BIONIC_AVAILABILITY_GUARD(28)
__nodiscard int fgetc_unlocked(FILE* __fp) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1)));
#endif

#if defined(__USE_BSD) && __BIONIC_AVAILABILITY_GUARD(28)
int fputc_unlocked(int __ch, FILE* __fp) __INTRODUCED_IN_API_P__ __attribute__((nonnull(2)));
#endif

#if defined(__USE_BSD) && __BIONIC_AVAILABILITY_GUARD(28)
size_t fread_unlocked(void* __buf, size_t __size, size_t __count, FILE* __fp) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1,4)));
#endif

#if defined(__USE_BSD) && __BIONIC_AVAILABILITY_GUARD(28)
size_t fwrite_unlocked(const void* __buf, size_t __size, size_t __count, FILE* __fp) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1,4)));
#endif

#if defined(__USE_GNU) && __BIONIC_AVAILABILITY_GUARD(28)
int fputs_unlocked(const char* __s, FILE* __fp) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1,2)));
#endif

#if defined(__USE_GNU) && __BIONIC_AVAILABILITY_GUARD(28)
char* fgets_unlocked(char* __buf, int __size, FILE* __fp) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1,3)));
#endif

#if defined(__BIONIC_INCLUDE_FORTIFY_HEADERS)
#include <bits/fortify/stdio.h>
#endif

__END_DECLS

#endif
