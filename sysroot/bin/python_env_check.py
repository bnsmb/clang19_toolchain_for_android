#!/data/local/tmp/sysroot/usr/bin/python

##!/system/bin/env python3
"""
stdlib-only Python installation self-test.

Usage:
  python3 python_env_check.py
  python3 python_env_check.py --network   # additionally test HTTPS/certificate validation
  python3 python_env_check.py --json      # machine-readable summary

No third-party packages are required. The network test is opt-in.
"""
import argparse
import importlib
import importlib.util
import json
import locale
import marshal
import os
import pathlib
import platform
import py_compile
import site
import socket
import subprocess
import sys
import sysconfig
import tempfile
import threading
import traceback
import urllib.request
from dataclasses import dataclass, asdict


# ---------------------------------------------------------------------------
# Environment detection
# ---------------------------------------------------------------------------

def is_android():
    """Heuristik: Android-Umgebung erkennen (Termux, /system/bin, sysroot)."""
    if "ANDROID_ROOT" in os.environ or "ANDROID_DATA" in os.environ:
        return True
    if hasattr(sys, "getandroidapilevel"):
        return True
    # Termux setzt PREFIX=/data/data/com.termux/files/usr
    prefix = os.environ.get("PREFIX", "")
    if "/com.termux/" in prefix:
        return True
    # Letzter Fallback: Plattform-String
    if "android" in platform.platform().lower():
        return True
    return False


IS_ANDROID = is_android()


# ---------------------------------------------------------------------------
# Mini test harness
# ---------------------------------------------------------------------------

@dataclass
class Result:
    name: str
    status: str
    detail: str = ""
    required: bool = True


RESULTS = []


def record(name, status, detail="", required=True):
    RESULTS.append(Result(name, status, str(detail), required))


def check(name, fn, required=True):
    try:
        detail = fn()
        record(name, "PASS", "" if detail is None else detail, required)
    except Exception as exc:
        record(name, "FAIL" if required else "WARN", f"{type(exc).__name__}: {exc}", required)


def skip(name, detail, required=False):
    record(name, "SKIP", detail, required)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_runtime():
    return (
        f"implementation={platform.python_implementation()}, "
        f"version={sys.version.split()[0]}, "
        f"executable={sys.executable!r}, "
        f"prefix={sys.prefix!r}, base_prefix={getattr(sys, 'base_prefix', '')!r}, "
        f"platform={sys.platform}, machine={platform.machine()}, "
        f"android={IS_ANDROID}"
    )


def test_sysconfig():
    paths = sysconfig.get_paths()
    missing = []
    for key in ("stdlib", "platstdlib"):
        p = paths.get(key)
        if p and not os.path.isdir(p):
            missing.append(f"{key}={p}")
    if missing:
        raise RuntimeError("Configured standard-library path(s) missing: " + ", ".join(missing))
    return " | ".join(
        f"{k}={paths.get(k)}"
        for k in ("stdlib", "platstdlib", "purelib", "platlib", "scripts")
    )


def test_sys_path():
    absent = [p for p in sys.path if p and not os.path.exists(p)]
    # Empty sys.path entries mean the current directory and are valid.
    if absent:
        return f"{len(absent)} sys.path entr(y/ies) do not currently exist: {absent}"
    return f"{len(sys.path)} entries; all existing"


def test_site():
    user_site = site.getusersitepackages()
    user_base = site.getuserbase()
    return (
        f"ENABLE_USER_SITE={getattr(site, 'ENABLE_USER_SITE', None)}, "
        f"USER_BASE={user_base!r}, USER_SITE={user_site!r}, "
        f"user_site_exists={os.path.isdir(user_site) if isinstance(user_site, str) else 'n/a'}"
    )


