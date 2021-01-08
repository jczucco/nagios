#!/bin/bash
#
# A simple NRPE check to monitor the packetfence services
# by Jeronimo Zucco - Jan/08/2020
# Notes:
#       - Tested with Packetfence 10.2.0
# NRPE Exit Codes, for reference:
#       0: OK
#       1: WARNING
#       2: CRITICAL
#       3: UNKNOWN

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3


print_gpl() {
    echo "This program is free software; you can redistribute it and/or modify"
    echo "it under the terms of the GNU General Public License as published by"
    echo "the Free Software Foundation; either version 2 of the License, or"
    echo "(at your option) any later version."
    echo ""
    echo "This program is distributed in the hope that it will be useful,"
    echo "but WITHOUT ANY WARRANTY; without even the implied warranty of"
    echo "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the"
    echo "GNU General Public License for more details."
    echo ""
    echo "You should have received a copy of the GNU General Public License"
    echo "along with this program; if not, write to the Free Software"
    echo "Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA"
}

/usr/local/pf/bin/pfcmd service pf status > /tmp/pfservices.log

SERVICESOK=""
SERVICES_CRITICAL=""

for SERVICE in packetfence-api-frontend.service packetfence-config.service packetfence-fingerbank-collector.service packetfence-haproxy-admin.service packetfence-haproxy-portal
.service packetfence-httpd.aaa.service packetfence-httpd.admin_dispatcher.service packetfence-httpd.dispatcher.service packetfence-httpd.portal.service packetfence-httpd.webser
vices.service packetfence-iptables.service packetfence-keepalived.service packetfence-mariadb.service packetfence-netdata.service packetfence-pfacct.service packetfence-pfcertm
anager.service packetfence-pfcron.service packetfence-pfdetect.service packetfence-pfdhcp.service packetfence-pfdhcplistener.service packetfence-pfdns.service packetfence-pffil
ter.service packetfence-pfipset.service packetfence-pfperl-api.service packetfence-pfpki.service packetfence-pfqueue.service packetfence-pfsso.service packetfence-pfstats.servi
ce packetfence-radiusd-auth.service packetfence-radsniff.service packetfence-redis-cache.service packetfence-redis_queue.service packetfence-tc.service ; do
        STARTED=$(grep ^"${SERVICE}" /tmp/pfservices.log | grep started)
        [ "${STARTED}" ] || {
                SERVICES_CRITICAL=$(echo "${SERVICE} ${SERVICES_CRITICAL}")
        }
done

[ "${SERVICES_CRITICAL}" ] && {
        echo "CRITICAL - PacketFence service ${SERVICES_CRITICAL}"
        exit ${STATE_CRITICAL}
} || {
        echo "OK - PacketFence services"
        exit ${STATE_OK}
}
