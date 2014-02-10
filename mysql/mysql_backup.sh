#!/bin/bash

## DO NOT EDIT
## This file is under PUPPET control

########################################
###                                  ###
### Script for backup mysql database ###
###                                  ###
########################################

# basic vars
DEBUG="false"
DRY_RUN="false"
SSH="ssh -o ConnectTimeout=5 -o PasswordAuthentication=no -o StrictHostKeyChecking=no"
SCP="scp -o ConnectTimeout=5 -o PasswordAuthentication=no -o StrictHostKeyChecking=no -q"
LOCK_FILE="/tmp/`basename $0`.lock"
DATE=`date +%Y%m%d-%H%M`	# format: year month day hours minute
EXIT_CODES="0"
INFO_LOG="/var/log/mysql/backup_info.log"
ERROR_LOG="/var/log/mysql/backup_error.log"

# vars
XTRABACKUP="false"
HOTCOPYBACKUP="false"
BACKUPS_DIR="/opt/BACKUP/mysql"
BACKUPS_LIFE="3"
FULL_HOSTNAME=`hostname -f 2>/dev/null || hostname`
REMOTE_BACKUPS_DIR="/opt/BACKUP/nobacula/mysql/$FULL_HOSTNAME"
REMOTE_BACKUPS_LIFE="3"
REMOTE_USER="backup"
TMP_DIR="/opt/DB/tmp"

# functions
do_usage(){
	cat <<EOF

Script to the backup mysql database

Usage:
	$0 [-dD] [options]
	$0 -h

Options:
	-b	-- set DB name for backup (default backuping all db)
	-r	-- replication mode (stop replica before backup and start after)
	-o	-- options for mysql connection (if you use options -x, please set "long opts" format)

	-x	-- use xtrabackup for backuping (default use mysqldump)
		-- for restore use command xtrabackup --prepare --apply-log-only --target-dir=/path/to/backup/dir

	-c	-- use mysqlhotcopy for backuping (default use mysqldump)
		-- only for MYISAM engine
		-- does not work which -R option

	-t	-- set path to tmpdir for xtrabackup (default $TMP_DIR)

	-p	-- path to backups dir (default $BACKUPS_DIR)
	-l	-- backups life in days (default $BACKUPS_LIFE)

	-U	-- remote user (default $REMOTE_USER)
	-R	-- remote host
	-P	-- path to backups dir on remote hosts (default $REMOTE_BACKUPS_DIR), use only with -R options
	-L	-- backups life on remote host in days (default $REMOTE_BACKUPS_LIFE), use only with -R options

	-d	-- dry run
	-D	-- debug
	-h	-- print this help page

EOF
	exit 1
}
do_debug(){
	if "$DEBUG"; then
		echo $@
	fi
}
do_run(){
	CMD="$@"
	if "$DRY_RUN"; then
		echo "$CMD"
	else
		sh -c "$CMD"
		EXIT_CODES=$(($EXIT_CODES + $?))
	fi
	do_check_exit_code
}
do_check_exit_code(){
	if ! [ x"$EXIT_CODES" = x0 ]; then
		echo "Error"
		exit 1
	fi
}

# get options
CONN_OPTS=""
DUMP_OPTS=""
while getopts b:ro:xct:p:l:U:R:P:L:dDh Opts; do
	case $Opts in
		b) DBS="$OPTARG";;
		r) DUMP_OPTS="--dump-slave=2";;
		o) CONN_OPTS="$OPTARG";;
		x) XTRABACKUP="true";;
		c) HOTCOPYBACKUP="true";;
		t) TMP_DIR="$OPTARG";;
		p) BACKUPS_DIR="$OPTARG";;
		l) BACKUPS_LIFE="$OPTARG";;
		U) REMOTE_USER="$OPTARG";;
		R) REMOTE_HOST="$OPTARG";;
		P) REMOTE_BACKUPS_DIR="$OPTARG";;
		L) REMOTE_BACKUPS_LIFE="$OPTARG";;
		d) DRY_RUN="true";;
		D) DEBUG="true";;
		?|h) do_usage;;
	esac
