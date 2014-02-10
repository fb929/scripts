#!/bin/bash

## DO NOT EDIT
## This file is under PUPPET control

########################################
###                                  ###
### Script for backup mongo database ###
###                                  ###
########################################

### Basic vars
DEBUG="false"
DRY_RUN="false"
SSH="ssh -o ConnectTimeout=5 -o PasswordAuthentication=no -o StrictHostKeyChecking=no"
SCP="scp -o ConnectTimeout=5 -o PasswordAuthentication=no -o StrictHostKeyChecking=no -q"
RSYNC="rsync -a --rsh='$SSH'"
LOCK_FILE="/tmp/`basename $0`.lock"
DATE=`date +%Y%m%d_%H%M`	# format: year month day hours minute
LOGS_DIR="/var/log/mongodb"
INFO_LOG="$LOGS_DIR/backup_info.log"
ERROR_LOG="$LOGS_DIR/backup_error.log"
EXIT_CODES="0"

### Vars
HOST="127.0.0.1"
BACKUPS_DIR="/opt/BACKUP/mongo"
BACKUPS_LIFE="2"
FULL_HOSTNAME=`hostname -f 2>/dev/null || hostname`
REMOTE_BACKUPS_DIR="/opt/BACKUP/nobacula/mongo/$FULL_HOSTNAME"
REMOTE_BACKUPS_LIFE="0"
REMOTE_USER="backup"
if tar --help | grep -q lzop; then
	TAR="tar --lzop"
	ARH_EXT="tzo"
else
	TAR="tar --gzip"
	ARH_EXT="tgz"
fi


### Functions
do_usage(){
	cat <<EOF

Script to the backup mongo database

Usage:
	$0 [-dD] [options]
	$0 -h

Options:
	-H	-- set DB hosname (default $HOST)
	-b	-- set DB name for backup (default backuping all db)

	-p	-- path to backups dir (default $BACKUPS_DIR)
	-l	-- backups life in days (default $BACKUPS_LIFE)

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

### Get options
while getopts H:b:p:l:R:P:L:dDh Opts; do
	case $Opts in
		H) HOST="$OPTARG" ;;
		b) DBS="$OPTARG" ;;
		p) BACKUPS_DIR="$OPTARG" ;;
		l) BACKUPS_LIFE="$OPTARG" ;;
		R) REMOTE_HOST="$OPTARG"; BACKUPS_DIR="/opt/BACKUP/nobacula/mongo" ;;
		P) REMOTE_BACKUPS_DIR="$OPTARG" ;;
		L) REMOTE_BACKUPS_LIFE="$OPTARG" ;;
		d) DRY_RUN="true" ;;
		D) DEBUG="true" ;;
		?|h) do_usage ;;
	esac
done

### Check options
[ x"$HOST" == x"0.0.0.0" ] && HOST="127.0.0.1"

### Action
do_run install -d $LOGS_DIR
do_run install -m 0770 -d $BACKUPS_DIR
do_run "find $BACKUPS_DIR/ -maxdepth 1 -type f -regex \".*\(tzo\|lzo\|tgz\)\" -mtime +$BACKUPS_LIFE | xargs rm -f"
# Create dump
cd $BACKUPS_DIR
if [ -z "$DBS" ]; then
	do_run "mongodump --host $HOST > $INFO_LOG 2>$ERROR_LOG"
else
	for DB in $DBS; do
		do_run "mongodump --host $HOST --db $DB > $INFO_LOG 2>$ERROR_LOG"
	done
fi

# Archiving dump
do_run $TAR -cpf ${DATE}.dump.$ARH_EXT dump
do_run rm -rf dump

# move to remote host
if ! [ -z "$REMOTE_HOST" ]; then
	do_run "$SSH $REMOTE_USER@$REMOTE_HOST 'find $REMOTE_BACKUPS_DIR/ -maxdepth 1 -type f -regex \".*\(tzo\|lzo\|tgz\)\" -mtime +$REMOTE_BACKUPS_LIFE | xargs rm -f' "
	do_run "$RSYNC $BACKUPS_DIR/${DATE}.dump.$ARH_EXT $REMOTE_USER@$REMOTE_HOST:$REMOTE_BACKUPS_DIR/"
	do_run "rm -f $BACKUPS_DIR/${DATE}.dump.$ARH_EXT"
fi

exit 0
