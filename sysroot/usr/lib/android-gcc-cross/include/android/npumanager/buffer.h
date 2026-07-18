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
 * @file buffer.h
 * @brief API to interact with NpuManagerService to manage buffers.
 */
/**
 * @defgroup ANpuBuffer NPU manager buffer
 *
 * @{
 */

#ifndef ANDROID_NPUMANAGER_BUFFER_H
#define ANDROID_NPUMANAGER_BUFFER_H

#include <stdbool.h>
#include <stdint.h>
#include <sys/cdefs.h>
#include <sys/types.h>

__BEGIN_DECLS

/** Opaque type of an NPU buffer. */
struct ANpuBuffer;
typedef struct ANpuBuffer ANpuBuffer;

/**
 * The range of relative priority of the buffer within the app.
 *
 * These values defines the valid range for the buffer_priority field.
 * The buffer_priority field must be within the range
 * [ANPUBUFFER_PRIORITY_MIN, ANPUBUFFER_PRIORITY_MAX], inclusive.
 */
typedef enum ANpuBuffer_Priority : int32_t {
    /** Introduced in API 37.  */
    ANPUBUFFER_PRIORITY_MIN = 0,
    /** Introduced in API 37.  */
    ANPUBUFFER_PRIORITY_DEFAULT = 500,
    /** Introduced in API 37.  */
    ANPUBUFFER_PRIORITY_MAX = 1000,
} ANpuBuffer_Priority;

/**
 * The purpose of the buffer.
 *
 * For input/output buffers, use AHardwareBuffer instead.
 */
typedef enum ANpuBuffer_Type : int8_t {
    /** Introduced in API 37.  */
    ANPUBUFFER_TYPE_UNKNOWN,
    /** Introduced in API 37.  */
    ANPUBUFFER_TYPE_MODEL_EXECUTABLE,
    /** Introduced in API 37.  */
    ANPUBUFFER_TYPE_MODEL_WEIGHTS,
    /** Introduced in API 37.  */
    ANPUBUFFER_TYPE_CACHE,
    /** Introduced in API 37.  */
    ANPUBUFFER_TYPE_AUXILIARY,
} ANpuBuffer_Type;

/** Opaque type for an NPU buffer allocation request. */
struct ANpuManager_AllocRequest;
typedef struct ANpuManager_AllocRequest ANpuManager_AllocRequest;

/**
 * Callback function type when allocation and load is done.
 *
 * The callback is invoked in response to ANpuManager_allocAsync(). Even when
 * the request has `ANpuManager_AllocRequest_setFileSegmentToLoad()`, indicating
 * that a file is to be loaded into the buffer, this callback is still used to
 * indicate that the load is complete (or failed), not ANpuManager_LoadCallback.
 *
 * The callback may be invoked on any thread, including the current thread
 * immediately inside ANpuManager_allocAsync() if an error is immediately
 * detected.
 *
 * \param cookie The user cookie previously set by
 *          ANpuManager_AllocRequest_setCookie(), or NULL if not set.
 *
 *          The cookie is borrowed, i.e. the user does not own the cookie and must not
 *          free it. See documentation of ANpuManager_AllocRequest_setCookie() for details.
 *
 *          The value of cookie is the one stored in the ANpuManager_AllocRequest at the time
 *          when ANpuManager_allocAsync() is called. Subsequent changes to the cookie
 *          in the ANpuManager_AllocRequest object after a given ANpuManager_allocAsync() is called
 *          has no effect on the callbacks generated from the given ANpuManager_allocAsync() call.
 *
 *          The callback may be called from any thread. The user is responsible for
 *          accessing the cookie in a thread-safe manner.
 * \param errorNum 0 if successful, or an errno on error.
 * \param buf The buffer on success, or NULL on error.
 *
 *          On success, buf must be
 *          explicitly freed by calling ANpuBuffer_free(). This is the case even if
 *          the buffer is preempted by NpuManagerService.
 *
 *          On error, the user must not call ANpuBuffer_free() with NULL.
 */
typedef void (*ANpuManager_AllocCallback)(void* cookie, int errorNum,
                                          ANpuBuffer* buf);

