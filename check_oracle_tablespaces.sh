#! /bin/sh
#
# Jeronimo Zucco - jczucco at gmail dot com
# Enor Paim - enorpaim at gmail dot com
#
# based on work of latigid010@yahoo.com in check_oracle plugin
# 2008-06-26
#
#  This Nagios plugin was created to check all Oracle Table Space status
#


PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION=`echo '$Revision: 1 $' | sed -e 's/[^0-9.]//g'`

. $PROGPATH/utils.sh

# set your Oracle environment here
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=$ORACLE_BASE/product/10.2.0
export ORACLE_SID=desenv
export ORACLE_TERM=xterm
export PATH=/usr/sbin:$PATH
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export NLS_LANG=PORTUGUESE_BRAZIL.we8iso8859p1


print_usage() {
  echo "Usage:"
  echo "  $PROGNAME <ORACLE_SID> <USER> <PASS> <CRITICAL> <WARNING>"
  echo "  $PROGNAME --help"
  echo "  $PROGNAME --version"
}

print_help() {
  print_revision $PROGNAME $REVISION
  echo ""
  print_usage
  echo ""
  echo "   Check local database for tablespace capacity in ORACLE_SID"
  echo "       --->  Requires Oracle user/password specified."
  echo "                --->  Requires select on dba_data_files and dba_free_space"
  echo "--help"
  echo "   Print this help screen"
  echo "--version"
  echo "   Print version and license information"
  echo ""
  echo "If the plugin doesn't work, check that the ORACLE_HOME environment"
  echo "variable is set, that ORACLE_HOME/bin is in your PATH, and the"
  echo "tnsnames.ora file is locatable and is properly configured."
  echo ""
  echo "When checking local database status your ORACLE_SID is case sensitive."
  echo ""
  echo "If you want to use a default Oracle home, add in your oratab file:"
  echo "*:/opt/app/oracle/product/7.3.4:N"
  echo ""
  support
}

check_tablespace() {
    if [ ${5} -lt ${6} ] ; then
        echo "UNKNOWN - Warning level is more then Crit"
        exit $STATE_UNKNOWN
    fi
    result=`sqlplus -s ${2}/${3}@${1} << EOF
set pagesize 0
set numf '9999999.99'
select NVL(b.free,0.0),a.total,100 - trunc(NVL(b.free,0.0)/a.total * 1000) / 10 prc
from (
select tablespace_name,sum(bytes)/1024/1024 total
from dba_data_files group by tablespace_name) A
LEFT OUTER JOIN
( select tablespace_name,sum(bytes)/1024/1024 free
from dba_free_space group by tablespace_name) B
ON a.tablespace_name=b.tablespace_name WHERE a.tablespace_name='${4}';
EOF`


    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error"
      exit $STATE_CRITICAL
    fi

    ts_free=`echo "$result" | awk '/^[ 0-9\.\t ]+$/ {print int($1)}'`
    ts_total=`echo "$result" | awk '/^[ 0-9\.\t ]+$/ {print int($2)}'`
    ts_pct=`echo "$result" | awk '/^[ 0-9\.\t ]+$/ {print int($3)}'`
    ts_pctx=`echo "$result" | awk '/^[ 0-9\.\t ]+$/ {print $3}'`
    if [ "$ts_free" -eq 0 -a "$ts_total" -eq 0 -a "$ts_pct" -eq 0 ] ; then
        echo "No data returned by Oracle - tablespace $5 not found?"
        exit $STATE_UNKNOWN
    fi
    if [ "$ts_pct" -ge ${5} ] ; then
        #echo "${2} : ${5} CRITICAL - $ts_pctx% used [ $ts_free / $ts_total MB available ]|${4}=$ts_pctx%;${6};${5};0;100"
	ERROR=$(echo "${ERROR}${4} ")
	return
    fi
    if [ "$ts_pct" -ge ${6} ] ; then
        #echo "${2} : ${4} WARNING  - $ts_pctx% used [ $ts_free / $ts_total MB available ]|${4}=$ts_pctx%;${6};${5};0;100"
	WARNING=$(echo "${WARNING}${4} ")
	return
    fi
    #echo "${2} : ${4} OK - $ts_pctx% used [ $ts_free / $ts_total MB available ]|${4}=$ts_pctx%;${6};${5};0;100"


}

case "$1" in
--help)
                print_help
    exit $STATE_OK
    ;;
-h)
                print_help
    exit $STATE_OK
    ;;
--version)
                print_revision $PROGNAME $REVISION
    exit $STATE_OK
    ;;
-V)
                print_revision $PROGNAME $REVISION
    exit $STATE_OK
    ;;
esac


# Hunt down a reasonable ORACLE_HOME
if [ -z "$ORACLE_HOME" ] ; then
        # Adjust to taste
        for oratab in /var/opt/oracle/oratab /etc/oratab
        do
        [ ! -f $oratab ] && continue
        ORACLE_HOME=`IFS=:
                while read SID ORACLE_HOME junk;
                do
                        if [ "$SID" = "$2" -o "$SID" = "*" ] ; then
                                echo $ORACLE_HOME;
                                exit;
                        fi;
                done < $oratab`
        [ -n "$ORACLE_HOME" ] && break
        done
fi
# Last resort
[ -z "$ORACLE_HOME" -a -d $PROGPATH/oracle ] && ORACLE_HOME=$PROGPATH/oracle

if [ "$cmd" != "--db" ]; then
        if [ -z "$ORACLE_HOME" -o ! -d "$ORACLE_HOME" ] ; then
                echo "Cannot determine ORACLE_HOME for sid $2"
                exit $STATE_UNKNOWN
        fi
fi


result=`sqlplus -s ${2}/${3}@${1} << EOF
set pagesize 0
set feedback off
select distinct tablespace_name from dba_data_files order by 1;
EOF`

ERROR=""
WARNING=""

for TABLESPACE in $result; do
        check_tablespace ${1} ${2} ${3} ${TABLESPACE} ${4} ${5}
done

[ "${ERROR}" ] && {
	echo "CRITICAL - Tablespace(s) ${ERROR}${WARNING}"
	exit $STATE_CRITICAL
} || {
	[ "${WARNING}" ] && {
		echo "WARNING - Tablespace(s) ${WARNING}"
        	exit $STATE_WARNING
	} || {
		echo "OK"
    		exit $STATE_OK
	}	
}

		

