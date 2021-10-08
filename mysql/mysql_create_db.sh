#!/bin/bash

## DO NOT EDIT
## This file is under PUPPET control

#
# Simple script for create database and grants for db user
#

# Vars
DB="$1"
USER="${2:-$DB}"
PASSWD="${3:-`pwgen -n 16 -1 2>/dev/null`}"

# Check db and user
if [ -z "$DB" ] || [ -z "$USER" ]; then
	cat <<EOF
Usage:
	$0 dbname [username] [password]
EOF
	exit 1
fi

# check passwd
if [ -z "$PASSWD" ]; then
	echo "pwgen it's not installed, exiting"
	exit 1
fi
# check username
if [[ ${#USER} -gt 16 ]]; then
	echo "ERROR! String '$USER' is too long for user name (should be no longer than 16)"
	exit 1
fi

# Create database
mysqladmin create $DB || exit 1
cat <<EOF | mysql
GRANT USAGE ON *.* TO '$USER'@localhost IDENTIFIED BY '$PASSWD';
GRANT USAGE ON *.* TO '$USER'@'127.0.0.1' IDENTIFIED BY '$PASSWD';
GRANT USAGE ON *.* TO '$USER'@'%' IDENTIFIED BY '$PASSWD';
GRANT ALL PRIVILEGES ON \`$DB%\`.* TO '$USER'@localhost;
GRANT ALL PRIVILEGES ON \`$DB%\`.* TO '$USER'@'127.0.0.1';
GRANT ALL PRIVILEGES ON \`$DB%\`.* TO '$USER'@'%';
EOF

# Show db access
cat <<EOF
Access to DB on $HOSTNAME:
DB name	$DB
User	$USER
Passwd	$PASSWD

$USER	$PASSWD

cat <<MYCNF > ~/.my.cnf
[client]
user        = $USER
password    = $PASSWD
MYCNF
chmod 0600 ~/.my.cnf
EOF
