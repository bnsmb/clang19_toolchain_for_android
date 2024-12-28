# simple script to keep the Wifi connection alive
#
# (you might change the IP address to a valid one for your environment)
#
ping -i 0.2 192.168.1.1 >/dev/null &                                      
if [ $? -eq 0 ] ; then
  echo "Started a ping command in the backbround; the PID of the process is $!"
  ps -f -p $!
fi


