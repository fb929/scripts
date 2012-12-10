#!/bin/bash

###########################################
###                                     ###
### Script to the backup mysql database ###
###                                     ###
###########################################

### Basic Vars
DEBUG="false"
DRY_RUN="false"
SSH="ssh -o ConnectTimeout=5 -o PasswordAuthentication=no"
SCP="scp -o ConnectTimeout=5 -o PasswordAuthentication=no -q"
LOCK_FILE="/tmp/`basename $0`.lock"
DATE=`date +%Y%m%d-%H%M`	# format: year month day hours minute
EXIT_CODES="0"
INFO_LOG="/var/log/mysql/backup_info.log"
ERROR_LOG="/var/log/mysql/backup_error.log"

### Vars
XTRABACKUP="false"
BACKUPS_DIR="/opt/BACKUP/mysql"
BACKUPS_LIFE="5"
REMOTE_BACKUPS_DIR="/opt/BACKUP/nobacula/mysql/$HOSTNAME"
REMOTE_BACKUPS_LIFE="10"
REMOTE_USER="mysql_backup"
TMP_DIR="/opt/DB/tmp"

### Functions
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
	-t	-- set path to tmpdir for xtrabackup (default $TMP_DIR)

	-p	-- path to backups dir (default $BACKUPS_DIR)
	-l	-- backups life in days (default $BACKUPS_LIFE)

	-R	-- remote host
	-P	-- path to backups dir on remote hosts (default $REMOTE_BACKUPS_DIR), use only with -r options
	-L	-- backups life on remote host in days (default $REMOTE_BACKUPS_LIFE), use only with -r options

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

### Get options
CONN_OPTS=""
DUMP_OPTS=""
while getopts b:ro:xt:p:l:R:P:L:dD Opts; do
	case $Opts in
		b) DBS="$OPTARG" ;;
		r) DUMP_OPTS="--dump-slave=2" ;;
		o) CONN_OPTS="$OPTARG" ;;
		x) XTRABACKUP="true" ;;
		t) TMP_DIR="$OPTARG" ;;
		p) BACKUPS_DIR="$OPTARG" ;;
		l) BACKUPS_LIFE="$OPTARG" ;;
		R) REMOTE_HOST="$OPTARG" ;;
		P) REMOTE_BACKUPS_DIR="$OPTARG" ;;
		L) REMOTE_BACKUPS_LIFE="$OPTARG" ;;
		d) DRY_RUN="true" ;;
		D) DEBUG="true" ;;
		?) do_usage ;;
	esac
done

### Check options
if [ -z "$DBS" ]; then
	DBS=`mysql $CONN_OPTS -N -e 'show databases' | sort | grep -vP "^information_schema$|^performance_schema$|^test$" | xargs echo`
fi

### Check programm
if ! which innobackupex > /dev/null 2>&1; then
	echo "innobackupex does not exist, exiting"
	exit 1
fi
if ! which mysqldump > /dev/null 2>&1; then
	echo "mysqldump does not exist, exiting"
	exit 1
fi
if ! which lzop > /dev/null 2>&1; then
	echo "lzop does not exist, exiting"
	exit 1
fi

### Action
if [ -z "$REMOTE_HOST" ]; then
	do_run install -m 0770 -d $BACKUPS_DIR
	if $XTRABACKUP; then
		do_run "innobackupex $CONN_OPTS --no-lock --tmpdir=$TMP_DIR --defaults-file=/etc/mysql/my.cnf --databases='$DBS' --parallel=8 --stream=tar ./ | lzop -1 > $BACKUPS_DIR/${DATE}_mysql.tzo" 2> $ERROR_LOG
	else
		for DB in $DBS; do
			do_run "mysqldump $DUMP_OPTS $CONN_OPTS $DB | lzop -1 > $BACKUPS_DIR/${DATE}_$DB.sql.lzo"
		done
	fi
	do_run "find $BACKUPS_DIR/ -maxdepth 1 -type f -regex '.*\(tzo\|lzo\)' -mtime +$BACKUPS_LIFE | xargs rm -f"
else
	do_run "$SSH $REMOTE_USER@$REMOTE_HOST 'install -d $REMOTE_BACKUPS_DIR'"
	if $XTRABACKUP; then
		do_run "innobackupex $CONN_OPTS --no-lock --tmpdir=$TMP_DIR --defaults-file=/etc/mysql/my.cnf --databases='$DBS' --parallel=8 --stream=tar ./ | lzop -1 | $SSH $REMOTE_USER@$REMOTE_HOST 'cat > $REMOTE_BACKUPS_DIR/${DATE}_mysql.tzo'" 2> $ERROR_LOG
	else
		for DB in $DBS; do
			do_run "mysqldump $DUMP_OPTS $CONN_OPTS $DB | lzop -1 | $SSH $REMOTE_USER@$REMOTE_HOST 'cat > $REMOTE_BACKUPS_DIR/${DATE}_$DB.sql.lzo'"
		done
	fi
	do_run "$SSH $REMOTE_USER@$REMOTE_HOST 'find $REMOTE_BACKUPS_DIR -maxdepth 1 -type f -regex \".*\(tzo\|lzo\)\" -mtime +$REMOTE_BACKUPS_LIFE | xargs rm -f ' "
fi
