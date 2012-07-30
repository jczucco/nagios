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
# Changelog:
# Apr/16/2012 by Leandro Lana: Support to tablespaces with autoextend enabled


PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION=`echo '$Revision: 1 $' | sed -e 's/[^0-9.]//g'`

. $PROGPATH/utils.sh

# set your Oracle environment here



print_usage() {
  echo "Usage:"
  echo "  $PROGNAME <USER> <PASS> <CRITICAL> <WARNING>"
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
    result=`sqlplus -s ${2}/${3} << EOF
    set lines 160
    set pages 0
select t.tablespace_name "Tablespace", trunc(round(ar.usado, 0),0) "Usado", round(decode(NVL2(cresc.tablespace, 0, sign(ar.Expansivel)),1,
                    (ar.livre + ar.expansivel), ar.livre), 0) "Livre", round(ar.alocado,0) "Alocado Mb",
                   NVL2(cresc.limite, 'ILIMITADO', round(ar.expansivel, 2)) "Expansivel",
                   round(decode(NVL2(cresc.tablespace, 0, sign(ar.Expansivel)), 1, ar.usado / (ar.total + ar.expansivel),
                    (ar.usado / ar.total)) * 100, 0) "Usado %", round(decode(NVL2(cresc.tablespace, 0, sign(ar.Expansivel)), 1,
                    (ar.livre + ar.expansivel) / (ar.total + ar.expansivel),
                    (ar.livre / ar.total)) * 100, 0) "Livre %", round(decode(NVL2(cresc.tablespace, 0, sign(ar.Expansivel)), 1,
                    (ar.total + ar.expansivel), ar.total), 2) "Total", t.Contents "Conteudo", t.Extent_Management "Tipo Ger."
       from dba_tablespaces t, (select df.tablespace_name tablespace,
               sum(nvl(df.user_bytes,0))/1024/1024 Alocado, (sum(df.bytes) - sum(NVL(df_fs.bytes, 0))) / 1024 / 1024 Usado,
               sum(NVL(df_fs.bytes, 0)) / 1024 / 1024 Livre,
               sum(decode(df.autoextensible, 'YES', decode(sign(df.maxbytes - df.bytes), 1, df.maxbytes - df.bytes, 0),
                          0)) / 1024 / 1024 Expansivel, sum(df.bytes) / 1024 / 1024 Total
       from dba_data_files df, (select tablespace_name, file_id, sum(bytes) bytes
                  from dba_free_space group by tablespace_name, file_id) df_fs
         where df.tablespace_name = df_fs.tablespace_name(+) and df.file_id = df_fs.file_id(+)
         group by df.tablespace_name
        union
        select tf.tablespace_name tablespace, sum(nvl(tf.user_bytes,0))/1024/1024 Alocado,        
               sum(tf_fs.bytes_used) / 1024 / 1024 Usado, sum(tf_fs.bytes_free) / 1024 / 1024 Livre,
               sum(decode(tf.autoextensible, 'YES', decode(sign(tf.maxbytes - tf.bytes), 1, tf.maxbytes - tf.bytes, 0),
                          0)) / 1024 / 1024 Expansivel, sum(tf.bytes) / 1024 / 1024 Total
          from dba_temp_files tf, V\\$TEMP_SPACE_HEADER tf_fs
         where tf.tablespace_name = tf_fs.tablespace_name and tf.file_id = tf_fs.file_id
         group by tf.tablespace_name) ar, (select df.tablespace_name tablespace, 'ILIMITADO' limite
          from dba_data_files df
         where df.maxbytes / 1024 / 1024 / 1024 > 30
           and df.autoextensible = 'YES'
         group by df.tablespace_name
        union
        select tf.tablespace_name tablespace, 'ILIMITADO' limite
          from dba_temp_files tf
         where tf.maxbytes / 1024 / 1024 / 1024 > 30
           and tf.autoextensible = 'YES'
         group by tf.tablespace_name) cresc
 where cresc.tablespace(+) = t.tablespace_name
   and ar.tablespace(+) = t.tablespace_name
   and t.tablespace_name='${4}';
EOF`


    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error"
      exit $STATE_CRITICAL
    fi

       ts_free=`echo "$result" |awk '{print $8}'`
       ts_total=`echo "$result" |awk '{print $7}'`
       ts_pct=`echo "$result" |awk '{print $6}'`
       ts_pctx=`echo "$result" |awk '{print $6}'`

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


result=`sqlplus -s ${2}/${3} << EOF
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

		