/**
 * Callback function type for buffer preemption.
 *
 * NpuManager calls this function when it needs to forcefully deallocate the
 * buffer. After this callback is invoked, any subsequent attempts to map the
 * buffer are expected to fail.
 *
 * Even if preempted, the buffer must still be explicitly freed by calling
 * ANpuBuffer_free() to clean up remaining resources.
 *
 * Note: On race conditions, the preemption callback may be invoked after the
 *       caller has already freed the buffer.
 *
 * This callback will not be invoked while the application has the buffer
 * mapped.
 *
 * The cookie is borrowed, i.e. the user does not own the cookie and must not
 * free it. See documentation of ANpuManager_AllocRequest_setCookie() for details.
 *
 * The callback may be called from any thread. The user is responsible for
 * accessing the cookie in a thread-safe manner.
 *
 * \param cookie The user cookie previously set by
 *        ANpuManager_AllocRequest_setCookie(), or NULL if not set.
 */
typedef void (*ANpuManager_PreemptCallback)(void* cookie);

/**
 * Callback function type for buffer load.
 *
 * NpuManager calls this function when the buffer load is done or has encountered an error.
 *
 * This callback is invoked in response to ANpuBuffer_loadAsync(), NOT to ANpuManager_allocAsync().
 *
 * \param cookie The user cookie previously set by
 *        ANpuManager_AllocRequest_setCookie(), or NULL if not set.
 * \param errorNum 0 if successful, or an errno on error.
 * \param buf The buffer. This is the same buffer passed to ANpuBuffer_loadAsync(), even if
 *        loading fails.
 */
typedef void (*ANpuManager_LoadCallback)(void* cookie, int errorNum,
                                         ANpuBuffer* buf);

/**
 * Callback function type to delete the user cookie.
 *
 * The deleter may be called from any thread. The user is responsible for
 * deleting the cookie or decrementing the associated reference counts in a thread-safe
 * manner.
 *
 * \param cookie The user cookie previously set by ANpuManager_AllocRequest_setCookie().
 *               This may be NULL if the provided cookie value is NULL.
 */
typedef void (*ANpuManager_CookieDeleter)(void* cookie);

/**
 * Creates a new allocation request. Fields are initialized to a default state.
 *
 * \return A new allocation request.
 */
ANpuManager_AllocRequest* ANpuManager_AllocRequest_create() __INTRODUCED_IN(37);

/**
 * Destroys an allocation request.
 *
 * \param request The allocation request to destroy. If NULL, nothing happens.
 */
void ANpuManager_AllocRequest_free(ANpuManager_AllocRequest* request) __INTRODUCED_IN(37);

/**
 * Sets the user cookie for an allocation request.
 *
 * The user may use this cookie to identify the request. It is not dereferenced
 * directly by the implementation of the NDK library.
 *
 * # Ownership of cookie
 *
 * This donates the ownership of the cookie to ANpuManager. In other words,
 * ANpuManager will be responsible for freeing the cookie with the provided
 * deleter function.
 *
 * This assumes the caller owns the cookie before calling this function, and
 * does not own the cookie after calling this function.
 *
 * In particular, to use the same cookie in multiple
 * ANpuManager_AllocRequest objects, or in OnPreempt() to reuse the cookie in a
 * new ANpuManager_AllocRequest object, reference count the cookie, and:
 *
 * - Before calling setCookie(), increment the reference count by 1.
 * - In the deleter function, decrement the reference count by 1.
 *
 * # Calling the deleter function
 *
 * When ANpuManager decides to free the cookie:
 * - If cookieDeleter is not NULL, it will be called with the cookie value.
 *   This will happen even if the cookie is NULL. In this case, the deleter
 *   must be able to handle NULL gracefully.
 * - If the cookieDeleter is NULL, nothing will happen, even when the cookie
 *   is not NULL. This is useful if the user stores an arbitrary 64-bit integer
 *   value in the cookie (so it is not a real pointer.) However, if the cookie
 *   points to a heap object, it is strongly recommended to set the deleter
 *   so ANpuManager handles its lifetime properly and reduce UAF bugs.
 *
 * # Other semantics of setCookie()
 *
 * When setCookie() is called multiple times, the previous cookie will be
 * deleted with the previous deleter function (if set) before the new cookie and
 * the new deleter function are set.
 *
 * To clear the cookie, set both cookie and cookieDeleter to NULL.
 *
 * If never called, the default cookie and cookieDeleter are NULL.
 *
 * The deleter may be called from any thread. The user is responsible for
 * deleting the cookie or decrementing the associated reference counts in a thread-safe
 * manner.
 *
 * # Callbacks
 *
 * The existing onAlloc and onPreempt callbacks must be able to handle the new cookie value
 * after setCookie() is called. If not, modify the callbacks accordingly before sending them using
 * ANpuManager_allocAsync().
 *
 * \param request The allocation request.
 * \param cookie The user cookie to be owned by ANpuManager.
 * \param cookieDeleter The deleter function to be called when ANpuManager
 *           is done with the cookie.
 */
