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

#ifndef _SIGNAL_H_
#define _SIGNAL_H_

#include <sys/cdefs.h>
#include <sys/types.h>

#if defined(__riscv) && defined(__GNUC__)
/*
* The unwinder used by GCC requires a generic definition of the sigcontext struct,
* but Bionic does not provide that.
*/
#include <bits/sigcontext_riscv64.h>
#else
#include <asm/sigcontext.h>
#endif

#include <bits/pthread_types.h>
#include <bits/signal_types.h>
#include <bits/timespec.h>
#include <limits.h>

#include <sys/ucontext.h>
#define __BIONIC_HAVE_UCONTEXT_T

__BEGIN_DECLS

/* The kernel headers define SIG_DFL (0) and SIG_IGN (1) but not SIG_HOLD, since
 * SIG_HOLD is only used by the deprecated SysV signal API.
 */
#define SIG_HOLD __BIONIC_CAST(reinterpret_cast, sighandler_t, 2)

#if __BIONIC_AVAILABILITY_GUARD(21)
/* We take a few real-time signals for ourselves. May as well use the same names as glibc. */
#define SIGRTMIN (__libc_current_sigrtmin())
#define SIGRTMAX (__libc_current_sigrtmax())
int __libc_current_sigrtmin(void) __THROW __INTRODUCED_IN_API_L__;
int __libc_current_sigrtmax(void) __THROW __INTRODUCED_IN_API_L__;
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

extern const char* const sys_siglist[_NSIG];
extern const char* const sys_signame[_NSIG]; /* BSD compatibility. */

#define si_timerid si_tid /* glibc compatibility. */

int sigaction(int __signal, const struct sigaction* __new_action, struct sigaction* __old_action)__THROW ;

#if __BIONIC_AVAILABILITY_GUARD(28)
int sigaction64(int __signal, const struct sigaction64* __new_action, struct sigaction64* __old_action) __INTRODUCED_IN_API_P__;
#endif

int siginterrupt(int __signal, int __flag)__THROW ;

#if __BIONIC_AVAILABILITY_GUARD(21)
sighandler_t signal(int __signal, sighandler_t __handler) __THROW __INTRODUCED_IN_API_L__;
int sigaddset(sigset_t* __set, int __signal) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

#if __BIONIC_AVAILABILITY_GUARD(28)
int sigaddset64(sigset64_t* __set, int __signal) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(21)
int sigdelset(sigset_t* __set, int __signal) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

#if __BIONIC_AVAILABILITY_GUARD(28)
int sigdelset64(sigset64_t* __set, int __signal) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(21)
int sigemptyset(sigset_t* __set) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

#if __BIONIC_AVAILABILITY_GUARD(28)
int sigemptyset64(sigset64_t* __set) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(21)
int sigfillset(sigset_t* __set) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

#if __BIONIC_AVAILABILITY_GUARD(28)
int sigfillset64(sigset64_t* __set) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(21)
int sigismember(const sigset_t* __set, int __signal) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

#if __BIONIC_AVAILABILITY_GUARD(28)
int sigismember64(const sigset64_t* __set, int __signal) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1)));
#endif


int sigpending(sigset_t* __set) __THROW __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(28)
int sigpending64(sigset64_t* __set) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1)));
#endif

int sigprocmask(int __how, const sigset_t* __new_set, sigset_t* __old_set)__THROW ;

#if __BIONIC_AVAILABILITY_GUARD(28)
int sigprocmask64(int __how, const sigset64_t* __new_set, sigset64_t* __old_set) __INTRODUCED_IN_API_P__;
#endif

int sigsuspend(const sigset_t* __mask) __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(28)
int sigsuspend64(const sigset64_t* __mask) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1)));
#endif

int sigwait(const sigset_t* __set, int* __signal) __attribute__((nonnull(1,2)));

#if __BIONIC_AVAILABILITY_GUARD(28)
int sigwait64(const sigset64_t* __set, int* __signal) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1,2)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(26)
int sighold(int __signal)
  __THROW __attribute__((__deprecated__("use sigprocmask() or pthread_sigmask() instead")))
  __INTRODUCED_IN_API_O__;
#endif

#if __BIONIC_AVAILABILITY_GUARD(26)
int sigignore(int __signal)
  __THROW __attribute__((__deprecated__("use sigaction() instead"))) __INTRODUCED_IN_API_O__;
#endif

#if __BIONIC_AVAILABILITY_GUARD(26)
int sigpause(int __signal)
  __attribute__((__deprecated__("use sigsuspend() instead"))) __INTRODUCED_IN_API_O__;
