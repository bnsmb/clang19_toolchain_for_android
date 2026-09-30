/*
 * zramctl - control compressed block devices in RAM
 *
 * Copyright (c) 2014 Timofey Titovets <Nefelim4ag@gmail.com>
 * Copyright (C) 2014 Karel Zak <kzak@redhat.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it would be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <https://gnu.org/licenses/>.
 *
 * ---------------------------------------------------------------------------
 * Android adaptation notes
 * ---------------------------------------------------------------------------
 * This version of zramctl has been adapted for Android (tested on /e/ OS).
 *
 *   - zram block devices live under /dev/block/ instead of /dev/.
 *   - sysfs attributes for zram live under /sys/block/zramN/ (not under
 *     /sys/class/block/zramN/, which is only a symlink on Android).
 *   - sysfs files on Android kernels often report st_size == 0 via fstat(),
 *     which breaks the generic util-linux helpers ul_path_read_u64() and
 *     ul_path_read_string().  Those attributes are therefore read directly
 *     with open()/read() and parsed after trimming trailing whitespace.
 *   - zramctl is sometimes invoked via `su` on Android; the debug output
 *     is written to stderr so it can be redirected independently of stdout.
 *
 * Debug output is controlled at runtime via the environment variable
 * ZRAMCTL_DEBUG.  Accepted values (case-insensitive):
 *
 *   ZRAMCTL_DEBUG=0        debug disabled (default)
 *   ZRAMCTL_DEBUG=1        basic debug messages
 *   ZRAMCTL_DEBUG=verbose  verbose debug messages (same as 1 plus extra)
 *
 * Example:
 *   ZRAMCTL_DEBUG=1 zramctl
 *   ZRAMCTL_DEBUG=verbose zramctl /dev/block/zram0
 */

#include <getopt.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stdio.h>
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <ctype.h>
#include <sys/file.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>

#include <libsmartcols.h>

#if HAVE_DECL_SD_DEVICE_NEW_FROM_SYSPATH
#include <systemd/sd-device.h>
#endif

#include "c.h"
#include "cctype.h"
#include "nls.h"
#include "closestream.h"
#include "strutils.h"
#include "xalloc.h"
#include "sysfs.h"
#include "optutils.h"
#include "ismounted.h"
#include "strv.h"
#include "path.h"
#include "pathnames.h"

/*
 * Android: zram devices live under /dev/block, not /dev.
 * We deliberately undef the value from pathnames.h so that a future
 * change in util-linux does not silently break the Android path.
 */
#undef _PATH_DEV
#define _PATH_DEV "/dev/block"

/*
 * Android: sysfs attributes live under /sys/block/<name>/.
 * The generic sysfs_devname_to_devno() helper cannot resolve "zramN"
 * on all Android kernels, so we build the sysfs path ourselves.
 */
#define ZRAMCTL_SYSFS_BLOCK "/sys/block"

/*
 * Version string.  The upstream version is taken from PACKAGE_VERSION
 * (provided by config.h), and we append an Android marker so it is
 * obvious in bug reports which build is in use.
 */
#ifndef PACKAGE_VERSION
# define PACKAGE_VERSION "unknown"
#endif
#define ZRAMCTL_ANDROID_TAG "android-1"

/*
 * Runtime debug switch.  Controlled via the ZRAMCTL_DEBUG environment
 * variable so that no recompilation is required to gather diagnostics
 * on a running device.
 *
 *   0 / unset / empty  -> no debug output
 *   1 / yes / true     -> basic debug output
 *   verbose / 2        -> verbose debug output (extra detail)
 */
static int zramctl_debug_level = 0;

enum {
    ZRAMCTL_DEBUG_NONE = 0,
    ZRAMCTL_DEBUG_BASIC = 1,
    ZRAMCTL_DEBUG_VERBOSE = 2
};

/*
 * Initialise the debug level from the environment.  Called once from
 * main() before any other code path that might emit debug output.
 */
static void zramctl_init_debug(void)
{
    const char *env = getenv("ZRAMCTL_DEBUG");

    if (!env || !*env)
        return;

    if (!strcasecmp(env, "0") ||
        !strcasecmp(env, "no") ||
        !strcasecmp(env, "false") ||
        !strcasecmp(env, "off"))
        zramctl_debug_level = ZRAMCTL_DEBUG_NONE;
    else if (!strcasecmp(env, "verbose") ||
             !strcasecmp(env, "2") ||
             !strcasecmp(env, "all"))
        zramctl_debug_level = ZRAMCTL_DEBUG_VERBOSE;
    else
        zramctl_debug_level = ZRAMCTL_DEBUG_BASIC;

    fprintf(stderr, "zramctl[debug]: debug level set to %d "
                    "(source: ZRAMCTL_DEBUG=\"%s\")\n",
            zramctl_debug_level, env);
}

/*
 * Debug print helpers.  All output goes to stderr with a consistent
 * prefix so that it can be grepped out of mixed output and so that an
 * uninvolved reader can tell which tool produced the message.
 *
 * The "function" argument is the C function name; this makes it much
 * easier to follow the control flow in a log file.
 */