def test_stdlib_imports():
    # Core modules are required. Some extension modules are optional in
    # custom/minimal builds (notably Android), so they live in the optional test.
    required = [
        "abc", "argparse", "array", "asyncio", "base64", "binascii", "builtins",
        "bz2", "calendar", "codecs", "collections", "concurrent.futures",
        "configparser", "contextlib", "copy", "csv", "dataclasses", "datetime",
        "decimal", "email", "enum", "fnmatch", "functools", "hashlib", "heapq",
        "hmac", "html", "http", "importlib", "inspect", "io", "ipaddress",
        "itertools", "json", "logging", "math", "operator", "pathlib", "pickle",
        "platform", "plistlib", "pprint", "queue", "random", "re", "shlex",
        "shutil", "signal", "socket", "sqlite3", "statistics", "string",
        "struct", "subprocess", "sysconfig", "tarfile", "tempfile", "textwrap",
        "threading", "time", "traceback", "types", "typing", "unicodedata",
        "unittest", "urllib.parse", "urllib.request", "uuid", "warnings", "weakref",
        "xml.etree.ElementTree", "zipfile", "zlib",
    ]
    failed = []
    for name in required:
        try:
            importlib.import_module(name)
        except Exception as exc:
            failed.append(f"{name}: {type(exc).__name__}: {exc}")
    if failed:
        raise RuntimeError("; ".join(failed))
    return f"{len(required)} standard-library modules imported successfully"


def test_optional_modules():
    optional = [
        "ssl", "ctypes", "lzma", "readline", "fcntl", "select",
        "resource", "venv", "ensurepip", "multiprocessing", "termios",
    ]
    found, missing = [], []
    for name in optional:
        try:
            importlib.import_module(name)
            found.append(name)
        except Exception as exc:
            missing.append(f"{name} ({type(exc).__name__}: {exc})")
    return f"available={found}; unavailable/failed={missing}"


def test_compile():
    source = "def f(x):\n    return x * 2\nassert f(21) == 42\n"

    with tempfile.TemporaryDirectory(prefix="pycheck-") as d:
        src = os.path.join(d, "sample.py")
        with open(src, "w", encoding="utf-8") as f:
            f.write(source)

        pyc = py_compile.compile(src, doraise=True)

        if not os.path.isfile(pyc):
            raise RuntimeError(f"bytecode file was not created: {pyc}")
        if os.path.getsize(pyc) == 0:
            raise RuntimeError(f"bytecode file is empty: {pyc}")

        # Verify that the generated bytecode can actually be loaded.
        with open(pyc, "rb") as f:
            f.read(16)  # PEP 552 header (magic + flags + timestamp/hash)
            code = marshal.load(f)

        namespace = {}
        exec(code, namespace)

        if namespace["f"](21) != 42:
            raise RuntimeError("compiled bytecode returned an incorrect result")

    return f"source compilation, bytecode loading and execution succeeded: {pyc}"


def test_tempfile_io():
    with tempfile.TemporaryDirectory(prefix="pycheck-") as d:
        p = pathlib.Path(d) / "sample.txt"
        payload = "Python self-test: Grüße ✓\n"
        p.write_text(payload, encoding="utf-8")
        if p.read_text(encoding="utf-8") != payload:
            raise RuntimeError("text round-trip mismatch")
        q = pathlib.Path(d) / "renamed.txt"
        p.rename(q)
        if not q.is_file():
            raise RuntimeError("rename failed")
    return "temporary directory, UTF-8 read/write and rename succeeded"


def test_json_roundtrip():
    obj = {"a": 1, "b": [1, 2, 3], "c": "ü", "d": {"nested": True}}
    s = json.dumps(obj, ensure_ascii=False)
    if json.loads(s) != obj:
        raise RuntimeError("JSON round-trip mismatch")
    return "JSON encode/decode round-trip succeeded"


def test_sqlite():
    import sqlite3
    with sqlite3.connect(":memory:") as db:
        db.execute("create table t (v integer)")
        db.execute("insert into t values (?)", (42,))
        value = db.execute("select v from t").fetchone()[0]
    if value != 42:
        raise RuntimeError(f"unexpected query result: {value!r}")
    return f"SQLite {sqlite3.sqlite_version}; in-memory query succeeded"


def test_hashes():
    import hashlib
    got = hashlib.sha256(b"abc").hexdigest()
    expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    if got != expected:
        raise RuntimeError(f"SHA-256 result mismatch: {got}")
    return "SHA-256 known-answer test passed"


