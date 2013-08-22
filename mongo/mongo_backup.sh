#!/bin/bash

###########################################
###                                     ###
### Script to the backup mongo database ###
###                                     ###
###########################################

### Basic vars
DEBUG="false"
DRY_RUN="false"
SSH="ssh -o ConnectTimeout=5 -o PasswordAuthentication=no"
SCP="scp -o ConnectTimeout=5 -o PasswordAuthentication=no -q"
LOCK_FILE="/tmp/`basename $0`.lock"
DATE=`date +%Y%m%d_%H%M`	# format: year month day hours minute
INFO_LOG="/var/log/mongodb/backup_info.log"
ERROR_LOG="/var/log/mongodb/backup_error.log"
EXIT_CODES="0"

### Vars
HOST="127.0.0.1"
BACKUPS_DIR="/opt/BACKUP/mongo"
BACKUPS_LIFE="7"
REMOTE_BACKUPS_DIR="/opt/BACKUP/nobacula/mongo/$HOSTNAME"
REMOTE_BACKUPS_LIFE="10"
REMOTE_USER="backup"

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
		R) REMOTE_HOST="$OPTARG" ;;
		P) REMOTE_BACKUPS_DIR="$OPTARG" ;;
		L) REMOTE_BACKUPS_LIFE="$OPTARG" ;;
		d) DRY_RUN="true" ;;
		D) DEBUG="true" ;;
		?|h) do_usage ;;
	esac
done

### Check lock
if [ -f $LOCK_FILE ]; then
	echo "$0 already running!"
	exit 1
else
	touch $LOCK_FILE
fi

### Check options
[ x"$HOST" == x"0.0.0.0" ] && HOST="127.0.0.1"

### Action
do_run install -m 0770 -d $BACKUPS_DIR
do_run "find $BACKUPS_DIR/ -maxdepth 1 -type f -name '*.tgz' -mtime +$BACKUPS_LIFE | xargs rm -f"
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
do_run tar -zcpf ${DATE}.dump.tgz dump
do_run rm -rf dump

# move to remote host
if ! [ -z "$REMOTE_HOST" ]; then
	do_run "$SSH $REMOTE_USER@$REMOTE_HOST 'find $REMOTE_BACKUPS_DIR/ -maxdepth 1 -type f -name \"*.tgz\" -mtime +$REMOTE_BACKUPS_LIFE | xargs rm -f' "
	do_run "rsync -a $BACKUPS_DIR/${DATE}.dump.tgz $REMOTE_USER@$REMOTE_HOST:$REMOTE_BACKUPS_DIR/"
	do_run "rm -f $BACKUPS_DIR/${DATE}.dump.tgz"
fi

rm $LOCK_FILE
exit 0