void ANpuManager_AllocRequest_setCookie(ANpuManager_AllocRequest* request,
                                        void* cookie,
                                        ANpuManager_CookieDeleter cookieDeleter)
        __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Sets the device number for an allocation request.
 *
 * An identifier for the NPU that is involved with the work. The identifiers
 * are vendor-specific and opaque to the ANpuManager.
 *
 * The default value is a negative value, which is invalid. Hence, this must be
 * with a valid non-negative device number before being sent to
 * NpuManagerService. Otherwise, the request is responded with errorNum set to
 * EINVAL.
 *
 * \param request The allocation request.
 * \param deviceNumber The device number.
 */
void ANpuManager_AllocRequest_setDeviceNumber(ANpuManager_AllocRequest* request,
                                              int32_t deviceNumber) __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Sets the purpose of the buffer for an allocation request.
 *
 * The default value is ANPUBUFFER_TYPE_UNKNOWN, which is invalid. Hence, this
 * must be set with a valid buffer type before being sent to
 * NpuManagerService. Otherwise, the request is responded with errorNum set to
 * EINVAL.
 *
 * \param request The allocation request.
 * \param bufferType The buffer type.
 */
void ANpuManager_AllocRequest_setBufferType(ANpuManager_AllocRequest* request,
                                            ANpuBuffer_Type bufferType) __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Sets the size of the buffer in bytes for an allocation request.
 *
 * If never called, the default value is 0.
 *
 * \param request The allocation request.
 * \param size The size of the buffer.
 */
void ANpuManager_AllocRequest_setSize(ANpuManager_AllocRequest* request, int64_t size)
        __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Sets the buffer priority for an allocation request.
 *
 * This is the relative priority of the buffer within the app.
 *
 * The value must be within the range
 * [ANPUBUFFER_PRIORITY_MIN, ANPUBUFFER_PRIORITY_MAX], inclusive.
 *
 * If never called, the default value is ANPUBUFFER_PRIORITY_DEFAULT.
 *
 * \param request The allocation request.
 * \param bufferPriority The buffer priority.
 */
void ANpuManager_AllocRequest_setBufferPriority(ANpuManager_AllocRequest* request,
                                                int32_t bufferPriority) __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Sets the file segment to load for an allocation request.
 *
 * Ownership: The ANpuManager_AllocRequest object takes ownership of the provided file descriptor.
 * The caller must not close it manually.
 *
 * \param request The allocation request.
 * \param fdToOwn The file descriptor of the file to load. Must be a valid file
 *           descriptor, or -1 to ask NpuManager to not load any file. Default
 *           value is -1.
 *
 *           The ownership of the fd is transferred to ANpuManager.
 * \param fileOffset The offset of the file segment to load, starting from the beginning of the
 *           file. Ignored if fdToOwn is -1.
 * \param segmentLength The length of the file segment to load. Must be non-negative. Ignored if
 *           fdToOwn is -1.
 * \param bufferOffset The offset in the buffer to start loading to. Must be non-negative. Ignored
 *           if fdToOwn is -1.
 */