def test_subprocess():
    code = "import sys; print(sys.version_info.major, sys.version_info.minor)"
    cp = subprocess.run(
        [sys.executable, "-c", code],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, timeout=15, check=False,
    )
    if cp.returncode != 0:
        raise RuntimeError(f"child exit={cp.returncode}; stderr={cp.stderr.strip()}")
    if not cp.stdout.strip().startswith(str(sys.version_info.major)):
        raise RuntimeError(f"unexpected child output: {cp.stdout!r}")
    return f"child interpreter ran: {cp.stdout.strip()!r}"


def test_threading():
    result = []
    t = threading.Thread(target=lambda: result.append(42), daemon=True)
    t.start()
    t.join(timeout=5)
    if t.is_alive() or result != [42]:
        raise RuntimeError(f"thread did not complete correctly: {result!r}")
    return "thread creation, execution and join succeeded"


def test_loopback_socket():
    # Does not access the Internet; uses only localhost.
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.settimeout(3)
        server.bind(("127.0.0.1", 0))
        server.listen(1)
        server.settimeout(3)
        port = server.getsockname()[1]
        errors = []

        def client():
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=3) as s:
                    s.sendall(b"ping")
                    if s.recv(4) != b"pong":
                        raise RuntimeError("bad reply")
            except Exception as exc:
                errors.append(exc)

        t = threading.Thread(target=client, daemon=True)
        t.start()
        conn, _ = server.accept()
        with conn:
            conn.settimeout(3)
            if conn.recv(4) != b"ping":
                raise RuntimeError("bad request")
            conn.sendall(b"pong")
        t.join(timeout=4)
        if t.is_alive():
            raise RuntimeError("client thread timed out")
        if errors:
            raise errors[0]
    return f"TCP loopback request/reply succeeded on ephemeral port {port}"


def test_ssl_import():
    import ssl
    if not hasattr(ssl, "SSLContext") or not hasattr(ssl, "create_default_context"):
        raise RuntimeError("SSLContext/create_default_context missing")
    ctx = ssl.create_default_context()
    ciphers = ctx.get_ciphers()
    if not ciphers:
        raise RuntimeError("no TLS ciphers available")
    return (
        f"{ssl.OPENSSL_VERSION}; {len(ciphers)} ciphers; "
        f"default verify_mode={ctx.verify_mode}, check_hostname={ctx.check_hostname}"
    )


def test_cert_paths():
    import ssl
    paths = ssl.get_default_verify_paths()
    candidates = [paths.cafile, paths.capath, paths.openssl_cafile, paths.openssl_capath]
    existing = [p for p in candidates if p and os.path.exists(p)]
    if not existing:
        raise RuntimeError(f"no default CA file/directory found; paths={paths}")
    return f"default_verify_paths={paths}; existing={existing}"


def test_https():
    url = "https://www.python.org/"
    req = urllib.request.Request(url, headers={"User-Agent": "python-stdlib-selftest/1.0"})
    with urllib.request.urlopen(req, timeout=12) as response:
        if response.status < 200 or response.status >= 400:
            raise RuntimeError(f"HTTP status {response.status}")
        return (
            f"HTTPS certificate verification succeeded; "
            f"status={response.status}; final_url={response.geturl()}"
        )


def test_multiprocessing():
    """
    Nur ausführen, wenn NICHT auf Android.
    Android hat kein POSIX-fork und häufig kein sem_open/`/dev/shm`,
    daher scheitert multiprocessing dort typischerweise beim Start.
    """
    import multiprocessing

    def worker(q):
        q.put(42)

    # 'fork' ist auf Android nicht verfügbar; 'spawn' braucht ein
    # importierbares Modul und funktioniert im __main__-Kontext nur eingeschränkt.
    ctx = multiprocessing.get_context("fork")
    q = ctx.Queue()
    p = ctx.Process(target=worker, args=(q,))
    p.start()
    p.join(timeout=10)
    if p.exitcode != 0:
        raise RuntimeError(f"child exitcode={p.exitcode}")
    if q.get(timeout=5) != 42:
        raise RuntimeError("unexpected queue value")
    return f"multiprocessing via 'fork' succeeded (start method={ctx.get_start_method()})"


