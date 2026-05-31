/*
 * Copyright (C) 2016 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#pragma once

/**
 * @def __ANDROID_UNAVAILABLE_SYMBOLS_ARE_WEAK__
 *
 * Controls whether calling APIs newer than the developer's minSdkVersion are a
 * build error (when not defined) or allowed as a weak reference with a
 * __builtin_available() guard (when defined).
 *
 * See https://developer.android.com/ndk/guides/using-newer-apis for more
 * details.
 */
#if defined(__ANDROID_UNAVAILABLE_SYMBOLS_ARE_WEAK__)
// When the caller is using weak API references, we should expose the decls for
// APIs which are not available in the caller's minSdkVersion, otherwise there's
// no way to take advantage of the weak references.
#define __BIONIC_AVAILABILITY_GUARD(api_level) 1
#else
// When the caller is using strict API references, we hide APIs which are not
// available in the caller's minSdkVersion. This is a bionic-only deviation in
// behavior from the rest of the NDK headers, but it's necessary to maintain
// source compatibility with 3p libraries that either can't correctly detect API
// availability (either incorrectly detecting as always-available or as
// never-available, but neither is true), or define their own polyfills which
// conflict with our declarations.
//
// https://github.com/android/ndk/issues/2081
#define __BIONIC_AVAILABILITY_GUARD(api_level) (__ANDROID_MIN_SDK_VERSION__ >= (api_level))
#endif

#define __INTRODUCED_IN(api_level) 
#define __DEPRECATED_IN(api_level, msg) __attribute__((deprecated("since " #api_level ". " msg)))
#define __REMOVED_IN(api_level, msg) __DEPRECATED_IN(api_level, msg)
 
// The same availability attribute can't be annotated multiple times. Therefore, the macros are
// defined for the configuration that it is valid for so that declarations like the below doesn't
// cause inconsistent availability values which is an error with -Wavailability:
//
// void foo() __INTRODUCED_IN_32(30) __INTRODUCED_IN_64(31);
//
#if !defined(__LP64__)
#define __INTRODUCED_IN_32(api_level) __attribute__((annotate("introduced_in_32=" #api_level)))
#define __INTRODUCED_IN_64(api_level)
#else
#define __INTRODUCED_IN_32(api_level)
#define __INTRODUCED_IN_64(api_level) __attribute__((annotate("introduced_in_64=" #api_level)))
#endif

#define __INTRODUCED_IN_ARM(api_level) __attribute__((annotate("introduced_in_arm=" #api_level)))
#define __INTRODUCED_IN_X86(api_level) __attribute__((annotate("introduced_in_x86=" #api_level)))
#define __INTRODUCED_IN_MIPS(api_level) __attribute__((annotate("introduced_in_mips=" #api_level)))
