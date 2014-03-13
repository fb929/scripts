#!/bin/bash

# skeleton for creating scripts

# basic vars
DEBUG="false"
DRY_RUN="false"
SSH="ssh -o ConnectTimeout=5 -o PasswordAuthentication=no -o StrictHostKeyChecking=no"
SCP="scp -o ConnectTimeout=5 -o PasswordAuthentication=no -o StrictHostKeyChecking=no -q"
LOCK_FILE="/tmp/`basename $0`.lock"
DATE=`date +%Y%m%d-%H%M`	# format: year month day hours minute
EXIT_CODES="0"
INFO_LOG="/var/log/`basename $0`.log"
ERROR_LOG="/var/log/`basename $0`.log"

# vars
#FULL_HOSTNAME=`hostname -f 2>/dev/null || hostname`

# base functions
do_usage(){
	cat <<EOF

Simple script

Usage:
	$0 [-dDh]

Options:
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
		EXIT_CODE="$?"
		EXIT_CODES=$(($EXIT_CODES + $EXIT_CODE))
	else
		sh -c "$CMD"
		EXIT_CODE="$?"
		EXIT_CODES=$(($EXIT_CODES + $EXIT_CODE))
	fi
# uncomment this if you need stop programm after CMD return error code
#	do_check_exit_code
}
do_check_exit_code(){
	if ! [ x"$EXIT_CODES" = x0 ]; then
		echo "exit code $CMD not 0"
		do_unlock
		exit 1
	fi
}
do_unlock(){
	rm -f $LOCK_FILE
}

# get options
while getopts dDh Opts; do
	case $Opts in
		d) DRY_RUN="true" ;;
		D) DEBUG="true" ;;
		h|?) do_usage ;;
	esac
done
shift $((OPTIND-1))

# сheck lock file
if [ -f $LOCK_FILE ]; then
	echo "$0 already running"
	echo "lock file $LOCK_FILE"
	exit 1
else
	touch $LOCK_FILE
fi

# action

# unlock
do_unlock
