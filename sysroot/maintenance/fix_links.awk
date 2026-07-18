#!/usr/bin/awk -f

{
    if (match($0, /tar: can't link '([^']+)' -> '([^']+)': Permission denied/, m)) {
        src = m[1]
        dst = m[2]

        n = split(src, s, "/")
        srcbase = s[n]

        n = split(dst, d, "/")
        dstbase = d[n]

        system("rm -f '" src "'")
        system("ln -s '" dstbase "' '" src "'")
    }
}
