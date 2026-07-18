/*
 * Copyright (C) 2025 The Android Open Source Project
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
 * @addtogroup NativeService
 *
 * ANativeService APIs allow you to implement Services declared as
 * {@code android:nativeService=true} using only native code.
 *
 * Because most NDK APIs rely on the Android Runtime (ART), the APIs available to native services
 * (which may not have the ART loaded inside their processes) are limited to a specific subset.
 * The current set of supported APIs is:
 *
 * - AFont_*
 * - AFontMatcher_*
 * - AIBinder_*
 *   - except AIBinder_fromJavaBinder and AIBinder_toJavaBinder
 * - ALooper_*
 * - ANativeService_*
 * - AParcel_*
 *   - except AParcel_fromJavaParcel
 * - APersistableBundle_*
 * - ASharedMemory_*
 *   - except ASharedMemory_dupFromJava
 * - AStatus_*
 * - ASystemFontIterator_*
 * - ATrace_*
 *
 * @{
 */

/**
 * @file native_service.h
 */

#ifndef ANDROID_NATIVE_SERVICE_H
#define ANDROID_NATIVE_SERVICE_H

#include <sys/cdefs.h>

#include <android/binder_ibinder.h>
#include <stdint.h>

__BEGIN_DECLS

/**
 * An opaque struct representing a native service instance.
 *
 * The framework creates a unique instance of this struct for each service. A handle to this same
 * instance is passed to every callback function of the service.
 *
 * Introduced in API 37.
 */
typedef struct ANativeService ANativeService;

/**
 * The function type signature definition of the entry point function of the service.
 * `service` must be initialized in this function.
 *
 * This function will run on the main thread of the process.
 *
 * Introduced in API 37.
 *
 * \param service {@link ANativeService} associated with the service.
 */
typedef void ANativeService_createFunc(ANativeService* service);

/**
 * The default name of the entry point function. You can specify a different function name through
 * `android.app.PROPERTY_NATIVE_SERVICE_FUNCTION_NAME` property in your manifest.
 *
 * Introduced in API 37.
 */
extern ANativeService_createFunc ANativeService_onCreate;

/**
 * The levels for {@link ANativeService_onTrimMemoryCallback} indicating the context of the trim,
 * giving a hint of the amount of trimming the application may like to perform.
 *
 * Introduced in API 37.
 */
typedef enum ANativeServiceTrimMemoryLevel : int32_t {
    /**
     * The process had been showing a user interface, and is no longer doing so.  Large allocations
     * with the UI should be released at this point to allow memory to be better managed.
     *
     * Introduced in API 37.
     */
    ANATIVE_SERVICE_TRIM_MEMORY_UI_HIDDEN = 20,

    /**
     * The process has gone on to the LRU list.  This is a good opportunity to clean up resources
     * that can efficiently and quickly be re-built if the user returns to the app.
     *
     * Introduced in API 37.
     */
    ANATIVE_SERVICE_TRIM_MEMORY_BACKGROUND = 40,
} ANativeServiceTrimMemoryLevel;

/**
 * The function type signature definition of the "onBind" callback function called when someone is
 * binding to the service, with the given action and data on the intent. This may return NULL if
 * clients cannot bind to the service, or a pointer to a valid AIBinder. If an AIBinder is returned,
 * its ownership is transferred to the system, which is responsible for decrementing the reference
 * count of the instance.
 *
 * This callback function will run on the main thread of the process.
 *
 * Introduced in API 37.
 *
 * \param service {@link ANativeService} associated with the service.
 * \param bindToken A token representing this service binding. The same token is passed to onUnbind
 * and onRebind callbacks to identify which binding triggered the callback.
 * \param action The action specified in the intent passed to `Context.bindService` encoded as UTF-8
 * or null if not specified.
 * \param data The data specified in the intent passed to `Context.bindService`. This is an encoded
 * URI based on RFC 2396 using UTF-8 or null if not specified.
 * \return an AIBinder pointer through which clients can call on to the service. Ownership is
 * transferred to the system.
 */
typedef AIBinder* (*ANativeService_onBindCallback)(ANativeService* service,
                                                             uint64_t bindToken,
                                                             char const* action,
                                                             char const* data);

/**
 * The function type signature definition of the "onUnbind" callback function called when all
 * clients have disconnected from a particular interface published by the service. Return true if
 * you would like to have the service's onRebind() method later called when new clients bind to it.
 *
 * This callback function will run on the main thread of the process.
 *
 * Introduced in API 37.
 *
 * \param service {@link ANativeService} associated with the service.
 * \param bindToken A token representing a service binding, which allows the callback to identify
 * which binding triggered it.
 * \return true if you would like to have the service's {@link ANativeService_onRebindCallback}
 * callback later called when new clients bind to it, otherwise false.
 */
