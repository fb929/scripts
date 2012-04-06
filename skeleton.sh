#!/bin/bash

#####################################
###                               ###
### Skeleton for creating scripts ###
###                               ###
#####################################

### Vars
DEBUG="false"
DRY_RUN="false"
SSH="ssh -o ConnectTimeout=5 -o PasswordAuthentication=no"
SCP="scp -o ConnectTimeout=5 -o PasswordAuthentication=no -q"
LOCK_FILE="/tmp/`basename $0`.lock"

### Base functions
do_usage(){
	cat <<EOF
Usage:
	$0 -[hDd]

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
}
do_unlock(){
	rm -f $LOCK_FILE
}

### Get options
GIT_TAG=""
while getopts dDh Opts; do
	case $Opts in
		d)
			DRY_RUN="true"
			;;
		D)
			DEBUG="true"
			;;
		h|?)
			do_usage
			;;
	esac
done

### Сheck lock file
if [ -f $LOCK_FILE ]; then
	echo "$0 already running"
	echo "lock file $LOCK_FILE"
	exit 1
else
	touch $LOCK_FILE
fi

### Action

### Unlock
do_unlock
