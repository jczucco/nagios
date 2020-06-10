#! /bin/bash
#
# check_openvpn nagios nrpe plugin
#
# by Jeronimo Zucco <jczucco+nagios@gmail.com>
# Jun/10/2020
#
# This Nagios plugin was created to check the statistics of an OpenVPN server
# Tested with CentOS Linux release 7 and openvpn-2.4.9-1.el7.x86_64
#
# Licence: "GNU Public License v2"
# Dependencies: expr, grep, sed
#
# If you are running an OpenVPN server, you should be using this script ;-)
#
# Install netcat package and put in your openvpn server.conf the following lines:
#
# # management and statistics
# management 127.0.0.1 5555
#


PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION="0.1"

. $PROGPATH/utils.sh

OPENVPN_SERVER="127.0.0.1"
OPENVPN_MGMT_PORT="5555"


print_usage() {
  echo "Usage:"
  echo "  $PROGNAME"
  echo "  $PROGNAME --help"
  echo "  $PROGNAME --version"
}

print_help() {
  print_revision $PROGNAME $REVISION
  echo ""
  print_usage
  echo ""
  echo "This Nagios plugin was created to check the statistics of an OpenVPN server"
  echo ""
  echo "Set variables OPENVPN_SERVER and OPENVPN_MGMT_PORT in the script"
  echo ""
  echo "--help"
  echo "   Print this help screen"
  echo "--version"
  echo "   Print version and license information"
}

if [ $# -eq 0 ]
then
        STATUS=$(echo "load-stats" | nc ${OPENVPN_SERVER} ${OPENVPN_MGMT_PORT} | tail -n 1 )
        [ "${STATUS}" ] && {
                OK=$(echo "${STATUS}" | grep ^SUCCESS)
                [ "${OK}" ] && {
                        NUMCLIENTS=$(echo ${STATUS} | cut -d\, -f1 | cut -d\= -f2)
                        BYTESIN=$(echo ${STATUS} | cut -d\, -f2 | cut -d\= -f2)
                        BYTESOUT=$(echo ${STATUS} | cut -d\, -f3 | cut -d\= -f2)
                        echo "OK - OpenVPN ${NUMCLIENTS} users connected |Clients=${NUMCLIENTS};BytesIn=${BYTESIN};BytesOut=${BYTESOUT}"
                        exit $STATE_OK
                } || {
                        echo "CRITICAL - OpenVPN Server"
                        exit $STATE_CRITICAL
                } || {
                echo "CRITICAL - OpenVPN Server"
                exit $STATE_CRITICAL
                }
        } || {
                echo "CRITICAL - OpenVPN Server"
                exit $STATE_CRITICAL
        }
else
        print_help
fi