done

# check options
if [ -z "$DBS" ]; then
	DBS=`mysql $CONN_OPTS -BNe 'show databases' | sort | grep -vP "^information_schema$|^performance_schema$|^test$" | xargs echo`
fi

# check programm
for PROGRAM in mysqldump mysqlhotcopy innobackupex lzop; do
	if ! which $PROGRAM > /dev/null 2>&1; then
		echo "$PROGRAM does not exist, exiting"
		exit 1
	fi
done

# get passwd
if [ -f /root/.my.cnf ]; then
	MYSQL_PWD=`grep password /root/.my.cnf | awk '{print $3}'`
fi

# if set remote host, then create backup and transfer to remote host on the "pipe"
# else create local backup
if [ -z "$REMOTE_HOST" ]; then
	do_run install -m 0770 -d $BACKUPS_DIR
	do_run install -d $TMP_DIR
	do_run "find $BACKUPS_DIR/ -maxdepth 1 -type f -regex '.*\(tzo\|lzo\)' -mtime +$BACKUPS_LIFE | xargs rm -f"
	if $XTRABACKUP; then
		do_run "ulimit -n 4096; MYSQL_PWD='$MYSQL_PWD' innobackupex $CONN_OPTS --no-lock --tmpdir=$TMP_DIR --defaults-file=/etc/mysql/my.cnf --databases='$DBS' --parallel=8 --stream=tar ./ | lzop -1 > $BACKUPS_DIR/${DATE}_mysql.tzo" 2> $ERROR_LOG
	elif $HOTCOPYBACKUP; then
		for DB in $DBS; do
			if mysql $CONN_OPTS -BNe 'show table status' $DB |  cut -f 2 | grep -q InnoDB; then
				do_run "mysqldump $DUMP_OPTS $CONN_OPTS $DB | lzop -1 > $BACKUPS_DIR/${DATE}_$DB.sql.lzo"
			else
				do_run "mysqlhotcopy -q $CONN_OPTS $DB $BACKUPS_DIR"
				do_run "cd $BACKUPS_DIR && tar --lzop -cpf ${DATE}_$DB.tzo $DB; rm -rf $DB"
			fi
		done
	else
		for DB in $DBS; do
			do_run "mysqldump $DUMP_OPTS $CONN_OPTS $DB | lzop -1 > $BACKUPS_DIR/${DATE}_$DB.sql.lzo"
		done
	fi
else
	do_run "$SSH $REMOTE_USER@$REMOTE_HOST 'install -d $REMOTE_BACKUPS_DIR'"
	do_run install -d $TMP_DIR
	do_run "$SSH $REMOTE_USER@$REMOTE_HOST 'find $REMOTE_BACKUPS_DIR -maxdepth 1 -type f -regex \".*\(tzo\|lzo\)\" -mtime +$REMOTE_BACKUPS_LIFE | xargs rm -f'"
	if $XTRABACKUP; then
		do_run "ulimit -n 4096; MYSQL_PWD='$MYSQL_PWD' innobackupex $CONN_OPTS --no-lock --tmpdir=$TMP_DIR --defaults-file=/etc/mysql/my.cnf --databases='$DBS' --parallel=8 --stream=tar ./ | lzop -1 | $SSH $REMOTE_USER@$REMOTE_HOST 'cat > $REMOTE_BACKUPS_DIR/${DATE}_mysql.tzo'" 2> $ERROR_LOG
	else
		for DB in $DBS; do
			do_run "mysqldump $DUMP_OPTS $CONN_OPTS $DB | lzop -1 | $SSH $REMOTE_USER@$REMOTE_HOST 'cat > $REMOTE_BACKUPS_DIR/${DATE}_$DB.sql.lzo'"
		done
	fi
fi
