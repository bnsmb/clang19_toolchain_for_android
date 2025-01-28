#! /system/bin/env bash
# Copyright Gerhard Rieger and contributors (see file CHANGES)
# Published under the GNU General Public License V.2, see file COPYING

# Shell script to build a chain of Socat instances connected via TCP sockets.
# This allows to drive, e.g., PROXY-CONNECT over SSL, or SSL over serial.
# Currently only a chain made from 3 addresses, resulting in two instances, is
# implemented.
# The 2nd address must be one of OPENSSL (SSL), PROXY-CONNECT (PROXY),
# SOCKS4, SOCKS4A, SOCKS5

# This is beta!

# Examples:

# Drive HTTP CONNECT (PROXY) over SSL
# (establish an SSL tunnel to a proxy server, request being forwarded to a
# telnet server):
#   socat-chain.sh \
#       STDIO \
#       PROXY::<telnet-server>:23 \
#       OPENSSL:<proxy-server>:8443

# Accept connections that arrive on port 7777, encrypt the data, and send it
# via socks server to final target:
#   socat-chain.sh \
#       TCP-L:7777,reuseaddr,fork \
#       OPENSSL,verify=0 \
#       SOCKS4:<socks-server>:<ssl-server>:8443

# Receive SSL coming from a serial lie
#   socat-chain.sh \
#       /dev/ttyS0,cfmakeraw \
#       SSL-L,cafile=server.pem,verify=0 \
#       TCP4:localhost:80

# Formally, this is what happens:
#   socat-chain.sh addr1 addr2 addr3
# results in something like:
#   socat TCP-L:RANDOM addr3 &
#   socat addr1 addr2:localhost:RANDOM
# or on passive/listening addr2:
#   socat addr2:RANDOM addr3 &
#   socat addr1 TCP:localhost:RANDOM

ECHO="echo -e"

usage () {
    $ECHO "Usage: $0 <options> <address1> <address2> <address3>"
    $ECHO "	<address1> is typically a passive (listening) address like"
    $ECHO "		TCP-L:1234"
    $ECHO "	<address2> must be one of OPENSSL, PROXY, SOCK4, SOCKS4A, or SOCKS5,"
    $ECHO "		or SSL-L (passive/listening)"
    $ECHO "		Given server hostname and port are ignored and replaced by internal"
    $ECHO "		communication point"
    $ECHO "	<address3> is typically a client address with protocol like OPENSSL"
    $ECHO "	<options>:"
    $ECHO "		-d*  -S <sigmask>  -t <timeout>  -T <timeout> 	are passed to socat"
    $ECHO "		-V	Shows executed Socat commands and some infos"
    $ECHO "Example to drive SOCKS over TLS:"
    $ECHO "	$0 \\"
    $ECHO "		TCP4-L:1234,reuseaddr,fork \\"
    $ECHO "		SOCKS::<server>:<port> \\"
    $ECHO "		OPENSSL:10.2.3.4:12345,cafile=..."
    $ECHO "	Clients that connect to port 1234 will be forwarded to <server>:<port> using socks"
    $ECHO "	over TLS"
}


LOCALHOST=127.0.0.1

VERBOSE= QUIET= OPTS=
while [ "$1" ]; do
    case "X$1" in
	X-h) usage; exit ;;
	X-V) VERBOSE=1 ;;
	X-q) QUIET=1; OPTS="-d0" ;;
	X-d*|X-l?*) OPTS="$OPTS $1" ;;
	X-b|X-S|X-t|X-T|X-l) OPT=$1; shift; OPTS="$OPTS $OPT $1" ;;
	X-) break ;;
	X-*) echo "$0: Unknown option \"$1\"" >&2
	     usage >&2
	     exit 1 ;;
	*) break ;;
    esac
    shift
done

ARG0="$1"
ARG1="$2"
ARG2="$3"

if [ -z "$ARG0" -o  -z "$ARG1" -o -z "$ARG2" ]; then
    echo "$0: Three addresses required" >&2
    usage >&2
    exit 1
fi


mkprogname () {
    ARG="$1"
    if [[ "$ARG" =~ .*[:].* ]]; then
	NAME="${ARG%%:*}"
    elif [[ "$ARG" =~ .*[,].* ]]; then
	NAME="${ARG%%,*}"
    elif [ "X$ARG" = X- ]; then
	NAME=stdio
    else
	NAME="$ARG"
    fi
    NAME="${NAME,,*}"
    echo $NAME
}