def test_locale_basic():
    """
    Weicher Check: Locale muss *ladbar* sein, aber wir erzwingen kein UTF-8,
    da Android-Minimalbuilds oft nur 'C' kennen.
    """
    try:
        locale.setlocale(locale.LC_ALL, "")
    except locale.Error:
        # Das ist tolerierbar – wir nehmen den aktuellen Zustand als Info.
        pass
    enc = locale.getpreferredencoding(False)
    if sys.getdefaultencoding().lower() != "utf-8":
        raise RuntimeError(f"sys.getdefaultencoding()={sys.getdefaultencoding()!r}, expected 'utf-8'")
    return f"preferred_encoding={enc!r}, sys.getdefaultencoding={sys.getdefaultencoding()!r}"


def test_build_config_vars():
    """Überprüfen Sie, ob kritische Build-Optionen wirksam sind."""
    checks = []
    # --enable-shared
    shared = sysconfig.get_config_var('Py_ENABLE_SHARED')
    checks.append(f"Py_ENABLE_SHARED={shared}")
    
    # --with-builtin-hashlib-hashes
    hashes = sysconfig.get_config_var('PY_HASHLIB_HASHES')
    checks.append(f"PY_HASHLIB_HASHES={hashes!r}")
    
    # --with-tzpath
    tzpath = sysconfig.get_config_var('TZPATH')
    checks.append(f"TZPATH={tzpath!r}")
    
    return "; ".join(checks)

def test_tzpath():
    """Überprüfen Sie, ob --with-tzpath das konfigurierte Verzeichnis tatsächlich findet."""
    tzpath = sysconfig.get_config_var('TZPATH') or ""
    candidates = [p for p in tzpath.split(':') if p and os.path.isdir(p)]
    if not candidates:
        raise RuntimeError(f"TZPATH configured but no directory found: {tzpath!r}")
    # Prüfen Sie, ob eine bekannte Zeitzonendatei existiert
    probe = os.path.join(candidates[0], "UTC")
    if not os.path.exists(probe):
        # UTC könnte ein Symlink sein; versuchen Sie eine andere
        for p in candidates:
            if os.path.exists(os.path.join(p, "UTC")):
                probe = os.path.join(p, "UTC")
                break
    return f"TZPATH dirs: {candidates}; probe UTC exists={os.path.exists(probe)}"

def test_extension_module_paths():
    """Überprüfen Sie, ob wichtige Erweiterungsmodule aus dem sysroot geladen werden."""
    modules = ["_ssl", "_sqlite3", "_hashlib", "_decimal"]
    details = []
    for name in modules:
        mod = sys.modules.get(name)
        if mod is None:
            try:
                mod = importlib.import_module(name)
            except Exception as exc:
                details.append(f"{name}: import failed ({exc})")
                continue
        path = getattr(mod, "__file__", None)
        if path:
            # Prüfen Sie, ob unter dem von Ihnen konfigurierten Prefix
            in_sysroot = "/data/local/tmp/sysroot" in path
            details.append(f"{name}: {path} (in_sysroot={in_sysroot})")
        else:
            details.append(f"{name}: builtin (no __file__)")
    return "; ".join(details)

def test_linker_flags():
    """Überprüfen Sie, ob kritische Linker-Flags wirksam sind."""
    ldflags = sysconfig.get_config_var('PY_LDFLAGS') or ""
    ldflags_ndist = sysconfig.get_config_var('PY_LDFLAGS_NODIST') or ""
    combined = f"{ldflags} {ldflags_ndist}"
    
    checks = []
    if "--no-rosegment" in combined:
        checks.append("no-rosegment: yes")
    if "max-page-size=16384" in combined:
        checks.append("max-page-size=16384: yes")
    if "build-id=sha1" in combined:
        checks.append("build-id=sha1: yes")
    
    if not checks:
        raise RuntimeError(f"No expected linker flags found in: {combined!r}")
    return "; ".join(checks)

