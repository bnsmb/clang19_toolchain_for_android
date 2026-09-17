.section .data
msg:    .ascii "Hello, World from an assembler program compiled with clang!\n"
len = . - msg

.section .text
.global _start

_start:
    // write(1, msg, len)
    mov     x8, #64         // syscall number: write = 64 on arm64
    mov     x0, #1          // stdout (fd = 1)
    ldr     x1, =msg        // pointer to message
    mov     x2, #len        // message length
    svc     #0              // syscall

    // exit(0)
    mov     x8, #93         // syscall number: exit = 93 on arm64
    mov     x0, #0          // exit code
    svc     #0              // syscall

