#include <stdio.h>
#include <android/api-level.h>
#include <android/ndk-version.h>

int main() {
    printf("Hello, World from a C program!\n");

#ifdef __clang__
    printf("Compiled with Clang %d.%d.%d\n", __clang_major__, __clang_minor__, __clang_patchlevel__);
#elif defined(__GNUC__)
    printf("Compiled with GCC %d.%d.%d\n", __GNUC__, __GNUC_MINOR__, __GNUC_PATCHLEVEL__);
#else
    printf("Compiled with an unknown compiler\n");
#endif

    printf("Compiler version string: %s\n", __VERSION__);

    // NDK Version
#ifdef __NDK_MAJOR__
    printf("NDK Version: r%d", __NDK_MAJOR__);
    #ifdef __NDK_MINOR__
        printf(".%d", __NDK_MINOR__);
    #endif
    #ifdef __NDK_BETA__
        if (__NDK_BETA__ > 0) printf(" beta%d", __NDK_BETA__);
    #endif
    printf("\n");
#else
    printf("NDK Version: unknown\n");
#endif

    // Target API Level (kann undefiniert sein!)
#ifdef __ANDROID_API__
    printf("Target API Level (compiled for): %d\n", __ANDROID_API__);
#else
    printf("Target API Level: not defined (using default/latest)\n");
#endif

    // Laufzeit-API Level des Geräts
    int deviceApiLevel = android_get_device_api_level();
    if (deviceApiLevel > 0) {
        printf("Device API Level (runtime): %d\n", deviceApiLevel);
    } else {
        printf("Device API Level: unknown (error)\n");
    }

    return 0;
}
