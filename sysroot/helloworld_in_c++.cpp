#include <iostream>
#include <android/api-level.h>
#include <android/ndk-version.h>

int main() {
    std::cout << "Hello, World from a C++ program!" << std::endl;

#ifdef __clang__
    std::cout << "Compiled with Clang "
              << __clang_major__ << "."
              << __clang_minor__ << "."
              << __clang_patchlevel__ << std::endl;
#elif defined(__GNUC__)
    std::cout << "Compiled with GCC "
              << __GNUC__ << "."
              << __GNUC_MINOR__ << "."
              << __GNUC_PATCHLEVEL__ << std::endl;
#else
    std::cout << "Compiled with an unknown compiler" << std::endl;
#endif

    std::cout << "Compiler version string: " << __VERSION__ << std::endl;

    // NDK Version
#ifdef __NDK_MAJOR__
    std::cout << "NDK Version: r" << __NDK_MAJOR__;
    #ifdef __NDK_MINOR__
        std::cout << "." << __NDK_MINOR__;
    #endif
    #ifdef __NDK_BETA__
        if (__NDK_BETA__ > 0) std::cout << " beta" << __NDK_BETA__;
    #endif
    std::cout << std::endl;
#else
    std::cout << "NDK Version: unknown" << std::endl;
#endif

    // Target API Level (kann undefiniert sein!)
#ifdef __ANDROID_API__
    std::cout << "Target API Level (compiled for): " << __ANDROID_API__ << std::endl;
#else
    std::cout << "Target API Level: not defined (using default/latest)" << std::endl;
#endif

    // Laufzeit-API Level des Geräts
    int deviceApiLevel = android_get_device_api_level();
    if (deviceApiLevel > 0) {
        std::cout << "Device API Level (runtime): " << deviceApiLevel << std::endl;
    } else {
        std::cout << "Device API Level: unknown (error)" << std::endl;
    }

    return 0;
}