def test_ensurepip_disabled():
    """Überprüfen Sie, ob --without-ensurepip wirksam ist."""
    spec = importlib.util.find_spec("ensurepip")
    if spec is not None:
        # Auch wenn es gefunden wird, ist möglicherweise eine leere Hülle; versuchen Sie den Import
        try:
            import ensurepip
            # Wenn der Import erfolgreich ist, prüfen Sie, ob es ein echtes Modul ist
            if hasattr(ensurepip, "version"):
                raise RuntimeError("ensurepip is available despite --without-ensurepip")
        except ImportError:
            pass
    return "ensurepip not importable (as expected with --without-ensurepip)"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Check a Python runtime using only the standard library."
    )
    parser.add_argument("--network", action="store_true",
                        help="test outbound HTTPS and certificate validation")
    parser.add_argument("--json", action="store_true",
                        help="print JSON results")
    args = parser.parse_args()

    print("Python environment self-test")
    print("=" * 28)
    print(f"Executable: {sys.executable}")
    print(f"Version:    {sys.version.replace(chr(10), ' ')}")
    print(f"Platform:   {platform.platform()}")
    print(f"Android:    {IS_ANDROID}")
    print()

    check("runtime metadata", test_runtime)
    check("sysconfig paths", test_sysconfig)
    check("sys.path", test_sys_path, required=False)
    check("site configuration", test_site)
    check("standard-library imports", test_stdlib_imports)
    check("optional modules", test_optional_modules, required=False)
    check("source compilation / bytecode", test_compile)
    check("temporary filesystem I/O", test_tempfile_io)
    check("JSON round-trip", test_json_roundtrip)
    check("SQLite", test_sqlite)
    check("hash implementation", test_hashes)
    check("subprocess child interpreter", test_subprocess)
    check("threading", test_threading)
    check("TCP loopback", test_loopback_socket, required=False)
    check("SSL/TLS module", test_ssl_import)
    check("default CA paths", test_cert_paths, required=False)
    check("locale basics", test_locale_basic, required=False)

    check("build config vars", test_build_config_vars)
    check("tzpath", test_tzpath)
    check("extension module paths", test_extension_module_paths, required=False)
    check("linker flags", test_linker_flags, required=False)
    check("ensurepip disabled", test_ensurepip_disabled, required=False)

    # multiprocessing: auf Android auslassen, sonst Pflicht-Test
    if IS_ANDROID:
        skip("multiprocessing",
             "skipped on Android (no POSIX fork / sem_open, /dev/shm often missing)")
    else:
        check("multiprocessing", test_multiprocessing)

    if args.network:
        check("outbound HTTPS + certificate validation", test_https, required=False)
    else:
        skip("outbound HTTPS + certificate validation",
             "not run (pass --network to enable)")

    if args.json:
        print(json.dumps({
            "python": {
                "executable": sys.executable,
                "version": sys.version,
                "prefix": sys.prefix,
                "base_prefix": getattr(sys, "base_prefix", None),
                "platform": sys.platform,
                "machine": platform.machine(),
                "android": IS_ANDROID,
            },
            "results": [asdict(r) for r in RESULTS],
        }, indent=2))
    else:
        print("Results")
        print("-------")
        for r in RESULTS:
            suffix = f" — {r.detail}" if r.detail else ""
            print(f"{r.status:4} {'[required]' if r.required else '[optional]':10} {r.name}{suffix}")
        failed = sum(r.status == "FAIL" and r.required for r in RESULTS)
        warned = sum(r.status == "WARN" for r in RESULTS)
        skipped = sum(r.status == "SKIP" for r in RESULTS)
        print()
        print(f"Summary: {len(RESULTS)} checks; required failures={failed}; "
              f"warnings={warned}; skipped={skipped}")
        print("Note: optional components and platform-specific capabilities "
              "can legitimately be unavailable.")

    return 1 if any(r.status == "FAIL" and r.required for r in RESULTS) else 0


if __name__ == "__main__":
    raise SystemExit(main())