# You may place a fork option in the first address
# in which case the following internal listeners do fork too
FORK=
case "$ARG0" in
    *,fork,*|*,fork) FORK=fork ;;
esac

# Split middle address for insertion of additional parts
if [[ "$ARG1" =~ .*,.* ]]; then
    ARG1A="${ARG1%%,*}"
    ARG1B="${ARG1#*,}"
else
    ARG1A="$ARG1"
    ARG1B=
fi

case "$0" in
    */*) if [ -x ${0%/*}/socat ]; then SOCAT=${0%/*}/socat; fi ;;
esac
if [ -z "$SOCAT" ]; then SOCAT=socat; fi
[ "$VERBOSE" ] && echo "# $0: Using executable $SOCAT" >&2

# We need a free TCP port (on loopback)
PORT=$($SOCAT -d -d TCP4-L:0,accept-timeout=0.000001 /dev/null 2>&1 |grep listening |sed 's/.*:\([1-9][0-9]*\)$/\1/')
if [ -z "$PORT" ]; then
    echo "$0: Failed to determine free TCP port" >&2
    exit 1
fi

PASSIVE= 	# is the second address passive/listening/server?
case "${ARG1A^^*}" in
    OPENSSL|OPENSSL:*|SSL|SSL:.*)
	OPTS1A=
	#if [[ $ARG1A =~ ^\([^:]*\):\([^:]*\):\([^,]*\)\(.*\) ]]; then 	# bash 3
	if [[ $ARG1A =~ ^([^:]*):([^:]*):([^,]*)(.*) ]]; then
	    OPTS1A="${BASH_REMATCH[4]}"
	#elif [[ $ARG1A =~ ^\([^,]*\)\(.*\) ]]; then 			# bash 3
	elif [[ $ARG1A =~ ^([^,]*)(.*) ]]; then
	    OPTS1A="${BASH_REMATCH[2]}"
	else
	    echo "$0: \"$ARG1A\": invalid arguments" >&2
	    exit 1
	fi
	PROG1="${BASH_REMATCH[1]}"
	NAME1=$(mkprogname "${BASH_REMATCH[1]}")
	NAME2=$(mkprogname "$ARG2")
	ARG1A=$PROG1:$LOCALHOST:$PORT$OPTS1A ;;
    PROXY-CONNECT:*|PROXY:*)
	#if ! [[ $ARG1A =~ ^\([^:]*\):\([^:]*\):\([^:]*\):\([^,]*\)\(.*\) ]]; then 	# bash 3
	if ! [[ $ARG1A =~ ^([^:]*):([^:]*):([^:]*):([^,]*)(.*) ]]; then
	    echo "$0: \"$ARG1A\": invalid arguments" >&2
	    exit 1
	fi
	#echo "0:\"${BASH_REMATCH[0]}\" 1:\"${BASH_REMATCH[1]}\" 2:\"${BASH_REMATCH[2]}\" 3:\"${BASH_REMATCH[3]}\" 4:\"${BASH_REMATCH[4]}\""
	PROG1="${BASH_REMATCH[1]}"
	NAME1=$(mkprogname "${PROG1,,*}")
	NAME2=$(mkprogname "$ARG2")
	OPTS1A="${BASH_REMATCH[5]}"
	ARG1A="$PROG1:$LOCALHOST:${BASH_REMATCH[3]}:${BASH_REMATCH[4]},proxyport=$PORT,$OPTS1A" ;;
    SOCKS:*|SOCKS4:*|SOCKS4A*)
	#if ! [[ $ARG1A =~ ^\([^:]*\):\([^:]*\):\([^:]*\):\([^:,]*\),* ]]; then 	# bash 3
	if ! [[ $ARG1A =~ ^([^:]*):([^:]*):([^:]*):([^:,]*),* ]]; then
	    echo "$0: \"$ARG1A\": invalid arguments" >&2
	    exit 1
	fi
	PROG1="${BASH_REMATCH[1]}"
	NAME1=$(mkprogname "${PROG1,,*}")
	NAME2=$(mkprogname "$ARG2")
	OPTS1A="${BASH_REMATCH[5]}"
	ARG1A="$PROG1:$LOCALHOST:${BASH_REMATCH[3]}:${BASH_REMATCH[4]},socksport=$PORT,$OPTS1A" ;;
    SOCKS5:*|SOCKS5-CONNECT*)
	#if ! [[ $ARG1A =~ ^\([^:]*\):\([^:]*\):\([^:]*\):\([^:,]*\):\([^:,]*\),* ]]; then 	# bash 3
	if ! [[ $ARG1A =~ ^([^:]*):([^:]*):([^:]*):([^:,]*):([^:,]*),* ]]; then
	    echo "$0: \"$ARG1A\": invalid arguments" >&2
	    exit 1
	fi
	PROG1="${BASH_REMATCH[1]}"
	NAME1=$(mkprogname "${PROG1,,*}")
	NAME2=$(mkprogname "$ARG2")
	OPTS1A="${BASH_REMATCH[6]}"
	ARG1A="$PROG1:$LOCALHOST:$PORT:${BASH_REMATCH[4]}:${BASH_REMATCH[5]},$OPTS1A" ;;
    # Passive (server) addresses
    OPENSSL-LISTEN|OPENSSL-LISTEN:*|SSL-L|SSL-L:.*)
	PASSIVE=1
	OPTS1A=
	#if [[ $ARG1A =~ ^\([^:]*\):\([^,]*\)\(.*\) ]]; then 	# bash 3
	if [[ $ARG1A =~ ^([^:]*):([^,]*)(.*) ]]; then
	    OPTS1A="${BASH_REMATCH[3]}"
	#elif [[ $ARG1A =~ ^\([^,]*\)\(.*\) ]]; then 		# bash 3
	elif [[ $ARG1A =~ ^([^,]*)(.*) ]]; then
	    OPTS1A="${BASH_REMATCH[2]}"
	else
	    echo "$0: \"$ARG1A\": invalid arguments" >&2
	    exit 1
	fi
	PROG1="${BASH_REMATCH[1]}"
	NAME1=$(mkprogname "$ARG0")
	NAME2=$(mkprogname "${BASH_REMATCH[1]}")
	ARG1A=$PROG1:$PORT$OPTS1A ;;
    *) echo "$0: Unsupported address \"$ARG1A\"" >&2
       usage >&2
       exit 1 ;;
esac

ADDR1A="$ARG0"
if [ -z "$PASSIVE" ]; then
    ADDR1B="$ARG1A,bind=$LOCALHOST,$ARG1B"
    ADDR2A="TCP4-L:$PORT,reuseaddr,$FORK,bind=$LOCALHOST,range=$LOCALHOST/32"
else
    ADDR1B="TCP4:$LOCALHOST:$PORT,bind=$LOCALHOST"
    ADDR2A="$ARG1A,reuseaddr,$FORK,bind=$LOCALHOST,range=$LOCALHOST/32,$ARG1B"
fi
ADDR2B="$ARG2"


pid1= pid2=
trap '[ "$pid1" ] && kill $pid1 2>/dev/null; [ "$pid2" ] && kill $pid2 2>/dev/null' EXIT

set -bm
trap 'rc=$?; if ! kill -n 0 $pid2 2>/dev/null; then [ -z "$QUIET" -a $rc -ne 0 ] && echo "$0: socat-$NAME2 exited with rc=$rc" >&2; exit $rc; fi' SIGCHLD

# Start instance 2 first, because instance 1 ("left") connects to 2
if [ "$VERBOSE" ]; then
    $ECHO "$SOCAT $OPTS -lp socat-$NAME2 \\
	\"$ADDR2A\" \\
	\"$ADDR2B\" &"
fi
$SOCAT $OPTS -lp socat-$NAME2 \
	"$ADDR2A" \
	"$ADDR2B" &
pid2=$!
sleep 0.1

#trap 'if ! kill -n 0 $pid1 2>/dev/null; then [ -z "$QUIET" ] && echo "$0: socat-$NAME1 exited with rc=$?" >&2; kill $pid2 2>/dev/null; exit 1; elif ! kill -n 0 $pid2 2>/dev/null; then [ -z "$QUIET" ] && echo "$0: socat-$NAME2 exited with rc=$?" >&2; kill $pid1 2>/dev/null; exit 1; fi' SIGCHLD

if [ "$VERBOSE" ]; then
    $ECHO "$SOCAT $OPTS -lp socat-$NAME1 \\
	\"$ADDR1A\" \\
	\"$ADDR1B\""
fi
$SOCAT $OPTS -lp socat-$NAME1 \
	"$ADDR1A" \
	"$ADDR1B"
#pid1=$!
rc1=$?

kill $pid2 2>/dev/null
wait 2>/dev/null
#wait -f

exit $rc1
