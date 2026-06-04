#!/system/bin/sh
ip route add 10.0.0.0/8 dev tun0
ip route add 192.168.0.0/16 dev tun0
ip route add 0.0.0.0/1 dev tun0
ip route add 128.0.0.0/1 dev tun0
ip rule add pref 10 from all lookup main

