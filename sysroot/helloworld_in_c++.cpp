#include <iostream>  // include the input-output stream library

int main() {
    std::cout << "Hello, World from a C++ program!" << std::endl;  // output the message to the console


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

    std::cout << "Compiler version: " << __VERSION__ << std::endl;

   return 0;  // indicate successful completion of the program

}

