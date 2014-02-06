#!/bin/bash

## DO NOT EDIT
## This file is under PUPPET control

##############################################
###                                        ###
### Script for backup postgres database    ###
###                                        ###
##############################################

# basic vars
DEBUG="false"
DRY_RUN="false"
SSH="ssh -o ConnectTimeout=5 -o PasswordAuthentication=no -o StrictHostKeyChecking=no"
SCP="scp -o ConnectTimeout=5 -o PasswordAuthentication=no -o StrictHostKeyChecking=no -q"
LOCK_FILE="/tmp/`basename $0`.lock"
DATE=`date +%Y%m%d-%H%M`	# format: year month day hours minute
EXIT_CODES="0"
INFO_LOG="/var/log/postgres/backup_info.log"
ERROR_LOG="/var/log/postgres/backup_error.log"

# vars
USER="postgres"
PORT="5433"
HOST="localhost"
BACKUPS_DIR="/opt/BACKUP/postgres"
BACKUPS_LIFE="3"
REMOTE_BACKUPS_DIR="/opt/BACKUP/nobacula/postgres/$Hostname"
REMOTE_BACKUPS_LIFE="3"
REMOTE_USER="backup"
TMP_DIR="/opt/DB/tmp"
if lzop -V > /dev/null 2>&1; then
	ARH="lzop"
	ARH_EXT="lzo"
else
	ARH="gzip"
	ARH_EXT="gz"
fi

# functions
do_usage(){
	cat <<EOF

Script to the backup postgres database

Usage:
	$0 [-dD] [options]
	$0 -h

Options:
	-b	-- set DB name for backup (default backuping all db)

	-u	-- set user for connect db (default $USER)
	-o	-- set port for connect db (default $PORT)
	-c	-- set hostname for connetc db (default $HOST)

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
while getopts b:u:o:c:p:l:U:R:P:L:dDh Opts; do
	case $Opts in
		b) DBS="$OPTARG";;
		u) USER="$OPTARG";;
		o) PORT="$OPTARG";;
		c) HOST="$OPTARG";;
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

if [ -z "$DBS" ]; then
	DBS=`echo "SELECT datname FROM pg_database  WHERE datistemplate = false;" | psql --username $USER --host=$HOST --port=$PORT -A -t -q`
fi

# if set remote host, then create backup and transfer to remote host on the "pipe"
# else create local backup
if [ -z "$REMOTE_HOST" ]; then
	do_run install -m 0770 -d $BACKUPS_DIR
	do_run install -d $TMP_DIR
	do_run "find $BACKUPS_DIR/ -maxdepth 1 -type f -regex '.*\(gz\|lzo\)' -mtime +$BACKUPS_LIFE | xargs rm -f"
	for DB in $DBS; do
		do_run "pg_dump --username $USER --host=$HOST --port=$PORT -c $DB | $ARH > $BACKUPS_DIR/${DATE}_$DB.sql.$ARH_EXT"
	done

else
	do_run "$SSH $REMOTE_USER@$REMOTE_HOST 'install -d $REMOTE_BACKUPS_DIR'"
	do_run install -d $TMP_DIR
	do_run "$SSH $REMOTE_USER@$REMOTE_HOST 'find $REMOTE_BACKUPS_DIR -maxdepth 1 -type f -regex \".*\(gz\|lzo\)\" -mtime +$REMOTE_BACKUPS_LIFE | xargs rm -f'"
	for DB in $DBS; do
		do_run "pg_dump --username $USER --host=$HOST --port=$PORT -c $DB | $ARH | $SSH $REMOTE_USER@$REMOTE_HOST 'cat > $REMOTE_BACKUPS_DIR/${DATE}_$DB.sql.$ARH_EXT"
	done
fi
