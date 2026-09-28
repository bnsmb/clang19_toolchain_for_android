#ifndef ANDROID_AFFINITY_FIX_H
#define ANDROID_AFFINITY_FIX_H

#ifdef __ANDROID__

#include <stddef.h>
#include <string.h>
#include <sys/types.h>
#include <sys/prctl.h>
#include <pthread.h>

/* ====================================================================
 * CPU_SET type and macros
 * ====================================================================
 *
 * Bionic supports cpu_set_t, but the NDK removes the definitions from
 * sched.h. The definitions below are taken from the Bionic source and
 * from official NDK workarounds.
 */
#define CPU_SETSIZE 1024
#define __NCPUBITS  (8 * sizeof (unsigned long))

typedef struct {
    unsigned long __bits[CPU_SETSIZE / __NCPUBITS];
} cpu_set_t;

/* CPU_SET: mark a CPU in the set */
#define CPU_SET(cpu, cpusetp) \
    ((cpusetp)->__bits[(cpu) / __NCPUBITS] |= (1UL << ((cpu) % __NCPUBITS)))

/* CPU_ZERO: clear the set */
#define CPU_ZERO(cpusetp) \
    memset((cpusetp), 0, sizeof(cpu_set_t))

/* CPU_ISSET: check whether a CPU is set in the set */
static inline int CPU_ISSET(int cpu, const cpu_set_t *set) {
    return (set->__bits[cpu / __NCPUBITS] >> (cpu % __NCPUBITS)) & 1UL;
}

/* CPU_COUNT: count the number of CPUs set in the set */
static inline int CPU_COUNT(const cpu_set_t *set) {
    int count = 0;
    int i;
    for (i = 0; i < (CPU_SETSIZE / __NCPUBITS); i++) {
        count += __builtin_popcountl(set->__bits[i]);
    }
    return count;
}

/* ====================================================================
 * Affinity functions
 * ====================================================================
 *
 * These functions exist at runtime in Android's libc (Bionic), but the
 * NDK does not declare them in sched.h.
 */
extern int sched_getaffinity(pid_t pid, size_t cpusetsize, cpu_set_t *cpuset);
extern int sched_setaffinity(pid_t pid, size_t cpusetsize, const cpu_set_t *cpuset);
extern int sched_getcpu(void);

/* ====================================================================
 * pthread_getname_np fallback
 * ====================================================================
 *
 * The function was introduced in Bionic with API 26 and is not declared
 * in older NDK headers. At runtime it is available from API 26 onwards;
 * for older API levels, prctl(PR_GET_NAME) is used instead.
 *
 * Note: calling prctl(PR_GET_NAME) fills the buffer with a
 * null-terminated string of at most 16 bytes.
 */
#ifndef HAVE_PTHREAD_GETNAME_NP
static inline int pthread_getname_np(pthread_t thread, char *name, size_t len) {
    (void)thread;
    if (name == NULL || len == 0) {
        return -1;
    }
    return prctl(PR_GET_NAME, (unsigned long)name, (unsigned long)len, 0, 0);
}
#endif

#endif /* __ANDROID__ */
#endif /* ANDROID_AFFINITY_FIX_H */