typedef bool (*ANativeService_onUnbindCallback)(ANativeService* service,
                                                uint64_t bindToken);

/**
 * The function type signature definition of the "onRebind" callback function called when someone is
 * rebinding to the service. This callback is called only when onUnbind() returned true before.
 *
 * This callback function will run on the main thread of the process.
 *
 * Introduced in API 37.
 *
 * \param service {@link ANativeService} associated with the service.
 * \param bindToken A token representing a service binding, which allows the callback to identify
 * which binding triggered it.
 */
typedef void (*ANativeService_onRebindCallback)(ANativeService* service,
                                                uint64_t bindToken);

/**
 * The function type signature definition of the "onDestroy" callback function called when the
 * service is being destroyed.
 *
 * This callback function will run on the main thread of the process.
 *
 * Introduced in API 37.
 *
 * \param service {@link ANativeService} associated with the service.
 */
typedef void (*ANativeService_onDestroyCallback)(ANativeService* service);

/**
 * The function type signature definition of the "onTrimMemory" callback function called when the
 * operating system has determined that it is a good time for a process to trim unneeded memory from
 * its process.
 *
 * You should never compare to exact values of the level, since new intermediate values may be added
 * -- you will typically want to compare if the value is greater or equal to a level you are
 * interested in.
 *
 * This callback function will run on the main thread of the process.
 *
 * Introduced in API 37.
 *
 * \param service {@link ANativeService} associated with the service.
 * \param level {@link ANativeServiceTrimMemoryLevel} indicating the context of the trim, giving a
 * hint of the amount of trimming the application may like to perform.
 */
typedef void (*ANativeService_onTrimMemoryCallback)(ANativeService* service,
                                                    ANativeServiceTrimMemoryLevel level);

/**
 * Sets the "onBind" callback function for the service.
 *
 * Introduced in API 37.
 *
 * \param service {@link ANativeService} associated with the service.
 * \param callback A pointer to an implementation of {@link ANativeService_onBindCallback}.
 */
void ANativeService_setOnBindCallback(ANativeService* service,
                                      ANativeService_onBindCallback callback)
        __INTRODUCED_IN(37) __attribute__((nonnull(1,2)));

/**
 * Sets the "onUnbind" callback function for the service.
 *
 * If NULL is specified as the callback, then the system runs the default implementation which does
 * nothing and returns false.
 *
 * Introduced in API 37.
 *
 * \param service {@link ANativeService} associated with the service.
 * \param callback A pointer to an implementation of {@link ANativeService_onUnbindCallback}.
 */
void ANativeService_setOnUnbindCallback(ANativeService* service,
                                        ANativeService_onUnbindCallback callback)
        __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Sets the "onRebind" callback function for the service.
 *
 * If NULL is specified as the callback, then the system skips calling the callback when the
 * event happens.
 *
 * Introduced in API 37.
 *
 * \param service {@link ANativeService} associated with the service.
 * \param callback A pointer to an implementation {@link ANativeService_onRebindCallback}.
 */
void ANativeService_setOnRebindCallback(ANativeService* service,
                                        ANativeService_onRebindCallback callback)
        __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Sets the "onDestroy" callback function for the service.
 *
 * If NULL is specified as the callback, then the system skips calling the callback when the
 * event happens.
 *
 * Introduced in API 37.
 *
 * \param service {@link ANativeService} associated with the service.
 * \param callback A pointer to an implementation of {@link ANativeService_onDestroyCallback}.
 */
void ANativeService_setOnDestroyCallback(ANativeService* service,
                                         ANativeService_onDestroyCallback callback)
        __INTRODUCED_IN(37) __attribute__((nonnull(1)));

/**
 * Sets the "onTrimMemory" callback function for the service.
 *
 * If NULL is specified as the callback, then the system skips calling the callback when the
 * event happens.
 *
 * Introduced in API 37.
 *
 * \param service {@link ANativeService} associated with the service.
 * \param callback A pointer to an implementation of {@link ANativeService_onTrimMemoryCallback}.
 */
void ANativeService_setOnTrimMemoryCallback(ANativeService* service,
                                            ANativeService_onTrimMemoryCallback callback)
        __INTRODUCED_IN(37) __attribute__((nonnull(1)));

__END_DECLS

#endif // ANDROID_NATIVE_SERVICE_H

/** @} */