void ANpuManager_AllocRequest_setFileSegmentToLoad(ANpuManager_AllocRequest* request,
                                                   int fdToOwn, int64_t fileOffset,
                                                   int64_t segmentLength, int64_t bufferOffset)
        __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Sets the protection flags for the buffer to be allocated.
 *
 * Note: This specifies the protection flags for the buffer, not the flags for the mmap call.
 * The flags for the mmap call is passed via ANpuBuffer_map().
 *
 * If never called, the default value is PROT_READ.
 *
 * After the buffer is allocated, ANpuBuffer_map() may only be called with |prot| to be a subset of
 * the value set by this function. If not, ANpuBuffer_map() fails and returns MAP_FAILED.
 *
 * \param request The allocation request.
 * \param prot The protection flags. Either PROT_NONE, or the bitwise OR of one or more of
 *        PROT_READ, PROT_WRITE, PROT_EXEC.
 */
void ANpuManager_AllocRequest_setProtectionFlags(ANpuManager_AllocRequest* request,
                                                 int32_t prot) __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Sets the allocation callback for an allocation request.
 *
 * Callback function to be invoked when allocation and load is finished or
 * has encountered an error.
 *
 * setOnAlloc() must be called with a non-NULL value. Otherwise, the process will crash.
 *
 * setOnAlloc() must be called before calling ANpuManager_allocAsync(). Otherwise, the
 * process will crash.
 *
 * See documentation of ANpuManager_AllocCallback for details about the arguments
 * when the callback is invoked.
 *
 * The new callback must be able to handle any existing cookie value set by
 * setCookie(), or NULL if setCookie() is never called. If not, modify the cookie or the callback
 * accordingly before sending them using ANpuManager_allocAsync().
 *
 * \param request The allocation request.
 *     Must not be NULL; otherwise the process will crash.
 * \param onAlloc The allocation callback.
 */
void ANpuManager_AllocRequest_setOnAlloc(ANpuManager_AllocRequest* request,
                                         ANpuManager_AllocCallback onAlloc)
        __INTRODUCED_IN(37) __attribute__((nonnull(1,2)));

/**
 * Sets the preemption callback for an allocation request.
 *
 * Callback function to be invoked when NpuManager needs to forcefully
 * deallocate the buffer.
 *
 * This may be set to NULL, in which case NpuManager will not invoke any
 * callback when preempting the buffer. Default value is NULL.
 *
 * When the buffer is preempted, any subsequent attempt to map the buffer will
 * fail with errno set to ENOENT.
 *
 * See documentation of ANpuManager_PreemptCallback for details about the
 * arguments when the callback is invoked.
 *
 * The new callback must be able to handle any existing cookie value set by
 * setCookie(), or NULL if setCookie() is never called. If not, modify the cookie or the callback
 * accordingly before sending them using ANpuManager_allocAsync().
 *
 * \param request The allocation request.
 * \param onPreempt The preemption callback.
 */
void ANpuManager_AllocRequest_setOnPreempt(ANpuManager_AllocRequest* request,
                                           ANpuManager_PreemptCallback onPreempt)
        __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Tests if the provided requests are supported or not.
 *
 * If a request is supported, ANpuManager_allocAsync() may still respond
 * onAlloc with a failure due to
 * other reasons, e.g., no memory. If a request is not supported,
 * ANpuManager_allocAsync() guarantees to respond onAlloc with a failure.
 *
 * The following fields in the requests are ignored:
 * - cookie
 * - onAlloc
 * - onPreempt
 *
 * \param requests The allocation requests to test.
 *
 *
 *                 The list must not be modified during the execution of
 *                 ANpuManager_isSupported(). Otherwise, the behavior is undefined.
 *                 It is okay to modify the list after ANpuManager_isSupported()
 *                 returns, even before the onAlloc callback is invoked.
 *
 *                 The elements of the list must not be modified or freed during the
 *                 execution of ANpuManager_isSupported(), e.g. via the
 *                 ANpuManager_AllocRequest_setXXX() functions and
 *                 ANpuManager_AllocRequest_free(). Otherwise, the behavior
 *                 is undefined. It is okay to modify or free the elements
 *                 after ANpuManager_isSupported() returns, even before the
 *                 onAlloc callback is invoked.
 *
 * \param requestsLen The length of the requests list.
 * \param outIsSupported The output boolean array to store the support status
 *                 of each request. It must be valid for at least requestsLen
 *                 elements for ANpuManager_isSupported() to write to.
 *
 *                 The caller must not simultaneously write to this array
 *                 during the execution of ANpuManager_isSupported().
 *                 Otherwise, the behavior is undefined.
 * \return 0 on successfully testing whether the requests are supported or not
 *         (even if some or all of them are not supported); results are stored
 *         in outIsSupported. Otherwise, if there is an error, returns -1 with
 *         with errno set, and results in outIsSupported should be ignored
 *         by the caller.
 */
