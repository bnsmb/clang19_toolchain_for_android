//
// include file with standard definitions missing in the libc from Android
//
// Please note that you must remove the definitions for functions that already exist in the source code from this include file.
// If not there will be error messages like this:
//
//    command.c:(.text+0x348): multiple definition of `catclose'
//    array.o:array.c:(.text+0x348): first defined here
//
// History
//  29.12.2024
//    initial release
//  22.01.2025 
//    added the function nl_langinfo
//  11.04.2025
//    added the functions getpwent and endpwent
//    the definitions for nl_langinfo and nl_catd now also can be used in C programs
//
// This file defines
//   __GNUC_PREREQ
//   quad_t
//   u_quad_t
//   short
//
// This file defines the functions
//   strverscmp
//   versionsort
//   getdtablesize
//   index
//   rindex
//   catopen
//   catgets
//   catclose
//   nl_langinfo
//   getpwent
//   endpwent
//

#ifndef ADD_MISSING_DEFINITIONS_H

#define ADD_MISSING_DEFINITIONS_H

// --------------------------------------------------------------------
//
#ifndef __GNUC_PREREQ
#define __GNUC_PREREQ(maj, min) ((__GNUC__ > (maj)) || (__GNUC__ == (maj) && __GNUC_MINOR__ >= (min)))
#endif


// --------------------------------------------------------------------
//
#ifndef quad_t

#include <stdint.h>

typedef int64_t quad_t;

#endif

// --------------------------------------------------------------------
//
#ifndef u_quad_t

#include <stdint.h>

typedef uint64_t u_quad_t;

#endif

// --------------------------------------------------------------------
//
#ifndef short

typedef unsigned short ushort;

#endif


// --------------------------------------------------------------------
//
#ifndef strverscmp

#include <dirent.h>

int strverscmp(const char *l0, const char *r0)
{
	const unsigned char *l = (const void *)l0;
	const unsigned char *r = (const void *)r0;
	size_t i, dp, j;
	int z = 1;

	/* Find maximal matching prefix and track its maximal digit
	 * suffix and whether those digits are all zeros. */
	for (dp=i=0; l[i]==r[i]; i++) {
		int c = l[i];
		if (!c) return 0;
		if (!isdigit(c)) dp=i+1, z=1;
		else if (c!='0') z=0;
	}

	if (l[dp]!='0' && r[dp]!='0') {
		/* If we're not looking at a digit sequence that began
		 * with a zero, longest digit string is greater. */
		for (j=i; isdigit(l[j]); j++)
			if (!isdigit(r[j])) return 1;
		if (isdigit(r[j])) return -1;
	} else if (z && dp<i && (isdigit(l[i]) || isdigit(r[i]))) {
		/* Otherwise, if common prefix of digit sequence is
		 * all zeros, digits order less than non-digits. */
		return (unsigned char)(l[i]-'0') - (unsigned char)(r[i]-'0');
	}

	return l[i] - r[i];
}

#endif

// --------------------------------------------------------------------
//
#ifndef versionsort

static int versionsort(const struct dirent **a, const struct dirent **b)
{
	return strverscmp((*a)->d_name, (*b)->d_name);
}

#endif


// --------------------------------------------------------------------
//
#ifndef getdtablesize

#include <unistd.h>
#include <sys/resource.h>

int getdtablesize() {
    // Zuerst sysconf versuchen
    long max_fds = sysconf(_SC_OPEN_MAX);
    if (max_fds > 0) {
        return (int)max_fds;
    }

    // Fallback: getrlimit verwenden
    struct rlimit limit;
    if (getrlimit(RLIMIT_NOFILE, &limit) == 0) {
        return (int)limit.rlim_cur;
    }

    // Notlösung: Standardwert
    return 1024;
}

#endif

// --------------------------------------------------------------------
//
#ifndef index

#include <string.h>

char *index(const char *s, int c) {
    return strchr(s, c);
}

#endif

// --------------------------------------------------------------------
//
#ifndef rindex

#include <string.h>

char *rindex(const char *s, int c) {
    return strrchr(s, c);
}

#endif

// --------------------------------------------------------------------

#ifdef __ANDROID__
typedef void* nl_catd;


#ifndef __cplusplus
#define nullptr ((void*)0)
#endif


nl_catd catopen(const char *name, int flag) {
    return nullptr;
}

char* catgets(nl_catd catalog, int set_number, int message_number, const char *default_message) {
    return (char *)default_message;
}

int catclose(nl_catd catalog) {
    return 0;
}
#endif

// --------------------------------------------------------------------

#ifndef nl_langinfo

#ifndef CODESET
#define CODESET 0
#endif

const char* nl_langinfo(int item) {
    switch (item) {
        case CODESET:
            return "UTF-8";
        // Weitere Dummy-Werte, falls benötigt
        case 2: // Beispiel für ein anderes Element
            return "en_US";
        default:
            return "unknown"; // Fallback für nicht unterstützte Items
    }
}

#endif


// --------------------------------------------------------------------

#ifndef getpwent

#include <pwd.h>
#include <stddef.h>

// Dummy getpwent – always return NULL (no user)
struct passwd *getpwent(void) {
    return NULL;
}

#endif

// --------------------------------------------------------------------

#ifndef endpwent

#include <pwd.h>
#include <stddef.h>

// Dummy endpwent – do nothing
void endpwent(void) {
    // no-op
}

#endif


// --------------------------------------------------------------------

#endif  /* ADD_MISSING_DEFINITIONS_H */

// --------------------------------------------------------------------
//
