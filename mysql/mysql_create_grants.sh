#!/bin/bash

## DO NOT EDIT
## This file is under PUPPET control

# simple script for create grants for superuser (default root)

# vars
USER="${1:-root}"
PASSWD="${2:-`pwgen -n 16 -1 2>/dev/null`}"
HOME_DIR=`grep "^$USER:" /etc/passwd | cut -d ":" -f 6`
MYCNF="$HOME_DIR/.my.cnf"

# check
if [ -z "$USER" ]; then
	cat <<EOF

script fo create grants for superuser (default root)

Usage:
	$0 [username] [password]

EOF
	exit 1
fi
if [ -z "$PASSWD" ]; then
	echo "pwgen it's not installed, exiting"
	exit 1
fi
if [ -f "$MYCNF" ]; then
	echo "$MYCNF already exist, grants not set"
	exit 1
fi

# create grants
cat <<EOF | mysql
GRANT ALL PRIVILEGES ON *.* TO '$USER'@'localhost' IDENTIFIED BY '$PASSWD' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO '$USER'@'%' IDENTIFIED BY '$PASSWD' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO '$USER'@'127.0.0.1' IDENTIFIED BY '$PASSWD' WITH GRANT OPTION;
EOF

cat <<EOF > $MYCNF
[client]
user		= $USER
password	= $PASSWD
EOF
chmod 0600 $MYCNF