int ANpuManager_isSupported(ANpuManager_AllocRequest* const* requests,
                            size_t requestsLen, bool* outIsSupported) __INTRODUCED_IN(37) __attribute__((nonnull(1,3)));

/**
 * Asynchronously allocates multiple buffers.
 *
 * Each ANpuBuffer*, after being received from the onAlloc callback, must be
 * explicitly freed by calling ANpuBuffer_free(). This is the case even if
 * the buffer is preempted by NpuManagerService.
 *
 * Available since API level 37.
 *
 * \param requests A list of requests, each describing a buffer to allocate.
 *
 *                 ANpuManager does not take ownership of the given request
 *                 objects. The caller is responsible for calling the
 *                 ANpuManager_AllocRequest_free() on them.
 *                 The caller may call ANpuManager_AllocRequest_free()
 *                 right after ANpuManager_allocAsync() is called. The
 *                 caller does not need to wait for the response on the
 *                 onAlloc callback to free the request.
 *
 *                 The onAlloc callback must not be NULL. Otherwise, the process
 *                 will crash.
 *
 *                 A "snapshot" of the requests are taken; in other words, all parameters are
 *                 recorded at the moment ANpuManager_allocAsync() is called. Any subsequent
 *                 modification to the request objects will not be reflected in the allocation
 *                 or in the callbacks. For example, if you call
 *                 ANpuManager_AllocRequest_setCookie() after
 *                 ANpuManager_allocAsync() is called, the old cookie value will be used when
 *                 the onAlloc callback is invoked.
 *
 *                 The list must not be modified during the execution of
 *                 ANpuManager_allocAsync(). Otherwise, the behavior is undefined.
 *                 It is okay to modify the list after ANpuManager_allocAsync()
 *                 returns, even before the onAlloc callback is invoked.
 *
 *                 The elements of the list must not be modified or freed during the
 *                 execution of ANpuManager_allocAsync(), e.g. via the
 *                 ANpuManager_AllocRequest_setXXX() functions and
 *                 ANpuManager_AllocRequest_free(). Otherwise, the behavior
 *                 is undefined. It is okay to modify or free the elements
 *                 after ANpuManager_allocAsync() returns, even before the
 *                 onAlloc callback is invoked.
 *
 * \param requestsLen The length of the requests list.
 */
void ANpuManager_allocAsync(ANpuManager_AllocRequest* const* requests,
                            size_t requestsLen) __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Indicates that the buffers are not needed by the user and can be freed.
 *
 * If there are any existing mappings to the buffer via ANpuBuffer_map(), the mapping will continue
 * to be valid until unmapped even after the buffer is freed. In this case, the associated memory
 * will be freed after all mappings are unmapped.
 *
 * To prevent use-after-free bugs, the caller must not use pointers in \a buffers
 * during or after this call in any of the ANpuBuffer_* functions, except:
 *
 * - ANpuBuffer_unmap() to unmap any existing mappings to the buffer.
 *
 * Even if a buffer is preempted, it must still be explicitly freed by calling
 * ANpuBuffer_free() to clean up remaining resources.
 *
 * Available since API level 37.
 *
 * \param buffers A list of buffers to free. Each item must not be NULL.
 *
 *                 The list must not be modified during the execution of
 *                 ANpuBuffer_free(). Otherwise, the behavior is undefined.
 *
 *                 The elements of the list must not be freed during the
 *                 execution of ANpuBuffer_free() in a separate thread,
 *                 or after the execution of ANpuBuffer_free() in any thread
 *                 (i.e. no double-free).
 *
 * \param buffersLen The length of the buffers list.
 * \return 0 on success, or -1 on error with errno set.
 */
