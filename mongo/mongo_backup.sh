#!/bin/bash

#################################################
###                                           ###
### Script to the local backup mongo database ###
###                                           ###
#################################################

### Static vars
DEBUG="false"
DRY_RUN="false"
BACKUPS_DIR="/opt/BACKUP/mongo"
BACKUPS_LIFE="1"
DATE=`date +%Y%m%d_%H%M`	# format: year month day hours minute
EXIT_CODES="0"
INFO_LOG="/var/log/mongodb/backup_info.log"
ERROR_LOG="/var/log/mongodb/backup_error.log"
HOST="0.0.0.0"

### Functions
do_usage(){
	cat <<EOF
Usage:
	$0 [-Dd]
	$0 -H <hostname> [-Dd]
	$0 -H <hostname> -b <db or dbs> [-Dd]
	$0 -h

Options:
	-H	-- set DB hosname (default 127.0.0.1)
	-b	-- set DB name for backup (default backuping all db)
	-D	-- debug mode
	-d	-- dry run (only show did not perform)
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
b=""
while getopts H:b:Dd Opts; do
	case $Opts in
		H)
			HOST="$OPTARG"
			;;
		b)
			DBS="$OPTARG"
			;;
		D)
			DEBUG="true"
			;;
		d)
			DRY_RUN="true"
			;;
		?)
			do_usage
			;;
	esac
done

### Check options
[ x"$HOST" == x"0.0.0.0" ] && HOST="127.0.0.1"

### Action
do_debug "=> Check Backups dir:"
if [ -d $BACKUPS_DIR/ ]; then
	do_debug "[ OK ]"
else
	do_debug "[ FAIL ]"
	do_debug "$BACKUPS_DIR not found, creating..."
	do_run install -m 0770 -d $BACKUPS_DIR
fi

do_debug "=> Cleaning old archive:"
do_run "find $BACKUPS_DIR/ -maxdepth 1 -type f -name '*.tgz' -mtime +$BACKUPS_LIFE | xargs rm -f"

do_debug "=> Shoot dump:"
cd $BACKUPS_DIR
if [ -z "$DBS" ]; then
	do_run "mongodump --host $HOST > $INFO_LOG 2>$ERROR_LOG"
else
	for DB in $DBS; do
		do_run "mongodump --host $HOST --db $DB > $INFO_LOG 2>$ERROR_LOG"
	done
fi

do_debug "=> Archiving dump:"
do_run tar -zcpf ${DATE}.dump.tgz dump
do_run rm -rf dump