#endif

#if __BIONIC_AVAILABILITY_GUARD(26)
int sigrelse(int __signal)
  __THROW __attribute__((__deprecated__("use sigprocmask() or pthread_sigmask() instead")))
  __INTRODUCED_IN_API_O__;
#endif

#if __BIONIC_AVAILABILITY_GUARD(26)
sighandler_t sigset(int __signal, sighandler_t __handler)
  __THROW __attribute__((__deprecated__("use sigaction() instead"))) __INTRODUCED_IN_API_O__;
#endif

int raise(int __signal)__THROW ;
int kill(pid_t __pid, int __signal)__THROW ;
int killpg(int __pgrp, int __signal)__THROW ;

#if __BIONIC_AVAILABILITY_GUARD(16)
int tgkill(int __tgid, int __tid, int __signal) __INTRODUCED_IN_API_J__;
#endif /* __BIONIC_AVAILABILITY_GUARD(16) */

int sigaltstack(const stack_t* __new_signal_stack, stack_t*  __old_signal_stack)__THROW ;

#if __BIONIC_AVAILABILITY_GUARD(17)
void psiginfo(const siginfo_t* __info, const char* __msg) __INTRODUCED_IN_API_J_MR1__ __attribute__((nonnull(1)));
void psignal(int __signal, const char* __msg) __INTRODUCED_IN_API_J_MR1__;
#endif /* __BIONIC_AVAILABILITY_GUARD(17) */

int pthread_kill(pthread_t __pthread, int __signal)__THROW ;

#if defined(__USE_GNU) && __BIONIC_AVAILABILITY_GUARD(29)
int pthread_sigqueue(pthread_t __pthread, int __signal, const union sigval __value) __THROW __INTRODUCED_IN_API_Q__;
#endif

int pthread_sigmask(int __how, const sigset_t* __new_set, sigset_t* __old_set)__THROW ;

#if __BIONIC_AVAILABILITY_GUARD(28)
int pthread_sigmask64(int __how, const sigset64_t* __new_set, sigset64_t* __old_set) __INTRODUCED_IN_API_P__;
#endif

#if __BIONIC_AVAILABILITY_GUARD(23)
int sigqueue(pid_t __pid, int __signal, const union sigval __value) __THROW __INTRODUCED_IN_API_M__;
#endif

#if __BIONIC_AVAILABILITY_GUARD(23)
int sigtimedwait(const sigset_t* __set, siginfo_t* __info, const struct timespec* __timeout) __INTRODUCED_IN_API_M__ __attribute__((nonnull(1)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(28)
int sigtimedwait64(const sigset64_t* __set, siginfo_t* __info, const struct timespec* __timeout) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(23)
int sigwaitinfo(const sigset_t* __set, siginfo_t* __info) __INTRODUCED_IN_API_M__ __attribute__((nonnull(1)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(28)
int sigwaitinfo64(const sigset64_t* __set, siginfo_t* __info) __INTRODUCED_IN_API_P__ __attribute__((nonnull(1)));
#endif

/**
 * Buffer size suitable for any call to sig2str().
 */
#define SIG2STR_MAX 32

#if __BIONIC_AVAILABILITY_GUARD(36)
/**
 * [sig2str(3)](https://man7.org/linux/man-pages/man3/sig2str.3.html)
 * converts the integer corresponding to SIGSEGV (say) into a string
 * like "SEGV" (not including the "SIG" used in the constants).
 * SIG2STR_MAX is a safe size to use for the buffer.
 *
 * Use strsignal() instead to convert the integer corresponding to SIGSEGV (say)
 * into a string like "Segmentation violation".
 *
 * Returns 0 on success, and returns -1 _without_ setting errno otherwise.
 *
 * Available since API level 36 (but see also strsignal()).
 */
int sig2str(int __signal, char* __buf) __INTRODUCED_IN_API_W__ __attribute__((nonnull(2)));
#endif

#if __BIONIC_AVAILABILITY_GUARD(36)
/**
 * [str2sig(3)](https://man7.org/linux/man-pages/man3/str2sig.3.html)
 * converts a string like "SEGV" (not including the "SIG" used in the constants)
 * into the integer corresponding to SIGSEGV.
 *
 * Returns 0 on success, and returns -1 _without_ setting errno otherwise.
 *
 * Available since API level 36.
 */
int str2sig(const char* __name, int* __signal) __INTRODUCED_IN_API_W__ __attribute__((nonnull(1,2)));
#endif

__END_DECLS

#if __ANDROID_API__ < 21
#include <android/legacy_signal_inlines.h>
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

#endif
