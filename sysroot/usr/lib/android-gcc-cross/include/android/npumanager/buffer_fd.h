/*
 * Copyright 2026 The Android Open Source Project
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

/**
 * @file buffer_fd.h
 * @brief API to interact with NpuManagerService to manage buffers.
 */

#ifndef ANDROID_NPUMANAGER_BUFFER_FD_H
#define ANDROID_NPUMANAGER_BUFFER_FD_H

#include <sys/cdefs.h>
#include <android/npumanager/buffer.h>

__BEGIN_DECLS

/**
 * Gets the file descriptor of the buffer.
 *
 * Available since API level 37.
 *
 * \param buf The buffer to get the file descriptor of.
 * \return The file descriptor of the buffer.
 *
 *         The file descriptor is valid until the buffer is freed with ANpuBuffer_free().
 *
 *         If the buffer is preempted after the user calls ANpuBuffer_getFd(), the
 *         returned fd is still valid, but attempting to map the buffer will fail with ENOENT.
 */
int ANpuBuffer_getFd(ANpuBuffer* buf) __INTRODUCED_IN(37) __attribute__((nonnull(1)));

__END_DECLS

#endif  // ANDROID_NPUMANAGER_BUFFER_FD_H