int ANpuBuffer_free(ANpuBuffer* const* buffers, size_t buffersLen)
        __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Maps a buffer into the application's address space.
 *
 * The arguments are similar to mmap().
 *
 * The returned address must be unmapped by calling ANpuBuffer_unmap().
 *
 * Available since API level 37.
 *
 * \param buf The buffer to map.
 * \param addr see mmap().
 * \param length see mmap().
 * \param prot see mmap().
 *           The value must be a subset of the value set by
 *           ANpuManager_AllocRequest_setProtectionFlags(). Otherwise,
 *           ANpuBuffer_map() fails and returns MAP_FAILED.
 * \param flags see mmap().
 * \param offset see mmap().
 * \return The mapped address on success, or MAP_FAILED on error and errno is
 *         set. If the buffer was preempted, errno is set to ENOENT.
 *
 *         There is a small time window between when the buffer is preempted
 *         and when ANpuManager_OnPreempt is called. If the app calls
 *         ANpuBuffer_map() during this time window, it will still get -1 with
 *         errno set to ENOENT, even though when ANpuManager_OnPreempt has not
 *         been called yet.
 */
void* ANpuBuffer_map(ANpuBuffer* buf, void* addr, size_t length,
                              int prot, int flags, off_t offset) __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Unmaps a previously mapped buffer.
 *
 * The arguments are similar to munmap().
 *
 * Available since API level 37.
 *
 * \param buf The buffer to unmap.
 * \param addr see munmap().
 * \param length see munmap().
 * \return 0 on success, or -1 on error with errno set.
 */
int ANpuBuffer_unmap(ANpuBuffer* buf, void* addr, size_t length)
        __INTRODUCED_IN(37) __attribute__((nonnull(1,2)));

/**
 * Sets the priority of the buffer.
 *
 * Available since API level 37.
 *
 * \param buf The buffer to set the priority of.
 * \param newBufferPriority The new priority of the buffer. The value must be
 *           within the range [ANPUBUFFER_PRIORITY_MIN, ANPUBUFFER_PRIORITY_MAX],
 *           inclusive.
 * \return 0 on success, or -1 on error with errno set.
 */
int ANpuBuffer_setPriority(ANpuBuffer* buf, int32_t newBufferPriority) __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Loads a file into the buffer asynchronously.
 *
 * There should not be any existing mapping (via ANpuBuffer_map()) to the buffer. Otherwise,
 * the callback is replied with an error.
 *
 * Available since API level 37.
 *
 * \param buf The buffer to load into.
 * \param fdToOwn The file descriptor of the file to load. Must be a valid file
 *           descriptor. The ownership of the fd is transferred to ANpuManager.
 *
 *           The position of the associated file description is not changed by this function.
 * \param fileOffset The offset of the file segment to load, starting from the beginning of the
 *           file.
 * \param segmentLength The length of the file segment to load. Must be non-negative.
 * \param bufferOffset The offset in the buffer to start loading to. Must be non-negative.
 * \param onLoad The callback to be invoked when loading is finished or has encountered an error.
 *        See documentation of ANpuManager_LoadCallback for details about the arguments
 *        when the callback is invoked.
 *
 *        This must be non-NULL. Otherwise, the process will crash.
 */
void ANpuBuffer_loadAsync(ANpuBuffer* buf, int fdToOwn, int64_t fileOffset,
                          int64_t segmentLength, int64_t bufferOffset,
                          ANpuManager_LoadCallback onLoad) __INTRODUCED_IN(37) __attribute__((nonnull(1,6)));

__END_DECLS

#endif  // ANDROID_NPUMANAGER_BUFFER_H

/** @} */