#define DBG_BASIC(fmt, ...)                                                  \
    do {                                                                     \
        if (zramctl_debug_level >= ZRAMCTL_DEBUG_BASIC)                      \
            fprintf(stderr, "zramctl[debug]: %s: " fmt "\n",                 \
                    __func__, ##__VA_ARGS__);                                \
    } while (0)

#define DBG_VERBOSE(fmt, ...)                                                \
    do {                                                                     \
        if (zramctl_debug_level >= ZRAMCTL_DEBUG_VERBOSE)                    \
            fprintf(stderr, "zramctl[debug]: %s: " fmt "\n",                 \
                    __func__, ##__VA_ARGS__);                                \
    } while (0)

/*
 * Small helper: return the basename of a path (the part after the last
 * '/').  Returns the input unchanged if there is no '/'.
 *
 * This is used both for sysfs lookups and for the device path in
 * /dev/block/, so it is worth having a single implementation.
 */
static const char *zramctl_basename(const char *path)
{
    const char *slash;

    if (!path)
        return "";
    slash = strrchr(path, '/');
    return slash ? slash + 1 : path;
}

/* status output columns */
struct colinfo {
    const char *name;
    double whint;
    int flags;
    const char *help;
};

enum {
    COL_NAME = 0,
    COL_DISKSIZE,
    COL_ORIG_SIZE,
    COL_COMP_SIZE,
    COL_ALGORITHM,
    COL_STREAMS,
    COL_ZEROPAGES,
    COL_MEMTOTAL,
    COL_MEMLIMIT,
    COL_MEMUSED,
    COL_MIGRATED,
    COL_COMPRATIO,
    COL_MOUNTPOINT
};

static const struct colinfo infos[] = {
    [COL_NAME]      = { "NAME",      0.25, 0, N_("zram device name") },
    [COL_DISKSIZE]  = { "DISKSIZE",     5, SCOLS_FL_RIGHT, N_("limit on the uncompressed amount of data") },
    [COL_ORIG_SIZE] = { "DATA",         5, SCOLS_FL_RIGHT, N_("uncompressed size of stored data") },
    [COL_COMP_SIZE] = { "COMPR",        5, SCOLS_FL_RIGHT, N_("compressed size of stored data") },
    [COL_ALGORITHM] = { "ALGORITHM",    3, 0, N_("the selected compression algorithm") },
    [COL_STREAMS]   = { "STREAMS",      3, SCOLS_FL_RIGHT, N_("number of concurrent compress operations") },
    [COL_ZEROPAGES] = { "ZERO-PAGES",   3, SCOLS_FL_RIGHT, N_("empty pages with no allocated memory") },
    [COL_MEMTOTAL]  = { "TOTAL",        5, SCOLS_FL_RIGHT, N_("all memory including allocator fragmentation and metadata overhead") },
    [COL_MEMLIMIT]  = { "MEM-LIMIT",    5, SCOLS_FL_RIGHT, N_("memory limit used to store compressed data") },
    [COL_MEMUSED]   = { "MEM-USED",     5, SCOLS_FL_RIGHT, N_("peak memory usage to store compressed data") },
    [COL_MIGRATED]  = { "MIGRATED",     5, SCOLS_FL_RIGHT, N_("number of objects migrated by compaction") },
    [COL_COMPRATIO] = { "COMP-RATIO",   5, SCOLS_FL_RIGHT, N_("compression ratio: DATA/TOTAL") },
    [COL_MOUNTPOINT]= { "MOUNTPOINT",0.10, SCOLS_FL_TRUNC, N_("where the device is mounted") },
};

static int columns[ARRAY_SIZE(infos) * 2] = {-1};
static size_t ncolumns;

enum {
    MM_ORIG_DATA_SIZE = 0,
    MM_COMPR_DATA_SIZE,
    MM_MEM_USED_TOTAL,
    MM_MEM_LIMIT,
    MM_MEM_USED_MAX,
    MM_ZERO_PAGES,
    MM_NUM_MIGRATED
};

static const char *const mm_stat_names[] = {
    [MM_ORIG_DATA_SIZE]  = "orig_data_size",
    [MM_COMPR_DATA_SIZE] = "compr_data_size",
    [MM_MEM_USED_TOTAL]  = "mem_used_total",
    [MM_MEM_LIMIT]       = "mem_limit",
    [MM_MEM_USED_MAX]    = "mem_used_max",
    [MM_ZERO_PAGES]      = "zero_pages",
    [MM_NUM_MIGRATED]    = "num_migrated"
};

struct zram {
    char    devname[64];        /* short name "zram0" or full path */
    int     lock_fd;
    struct  path_cxt *sysfs;    /* device specific sysfs directory */
    char    **mm_stat;

#if HAVE_DECL_SD_DEVICE_NEW_FROM_SYSPATH
    sd_device   *device;
#endif

    unsigned int mm_stat_probed : 1,
                 control_probed : 1,
                 has_control : 1;   /* has /sys/class/zram-control/ */
};

static unsigned int raw, no_headings, inbytes;
static struct path_cxt *__control;

static int get_column_id(size_t num)
{
    assert(num < ncolumns);
    assert(columns[num] < (int) ARRAY_SIZE(infos));
    return columns[num];
}

static const struct colinfo *get_column_info(int num)
{
    return &infos[ get_column_id(num) ];
}

static int column_name_to_id(const char *name, size_t namesz)
{
    size_t i;

    for (i = 0; i < ARRAY_SIZE(infos); i++) {
        const char *cn = infos[i].name;

        if (!c_strncasecmp(name, cn, namesz) && !*(cn + namesz))
            return i;
    }
    warnx(_("unknown column: %s"), name);
    return -1;
}

#if HAVE_DECL_SD_DEVICE_NEW_FROM_SYSPATH
static int monitor_callback(sd_device_monitor *m, sd_device *device, void *userdata)
{
    struct zram *z = userdata;
    sd_device_action_t a;
    const char *s;

    assert(z);
    assert(device);

    if (sd_device_get_action(device, &a) < 0)
        return 0;

    if (a == SD_DEVICE_REMOVE)
        return 0;

    if (sd_device_get_devname(device, &s) < 0)
        return 0;

    if (strcmp(s, z->devname) != 0)
        return 0;

    if (sd_device_get_is_initialized(device) <= 0)
        return 0;

    assert(!z->device);
    z->device = sd_device_ref(device);

    return sd_event_exit(sd_device_monitor_get_event(m), 0);
}
#endif

static int zram_wait_initialized(struct zram *z)
{
#if HAVE_DECL_SD_DEVICE_NEW_FROM_SYSPATH
    _cleanup_(sd_device_unrefp) sd_device *dev = NULL;
    _cleanup_(sd_device_monitor_unrefp) sd_device_monitor *m = NULL;
    sd_event *event;
    int r;

    assert(z);

    DBG_BASIC("waiting for device %s to be initialised by udev", z->devname);

    z->device = sd_device_unref(z->device);

    r = sd_device_monitor_new(&m);
    if (r < 0) {
        DBG_BASIC("sd_device_monitor_new() failed: %d", r);
        return r;
    }

    r = sd_device_monitor_filter_add_match_subsystem_devtype(m, "block", "disk");
    if (r < 0) {
        DBG_BASIC("sd_device_monitor_filter_add_match_subsystem_devtype() failed: %d", r);
        return r;
    }

    r = sd_device_monitor_start(m, monitor_callback, z);
    if (r < 0) {
        DBG_BASIC("sd_device_monitor_start() failed: %d", r);
        return r;
    }

    event = sd_device_monitor_get_event(m);

    r = sd_event_add_time_relative(event, NULL, CLOCK_BOOTTIME, 3 * 1000 * 1000, 0, NULL, (void*) (intptr_t) (-ETIMEDOUT));
    if (r < 0) {
        DBG_BASIC("sd_event_add_time_relative() failed: %d", r);
        return r;
    }

#if HAVE_DECL_SD_DEVICE_OPEN
    r = sd_device_new_from_devname(&dev, z->devname);
#else
    {
        char syspath[PATH_MAX];
        const char *slash;

        slash = strrchr(z->devname, '/');
        if (!slash) {
            DBG_BASIC("cannot determine basename of %s", z->devname);
            return -EINVAL;
        }
        snprintf(syspath, sizeof(syspath), "/sys/class/block/%s", slash+1);

        DBG_VERBOSE("using syspath %s", syspath);
        r = sd_device_new_from_syspath(&dev, syspath);
    }
#endif
    if (r < 0) {
        DBG_BASIC("failed to open device %s: %d", z->devname, r);
        return r;
    }

    r = sd_device_get_is_initialized(dev);
    if (r < 0) {
        DBG_BASIC("sd_device_get_is_initialized() failed: %d", r);
        return r;
    }
    if (r > 0) {
        DBG_VERBOSE("device %s is already initialised", z->devname);
        z->device = dev;
        dev = NULL;
        return 0;
    }

    DBG_VERBOSE("waiting up to 3 seconds for udev event on %s", z->devname);
    return sd_event_loop(event);
#else
    assert(z);
    DBG_VERBOSE("sd-device support not compiled in, skipping wait for %s", z->devname);
    return 0;
#endif
}

static int zram_lock(struct zram *z, int operation)
{
    int fd, r;

    assert(z);
    assert((operation & ~LOCK_NB) == LOCK_SH ||
           (operation & ~LOCK_NB) == LOCK_EX);

    if (z->lock_fd >= 0) {
        DBG_VERBOSE("device %s is already locked (fd=%d)", z->devname, z->lock_fd);
        return 0;
    }

#if HAVE_DECL_SD_DEVICE_OPEN
    if (z->device) {
        fd = sd_device_open(z->device, O_RDONLY|O_CLOEXEC|O_NONBLOCK|O_NOCTTY);
        if (fd < 0) {
            DBG_BASIC("sd_device_open(%s) failed: %s", z->devname, strerror(-fd));
            return fd;
        }
    } else {
#endif
        fd = open(z->devname, O_RDONLY|O_CLOEXEC|O_NONBLOCK|O_NOCTTY);
        if (fd < 0) {
            DBG_BASIC("open(%s) failed: %s", z->devname, strerror(errno));
            return -errno;
        }
#if HAVE_DECL_SD_DEVICE_OPEN
    }
#endif

    if (flock(fd, operation) < 0) {
        r = -errno;
        DBG_BASIC("flock(%s, 0x%x) failed: %s", z->devname, operation, strerror(errno));
        close(fd);
        return r;
    }

    DBG_VERBOSE("locked device %s (fd=%d, operation=0x%x)", z->devname, fd, operation);
    z->lock_fd = fd;
    return 0;
}

static void zram_unlock(struct zram *z)
{
    if (z && z->lock_fd >= 0) {
        DBG_VERBOSE("unlocking device %s (fd=%d)", z->devname, z->lock_fd);
        close(z->lock_fd);
        z->lock_fd = -EBADF;
    }
}

static void zram_reset_stat(struct zram *z)
{
    if (z) {
        if (z->mm_stat)
            DBG_VERBOSE("freeing cached mm_stat for %s", z->devname);
        ul_strv_free(z->mm_stat);
        z->mm_stat = NULL;
        z->mm_stat_probed = 0;
    }
}

/*
 * Set the device name.
 *
 * Two forms are accepted:
 *
 *   - devname == NULL: generate a short name "zram<N>".  This is the
 *     canonical form for sysfs lookups (/sys/block/zramN).
 *
 *   - devname != NULL: use the given string as-is.  The caller may
 *     pass a short name ("zram0"), a full Android path
 *     ("/dev/block/zram0"), or a legacy path ("/dev/zram0").  The
 *     basename is used for sysfs lookups; the full string is used for
 *     open()/flock() and for display.
 *
 * The lock file descriptor is intentionally NOT closed here because
 * callers may want to keep a device locked while changing its name
 * (this happens in find_free_zram()).
 */
static void zram_set_devname(struct zram *z, const char *devname, size_t n)
{
    assert(z);

    if (!devname) {
        snprintf(z->devname, sizeof(z->devname), "zram%zu", n);
        DBG_VERBOSE("generated short device name \"%s\" (index=%zu)",
                    z->devname, n);
    } else {
        xstrncpy(z->devname, devname, sizeof(z->devname));
        DBG_VERBOSE("using supplied device name \"%s\"", z->devname);
    }

    ul_unref_path(z->sysfs);
    z->sysfs = NULL;
    zram_reset_stat(z);
}

/*
 * Extract the device number from a device name.
 *
 * Accepts all three forms:
 *   - "zramN"               (canonical, used internally)
 *   - "/dev/block/zramN"    (Android)
 *   - "/dev/zramN"          (upstream Linux, for compatibility)
 *
 * Returns the numeric index N on success, or -EINVAL if the name does
 * not match any known form.
 */
static int zram_get_devnum(struct zram *z)
{
    int n;

    assert(z);

    if (sscanf(z->devname, "zram%d", &n) == 1)
        return n;
    if (sscanf(z->devname, _PATH_DEV "/zram%d", &n) == 1)
        return n;
    if (sscanf(z->devname, "/dev/zram%d", &n) == 1)
        return n;

    DBG_BASIC("cannot extract device number from \"%s\"", z->devname);
    return -EINVAL;
}

static struct zram *new_zram(const char *devname)
{
    struct zram *z = xcalloc(1, sizeof(struct zram));

    z->lock_fd = -EBADF;

    DBG_VERBOSE("allocated new zram handle at %p (devname=%s)",
                (void *) z, devname ? devname : "(null)");

    if (devname)
        zram_set_devname(z, devname, 0);

    return z;
}

static void free_zram(struct zram *z)
{
    if (!z)
        return;

    DBG_VERBOSE("freeing zram handle %p (devname=%s)",
                (void *) z, z->devname);

    ul_unref_path(z->sysfs);
    zram_reset_stat(z);
    zram_unlock(z);

#if HAVE_DECL_SD_DEVICE_NEW_FROM_SYSPATH
    sd_device_unref(z->device);
#endif

    free(z);
}

/*
 * Resolve the sysfs directory for a zram device.
 *
 * Android exposes zram under /sys/block/zramN.  The symlink
 * /sys/class/block/zramN exists but the underlying directory is the
 * one under /sys/block, and the generic sysfs_devname_to_devno()
 * helper does not always resolve "zramN" on Android kernels.  We
 * therefore build the sysfs path directly from the device basename.
 *
 * The result is cached in z->sysfs so that repeated attribute reads
 * do not re-resolve the path.
 */
static struct path_cxt *zram_get_sysfs(struct zram *z)
{
    const char *base;
    char path[PATH_MAX];
    struct stat st;

    assert(z);

    if (z->sysfs) {
        DBG_VERBOSE("reusing cached sysfs path for %s", z->devname);
        return z->sysfs;
    }

    /*
     * Use only the basename for the sysfs lookup so that both
     * "zram0" and "/dev/block/zram0" resolve to /sys/block/zram0.
     */
    base = zramctl_basename(z->devname);
    snprintf(path, sizeof(path), ZRAMCTL_SYSFS_BLOCK "/%s", base);

    DBG_VERBOSE("resolving sysfs path for %s -> %s", z->devname, path);

    z->sysfs = ul_new_path(path);
    if (!z->sysfs) {
        DBG_BASIC("ul_new_path(%s) failed: %s", path, strerror(errno));
        return NULL;
    }

    /*
     * Sanity check: the directory must exist.  ul_new_path() itself
     * does not verify existence, so an Android kernel without zram
     * support would otherwise produce confusing later errors.
     */
    if (stat(path, &st) < 0 || !S_ISDIR(st.st_mode)) {
        DBG_BASIC("sysfs path %s does not exist or is not a directory", path);
        ul_unref_path(z->sysfs);
        z->sysfs = NULL;
        return NULL;
    }

    DBG_VERBOSE("sysfs path %s resolved and verified", path);
    return z->sysfs;
}

static inline int zram_exist(struct zram *z)
{
    assert(z);

    errno = 0;
    if (zram_get_sysfs(z) == NULL) {
        errno = ENODEV;
        DBG_VERBOSE("device %s does not exist", z->devname);
        return 0;
    }

    DBG_VERBOSE("device %s exists", z->devname);
    return 1;
}

static int zram_set_u64parm(struct zram *z, const char *attr, uint64_t num)
{
    struct path_cxt *sysfs = zram_get_sysfs(z);
    int rc;

    if (!sysfs)
        return -EINVAL;

    DBG_VERBOSE("writing %ju to %s/%s", num, z->devname, attr);
    rc = ul_path_write_u64(sysfs, num, attr);
    if (rc)
        DBG_BASIC("failed to write %ju to %s/%s: %s",
                  num, z->devname, attr, strerror(errno));
    return rc;
}

static int zram_set_strparm(struct zram *z, const char *attr, const char *str)
{
    struct path_cxt *sysfs = zram_get_sysfs(z);
    int rc;

    if (!sysfs)
        return -EINVAL;

    DBG_VERBOSE("writing \"%s\" to %s/%s", str, z->devname, attr);
    rc = ul_path_write_string(sysfs, str, attr);
    if (rc)
        DBG_BASIC("failed to write \"%s\" to %s/%s: %s",
                  str, z->devname, attr, strerror(errno));
    return rc;
}

/*
 * Read a sysfs attribute directly with open()/read().
 *
 * Why not use ul_path_read_*()?  On Android kernels, sysfs files
 * frequently report st_size == 0 via fstat().  The util-linux helpers
 * allocate a buffer based on st_size and therefore end up reading
 * nothing.  Reading directly with read() sidesteps that problem.
 *
 * The caller-supplied buffer is NUL-terminated and trailing
 * whitespace (newline, carriage return, spaces, tabs) is removed.
 *
 * Returns the number of bytes read (>= 0) on success, or -errno on
 * failure.
 */
static ssize_t zram_read_sysfs_attr(const char *devname,
                                    const char *attr,
                                    char *buf, size_t bufsz)
{
    char path[PATH_MAX];
    const char *base;
    ssize_t n;
    int fd;
    char *end;

    assert(bufsz > 0);

    base = zramctl_basename(devname);
    snprintf(path, sizeof(path), ZRAMCTL_SYSFS_BLOCK "/%s/%s", base, attr);

    fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        DBG_VERBOSE("open(%s) failed: %s", path, strerror(errno));
        return -errno;
    }

    n = read(fd, buf, bufsz - 1);
    close(fd);

    if (n < 0) {
        DBG_VERBOSE("read(%s) failed: %s", path, strerror(errno));
        return -errno;
    }

    buf[n] = '\0';

    /* Trim trailing whitespace in place. */
    end = buf + n - 1;
    while (end >= buf && isspace((unsigned char) *end))
        *end-- = '\0';

    DBG_VERBOSE("read %s -> \"%s\"", path, buf);
    return (ssize_t) strlen(buf);
}

/*
 * Determine whether a zram device is in use.
 *
 * A device is considered "in use" if its disksize attribute is greater
 * than zero.  This matches the behaviour of upstream zramctl.
 *
 * We read the attribute directly because ul_path_read_u64() is not
 * reliable on Android sysfs (see zram_read_sysfs_attr()).
 */
static int zram_used(struct zram *z)
{
    char buf[64];
    ssize_t n;
    uint64_t size = 0;
    char *endptr;

    assert(z);

    n = zram_read_sysfs_attr(z->devname, "disksize", buf, sizeof(buf));
    if (n <= 0) {
        DBG_VERBOSE("could not read disksize for %s (n=%zd)", z->devname, n);
        return 0;
    }

    errno = 0;
    size = strtoull(buf, &endptr, 10);
    if (errno || endptr == buf) {
        DBG_BASIC("failed to parse disksize \"%s\" for %s: %s",
                  buf, z->devname, strerror(errno));
        return 0;
    }

    DBG_VERBOSE("device %s has disksize=%ju", z->devname, size);
    return size > 0;
}

static int zram_has_control(struct zram *z)
{
    if (!z->control_probed) {
        z->has_control = access(_PATH_SYS_CLASS "/zram-control/", F_OK) == 0 ? 1 : 0;
        z->control_probed = 1;
        DBG_VERBOSE("zram-control available: %s",
                    z->has_control ? "yes" : "no");
    }

    return z->has_control;
}

static struct path_cxt *zram_get_control(void)
{
    if (!__control) {
        __control = ul_new_path(_PATH_SYS_CLASS "/zram-control");
        DBG_VERBOSE("created control path %s", _PATH_SYS_CLASS "/zram-control");
    }
    return __control;
}

static int zram_control_add(struct zram *z)
{
    int n = 0;
    struct path_cxt *ctl;
    int rc;

    if (!zram_has_control(z) || !(ctl = zram_get_control()))
        return -ENOSYS;

    rc = ul_path_read_s32(ctl, &n, "hot_add");
    if (rc != 0 || n < 0) {
        DBG_BASIC("hot_add failed (rc=%d, n=%d)", rc, n);
        return n;
    }

    DBG_VERBOSE("hot-added zram device %d", n);
    zram_set_devname(z, NULL, n);
    return 0;
}

static int zram_control_remove(struct zram *z)
{
    struct path_cxt *ctl;
    int n, rc;

    if (!zram_has_control(z) || !(ctl = zram_get_control()))
        return -ENOSYS;

    n = zram_get_devnum(z);
    if (n < 0)
        return n;

    DBG_VERBOSE("hot-removing zram device %d", n);
    rc = ul_path_write_u64(ctl, n, "hot_remove");
    if (rc)
        DBG_BASIC("hot_remove of zram%d failed: %s", n, strerror(errno));
    return rc;
}

static struct zram *find_free_zram(void)
{
    struct zram *z = new_zram(NULL);
    size_t i;
    int isfree = 0;

    for (i = 0; isfree == 0; i++) {
        DBG_VERBOSE("checking whether zram%zu is free", i);
        zram_set_devname(z, NULL, i);
        if (!zram_exist(z) && zram_control_add(z) != 0) {
            DBG_BASIC("no more zram devices available after zram%zu", i);
            break;
        }
        isfree = !zram_used(z);
        DBG_VERBOSE("zram%zu is %s", i, isfree ? "free" : "in use");
    }

    if (!isfree) {
        DBG_BASIC("no free zram device found");
        free_zram(z);
        z = NULL;
    } else {
        DBG_BASIC("found free zram device %s", z->devname);
    }
    return z;
}

/*
 * Return a human-readable string for the NAME column.
 *
 * Internally we keep the short name "zramN" so that sysfs lookups are
 * simple, but users expect the full Android path under /dev/block/.
 * If the caller already supplied a full path, we return it unchanged.
 */
static char *zram_full_devname(struct zram *z)
{
    char *str = NULL;

    if (*z->devname == '/')
        return xstrdup(z->devname);

    xasprintf(&str, _PATH_DEV "/%s", z->devname);
    return str;
}



/*
 * Print the version string for zramctl only.
 *
 * We deliberately do NOT use the shared print_version() helper from
 * include/c.h because we want to add an Android-specific tag to the
 * version output without affecting any other util-linux tool.
 *
 * The upstream version comes from PACKAGE_VERSION (set by configure),
 * and the Android tag is defined at the top of this file.
 */
static void __attribute__((__noreturn__)) zramctl_print_version(void)
{
    fprintf(stdout, "zramctl from util-linux %s (%s)\n",
            PACKAGE_VERSION, ZRAMCTL_ANDROID_TAG);
    exit(EXIT_SUCCESS);
}

/* --------------------------------------------------------------------- */
/* mm_stat and column data                                              */
/* --------------------------------------------------------------------- */

static int get_mm_stat(struct zram *z,
             size_t idx, int bytes,
             char **re_str, uint64_t *re_num)
{
    struct path_cxt *sysfs;
    const char *name;
    uint64_t num;
    char buf[64];
    ssize_t n;

    assert(idx < ARRAY_SIZE(mm_stat_names));
    assert(z);

    sysfs = zram_get_sysfs(z);
    if (!sysfs)
        return -ENOENT;

    /*
     * Linux >= 4.1 exposes all counters in a single "mm_stat" file.
     * Linux < 4.1 exposes them as individual attributes.
     *
     * We try mm_stat first and fall back to the per-attribute form.
     */
    if (!z->mm_stat && !z->mm_stat_probed) {
        n = zram_read_sysfs_attr(z->devname, "mm_stat", buf, sizeof(buf));
        if (n > 0) {
            z->mm_stat = ul_strv_split(buf, " ");

            if (ul_strv_length(z->mm_stat) < ARRAY_SIZE(mm_stat_names)) {
                DBG_BASIC("mm_stat for %s has unexpected format (\"%s\")",
                          z->devname, buf);
                ul_strv_free(z->mm_stat);
                z->mm_stat = NULL;
            } else {
                DBG_VERBOSE("mm_stat for %s parsed successfully", z->devname);
            }
        } else {
            DBG_VERBOSE("mm_stat not available for %s, falling back to per-attribute reads",
                        z->devname);
        }
        z->mm_stat_probed = 1;
    }

    if (z->mm_stat) {
        if (re_str && bytes)
            *re_str = xstrdup(z->mm_stat[idx]);

        num = strtou64_or_err(z->mm_stat[idx], _("Failed to parse mm_stat"));
        if (re_num)
            *re_num = num;
        if (re_str && !bytes)
            *re_str = size_to_human_string(SIZE_SUFFIX_1LETTER, num);
        return 0;
    }

    name = mm_stat_names[idx];

    if (re_str && bytes) {
        n = zram_read_sysfs_attr(z->devname, name, buf, sizeof(buf));
        if (n > 0)
            *re_str = xstrdup(buf);
        else
            DBG_VERBOSE("attribute %s for %s not readable (n=%zd)",
                        name, z->devname, n);
    }

    if ((re_str && !bytes) || re_num) {
        int rc = ul_path_read_u64(sysfs, &num, name);
        if (rc != 0) {
            DBG_VERBOSE("ul_path_read_u64(%s/%s) failed, using direct read",
                        z->devname, name);
            n = zram_read_sysfs_attr(z->devname, name, buf, sizeof(buf));
            if (n <= 0)
                return -ENOENT;
            num = strtou64_or_err(buf, _("Failed to parse mm_stat attribute"));
        }

        if (re_str && !bytes)
            *re_str = size_to_human_string(SIZE_SUFFIX_1LETTER, num);
        if (re_num)
            *re_num = num;
    }

    return 0;
}

static char *get_mm_stat_string(struct zram *z, size_t idx, int bytes)
{
    char *str = NULL;

    get_mm_stat(z, idx, bytes, &str, NULL);
    return str;
}

static uint64_t get_mm_stat_number(struct zram *z, size_t idx)
{
    uint64_t num = 0;

    get_mm_stat(z, idx, 0, NULL, &num);
    return num;
}

static void fill_table_row(struct libscols_table *tb, struct zram *z)
{
    static struct libscols_line *ln;
    struct path_cxt *sysfs;
    size_t i;
    uint64_t num;

    assert(tb);
    assert(z);

    DBG_VERBOSE("filling status table row for %s", z->devname);

    sysfs = zram_get_sysfs(z);
    if (!sysfs) {
        DBG_BASIC("skipping %s: sysfs path could not be resolved", z->devname);
        return;
    }

    ln = scols_table_new_line(tb, NULL);
    if (!ln)
        err(EXIT_FAILURE, _("failed to allocate output line"));

    for (i = 0; i < ncolumns; i++) {
        char *str = NULL;
        int col = get_column_id(i);

        switch (col) {
        case COL_NAME:
            str = zram_full_devname(z);
            break;
        case COL_DISKSIZE:
            if (inbytes) {
                char buf[64];
                ssize_t n = zram_read_sysfs_attr(z->devname, "disksize",
                                                 buf, sizeof(buf));
                if (n > 0)
                    str = xstrdup(buf);
            } else if (ul_path_read_u64(sysfs, &num, "disksize") == 0) {
                str = size_to_human_string(SIZE_SUFFIX_1LETTER, num);
            } else {
                char buf[64];
                ssize_t n = zram_read_sysfs_attr(z->devname, "disksize",
                                                 buf, sizeof(buf));
                if (n > 0) {
                    num = strtou64_or_err(buf, _("Failed to parse disksize"));
                    str = size_to_human_string(SIZE_SUFFIX_1LETTER, num);
                }
            }
            break;
        case COL_ALGORITHM:
        {
            char buf[256];
            char *alg = NULL;
            ssize_t n = zram_read_sysfs_attr(z->devname, "comp_algorithm",
                                             buf, sizeof(buf));

            if (n > 0) {
                alg = buf;
                char *lbr = strrchr(alg, '[');
                char *rbr = strrchr(alg, ']');

                if (lbr != NULL && rbr != NULL && rbr - lbr > 1)
                    str = xstrndup(lbr + 1, rbr - lbr - 1);
            } else {
                DBG_VERBOSE("comp_algorithm not readable for %s (n=%zd)",
                            z->devname, n);
            }
            break;
        }
        case COL_MOUNTPOINT:
        {
            char path[PATH_MAX] = { '\0' };
            int fl;
            char *full = zram_full_devname(z);

            check_mount_point(full, &fl, path, sizeof(path));
            if (*path)
                str = xstrdup(path);
            free(full);
            break;
        }
        case COL_COMPRATIO:
            xasprintf(&str, "%.4f",
                (double) get_mm_stat_number(z, MM_ORIG_DATA_SIZE)
                / get_mm_stat_number(z, MM_MEM_USED_TOTAL));
            break;
        case COL_STREAMS:
        {
            char buf[64];
            ssize_t n = zram_read_sysfs_attr(z->devname, "max_comp_streams",
                                             buf, sizeof(buf));
            if (n > 0)
                str = xstrdup(buf);
            else
                DBG_VERBOSE("max_comp_streams not readable for %s (n=%zd)",
                            z->devname, n);
            break;
        }
        case COL_ZEROPAGES:
            str = get_mm_stat_string(z, MM_ZERO_PAGES, 1);
            break;
        case COL_ORIG_SIZE:
            str = get_mm_stat_string(z, MM_ORIG_DATA_SIZE, inbytes);
            break;
        case COL_COMP_SIZE:
            str = get_mm_stat_string(z, MM_COMPR_DATA_SIZE, inbytes);
            break;
        case COL_MEMTOTAL:
            str = get_mm_stat_string(z, MM_MEM_USED_TOTAL, inbytes);
            break;
        case COL_MEMLIMIT:
            str = get_mm_stat_string(z, MM_MEM_LIMIT, inbytes);
            break;
        case COL_MEMUSED:
            str = get_mm_stat_string(z, MM_MEM_USED_MAX, inbytes);
            break;
        case COL_MIGRATED:
            str = get_mm_stat_string(z, MM_NUM_MIGRATED, inbytes);
            break;
        }
        if (str && scols_line_refer_data(ln, i, str))
            err(EXIT_FAILURE, _("failed to add output data"));
    }
}

static void status(struct zram *z)
{
    struct libscols_table *tb;
    size_t i;
    DIR *dir;
    struct dirent *d;

    scols_init_debug(0);

    tb = scols_new_table();
    if (!tb)
        err(EXIT_FAILURE, _("failed to allocate output table"));

    scols_table_enable_raw(tb, raw);
    scols_table_enable_noheadings(tb, no_headings);

    for (i = 0; i < ncolumns; i++) {
        const struct colinfo *col = get_column_info(i);

        if (!scols_table_new_column(tb, col->name, col->whint, col->flags))
            err(EXIT_FAILURE, _("failed to initialize output column"));
    }

    if (z) {
        DBG_BASIC("showing status for explicitly requested device %s", z->devname);
        fill_table_row(tb, z);
        goto print_table;
    }

    DBG_BASIC("scanning %s for zram devices", _PATH_DEV);
    z = new_zram(NULL);
    if (!(dir = opendir(_PATH_DEV)))
        err(EXIT_FAILURE, _("cannot open %s"), _PATH_DEV);

    while ((d = readdir(dir))) {
        int n;
        if (sscanf(d->d_name, "zram%d", &n) != 1)
            continue;

        DBG_VERBOSE("found candidate device \"%s\" in %s", d->d_name, _PATH_DEV);
        zram_set_devname(z, NULL, n);

        if (zram_exist(z) && zram_used(z)) {
            DBG_BASIC("device %s is in use, adding to output", z->devname);
            fill_table_row(tb, z);
        } else {
            DBG_VERBOSE("device %s is not in use, skipping", z->devname);
        }
    }
    closedir(dir);
    free_zram(z);

print_table:
    scols_print_table(tb);
    scols_unref_table(tb);
}

static void __attribute__((__noreturn__)) usage(void)
{
    FILE *out = stdout;
    size_t i;

    fputs(USAGE_HEADER, out);
    fprintf(out, _( " %1$s [options] <device>\n"
            " %1$s -r <device> [...]\n"
            " %1$s [options] -f | <device> -s <size>\n"),
            program_invocation_short_name);

    fputs(USAGE_SEPARATOR, out);
    fputs(_("Set up and control zram devices.\n"), out);
    fputs(_("(Android build: devices live under /dev/block/)\n"), out);

    fputs(USAGE_OPTIONS, out);
    fputs(_(" -a, --algorithm <alg>     compression algorithm to use\n"), out);
    fputs(_(" -b, --bytes               print sizes in bytes, not in human-readable form\n"), out);
    fputs(_(" -f, --find                find a free device\n"), out);
    fputs(_(" -n, --noheadings          don't print headings\n"), out);
    fputs(_(" -o, --output <list>       columns to use for status output\n"), out);
    fputs(_("     --output-all          output all columns\n"), out);
    fputs(_(" -p, --algorithm-params <parameter>...\n"
        "                           parameters for the compression algorithm\n"), out);
    fputs(_(" -r, --reset <device>...   reset the specified zram devices\n"), out);
    fputs(_("     --raw                 use raw status output format\n"), out);
    fputs(_(" -s, --size <size>         device size\n"), out);
    fputs(_(" -t, --streams <number>    number of compression streams\n"), out);

    fputs(USAGE_SEPARATOR, out);
    fprintf(out, USAGE_HELP_OPTIONS(27));

    fputs(USAGE_ARGUMENTS, out);
    fprintf(out, USAGE_ARG_SIZE(_("<size>")));

    fputs(_(" <alg> is the name of an algorithm; supported are:\n"), out);
    fputs(  "   lzo, lz4, lz4hc, deflate, 842, zstd\n", out);
    fputs(_("   (List may be inaccurate, consult man page.)\n"), out);

    fputs(USAGE_COLUMNS, out);
    for (i = 0; i < ARRAY_SIZE(infos); i++)
        fprintf(out, " %11s  %s\n", infos[i].name, _(infos[i].help));

    fputs(USAGE_SEPARATOR, out);
    fputs(_("Debug output is controlled by the ZRAMCTL_DEBUG environment variable.\n"
            "Set ZRAMCTL_DEBUG=1 for basic diagnostics, or ZRAMCTL_DEBUG=verbose\n"
            "for more detail.  All debug output goes to stderr.\n"), out);

    fprintf(out, USAGE_MAN_TAIL("zramctl(8)"));
    exit(EXIT_SUCCESS);
}

/* actions */
enum {
    A_NONE = 0,
    A_STATUS,
    A_CREATE,
    A_FINDONLY,
    A_RESET
};

int main(int argc, char **argv)
{
    uintmax_t size = 0, nstreams = 0;
    char *algorithm = NULL;
    char *algorithm_params = NULL;
    int rc = 0, c, find = 0, act = A_NONE;
    struct zram *zram = NULL;
    char *outarg = NULL;

    enum {
        OPT_RAW = CHAR_MAX + 1,
        OPT_LIST_TYPES
    };

    static const struct option longopts[] = {
        { "algorithm",       required_argument, NULL, 'a' },
        { "bytes",           no_argument, NULL, 'b' },
        { "find",            no_argument, NULL, 'f' },
        { "help",            no_argument, NULL, 'h' },
        { "output",          required_argument, NULL, 'o' },
        { "output-all",      no_argument, NULL, OPT_LIST_TYPES },
        { "algorithm-params",required_argument, NULL, 'p' },
        { "noheadings",      no_argument, NULL, 'n' },
        { "reset",           no_argument, NULL, 'r' },
        { "raw",             no_argument, NULL, OPT_RAW },
        { "size",            required_argument, NULL, 's' },
        { "streams",         required_argument, NULL, 't' },
        { "version",         no_argument, NULL, 'V' },
        { NULL, 0, NULL, 0 }
    };

    static const ul_excl_t excl[] = {
        { 'f', 'o', 'r' },
        { 'o', 'r', 's' },
        { 0 }
    };
    int excl_st[ARRAY_SIZE(excl)] = UL_EXCL_STATUS_INIT;

    /*
     * Initialise debug as early as possible so that even argument
     * parsing and early setup emit debug output if requested.
     */
    zramctl_init_debug();

    DBG_BASIC("starting zramctl (Android build %s)", ZRAMCTL_ANDROID_TAG);
    DBG_VERBOSE("program invocation: %s", program_invocation_short_name);

    setlocale(LC_ALL, "");
    bindtextdomain(PACKAGE, LOCALEDIR);
    textdomain(PACKAGE);
    close_stdout_atexit();

    while ((c = getopt_long(argc, argv, "a:bfho:p:nrs:t:V", longopts, NULL)) != -1) {

        err_exclusive_options(c, longopts, excl, excl_st);

        switch (c) {
        case 'a':
            algorithm = optarg;
            DBG_VERBOSE("algorithm set to \"%s\"", algorithm);
            break;
        case 'b':
            inbytes = 1;
            DBG_VERBOSE("byte output enabled");
            break;
        case 'f':
            find = 1;
            DBG_VERBOSE("find free device requested");
            break;
        case 'o':
            outarg = optarg;
            DBG_VERBOSE("output columns requested: \"%s\"", outarg);
            break;
        case OPT_LIST_TYPES:
            for (ncolumns = 0; ncolumns < ARRAY_SIZE(infos); ncolumns++)
                columns[ncolumns] = ncolumns;
            DBG_VERBOSE("all columns enabled");
            break;
        case 'p':
            algorithm_params = optarg;
            DBG_VERBOSE("algorithm params set to \"%s\"", algorithm_params);
            break;
        case 's':
            size = strtosize_or_err(optarg, _("failed to parse size"));
            act = A_CREATE;
            DBG_VERBOSE("requested size=%ju", size);
            break;
        case 't':
            nstreams = strtou64_or_err(optarg, _("failed to parse streams"));
            DBG_VERBOSE("requested streams=%ju", nstreams);
            break;
        case 'r':
            act = A_RESET;
            DBG_VERBOSE("reset action requested");
            break;
        case OPT_RAW:
            raw = 1;
            DBG_VERBOSE("raw output enabled");
            break;
        case 'n':
            no_headings = 1;
            DBG_VERBOSE("no headings enabled");
            break;

        case 'V':
	    zramctl_print_version();
        case 'h':
            usage();
        default:
            errtryhelp(EXIT_FAILURE);
        }
    }

    if (find && optind < argc)
        errx(EXIT_FAILURE, _("option --find is mutually exclusive "
                     "with <device>"));
    if (act == A_NONE)
        act = find ? A_FINDONLY : A_STATUS;

    if (act != A_RESET && optind + 1 < argc)
        errx(EXIT_FAILURE, _("only one <device> at a time is allowed"));

    if ((act == A_STATUS || act == A_FINDONLY) && (algorithm || algorithm_params || nstreams))
        errx(EXIT_FAILURE, _("options --algorithm, --algorithm-params, and --streams "
                     "must be combined with --size"));

    DBG_BASIC("selected action %d (0=none,1=status,2=create,3=find,4=reset)", act);

    ul_path_init_debug();
    ul_sysfs_init_debug();

    switch (act) {
    case A_STATUS:
        if (!ncolumns) {        /* default columns */
            columns[ncolumns++] = COL_NAME;
            columns[ncolumns++] = COL_ALGORITHM;
            columns[ncolumns++] = COL_DISKSIZE;
            columns[ncolumns++] = COL_ORIG_SIZE;
            columns[ncolumns++] = COL_COMP_SIZE;
            columns[ncolumns++] = COL_MEMTOTAL;
            columns[ncolumns++] = COL_STREAMS;
            columns[ncolumns++] = COL_MOUNTPOINT;
        }

        if (outarg && string_add_to_idarray(outarg,
                    columns, ARRAY_SIZE(columns),
                    &ncolumns, column_name_to_id) < 0)
            return EXIT_FAILURE;

        if (optind < argc) {
            DBG_BASIC("using explicitly requested device \"%s\"", argv[optind]);
            zram = new_zram(argv[optind++]);
            if (!zram_exist(zram))
                err(EXIT_FAILURE, "%s", zram->devname);
        }
        status(zram);
        free_zram(zram);
        break;
    case A_RESET:
        if (optind == argc)
            errx(EXIT_FAILURE, _("no device specified"));
        while (optind < argc) {
            DBG_BASIC("resetting device \"%s\"", argv[optind]);
            zram = new_zram(argv[optind]);
            if (!zram_exist(zram) ||
                zram_wait_initialized(zram) ||
                zram_lock(zram, LOCK_EX | LOCK_NB) ||
                (zram_unlock(zram), zram_set_u64parm(zram, "reset", 1))) {
                warn(_("%s: failed to reset"), zram->devname);
                rc = 1;
            }
            zram_control_remove(zram);
            free_zram(zram);
            optind++;
        }
        break;
    case A_FINDONLY:
        zram = find_free_zram();
        if (!zram)
            errx(EXIT_FAILURE, _("no free zram device found"));
        printf("%s\n", zram->devname);
        free_zram(zram);
        break;
    case A_CREATE:
        if (find) {
            zram = find_free_zram();
            if (!zram)
                errx(EXIT_FAILURE, _("no free zram device found"));
        } else if (optind == argc) {
            errx(EXIT_FAILURE, _("no device specified"));
        } else {
            zram = new_zram(argv[optind]);
            if (!zram_exist(zram))
                err(EXIT_FAILURE, "%s", zram->devname);
        }

        DBG_BASIC("creating/setting up device %s (size=%ju)", zram->devname, size);

        if (zram_wait_initialized(zram))
            err(EXIT_FAILURE, _("%s: failed to wait for initialized"), zram->devname);

        if (zram_lock(zram, LOCK_EX))
            err(EXIT_FAILURE, _("%s: failed to lock"), zram->devname);

        zram_unlock(zram);

        if (zram_set_u64parm(zram, "reset", 1))
            err(EXIT_FAILURE, _("%s: failed to reset"), zram->devname);

        if (nstreams &&
            zram_set_u64parm(zram, "max_comp_streams", nstreams) &&
            errno != ENOENT)
            err(EXIT_FAILURE, _("%s: failed to set number of streams"), zram->devname);

        if (algorithm &&
            zram_set_strparm(zram, "comp_algorithm", algorithm))
            err(EXIT_FAILURE, _("%s: failed to set algorithm"), zram->devname);

        if (algorithm_params &&
            zram_set_strparm(zram, "algorithm_params", algorithm_params))
            err(EXIT_FAILURE, _("%s: failed to set algorithm params"), zram->devname);

        if (zram_set_u64parm(zram, "disksize", size))
            err(EXIT_FAILURE, _("%s: failed to set disksize (%ju bytes)"),
                zram->devname, size);
        if (find)
            printf("%s\n", zram->devname);
        free_zram(zram);
        break;
    }

    DBG_BASIC("zramctl finished with rc=%d", rc ? EXIT_FAILURE : EXIT_SUCCESS);
    ul_unref_path(__control);
    return rc ? EXIT_FAILURE : EXIT_SUCCESS;
}

