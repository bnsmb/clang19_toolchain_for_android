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

#ifndef _ARPA_INET_H_
#define _ARPA_INET_H_

#include <sys/cdefs.h>

#include <endian.h>
#include <netinet/in.h>
#include <stdint.h>
#include <sys/types.h>

__BEGIN_DECLS

in_addr_t inet_addr(const char* __s) __THROW __attribute__((nonnull(1)));
int inet_aton(const char* __s, struct in_addr* __addr) __THROW __attribute__((nonnull(1)));

#if __BIONIC_AVAILABILITY_GUARD(21)
in_addr_t inet_lnaof(struct in_addr __addr) __THROW __INTRODUCED_IN_API_L__;
struct in_addr inet_makeaddr(in_addr_t __net, in_addr_t __host) __INTRODUCED_IN_API_L__;
in_addr_t inet_netof(struct in_addr __addr) __THROW __INTRODUCED_IN_API_L__;
in_addr_t inet_network(const char* __s) __THROW __INTRODUCED_IN_API_L__ __attribute__((nonnull(1)));
#endif /* __BIONIC_AVAILABILITY_GUARD(21) */

char* inet_ntoa(struct in_addr __addr)__THROW ;
const char* inet_ntop(int __af, const void* __src, char* __dst, socklen_t __size) __THROW __attribute__((nonnull(2,3)));
unsigned int inet_nsap_addr(const char* __ascii, unsigned char* __binary, int __n) __THROW __attribute__((nonnull(1,2)));
char* inet_nsap_ntoa(int __binary_length, const unsigned char* __binary, char* __ascii) __THROW __attribute__((nonnull(2)));
int inet_pton(int __af, const char* __src, void* __dst) __THROW __attribute__((nonnull(2,3)));

__END_DECLS

#endif
