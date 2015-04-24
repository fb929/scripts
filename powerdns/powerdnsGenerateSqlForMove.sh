#!/bin/bash

# scripts for generate sql file for move domain in powerdns

ACTION="$1"
shift
DOMAINS="$@"

REPLACE="
	s|ns\.q1\.ru|ns.game-insight.com|g;
	s|ns2\.q1\.ru|ns2.game-insight.com|g;
	s|domain\.q1\.ru|support.game-insight.com|g;
	s|root@q1\.ru|support.game-insight.com|g;
	s|root\.q1\.ru|support.game-insight.com|g;
"

do_usage(){
	cat <<EOF
usage: $0 [domains|records] domainsList

options:
	domains|records - gen domains list or records list
	domainsList     - set domains list or path to list file
EOF
	exit 1
}
do_domains(){
	LIST="$@"
	for DOMAIN in $LIST; do
		NOTIFIED_SERIAL=$( mysql -Ne "select notified_serial from domains where name='$DOMAIN';" powerdns )
		if [[ -z "$NOTIFIED_SERIAL" ]]; then
			echo "error get notified_serial for domain $DOMAIN"
			continue
		fi
		echo "INSERT INTO domains (name,type,notified_serial) VALUES ('$DOMAIN','MASTER','$NOTIFIED_SERIAL');"
	done
	echo
	echo "run on new database:"
	echo "mysql -Ne '"
	for DOMAIN in $LIST; do
		echo "SELECT name,id from domains where name=\"$DOMAIN\";"
	done
	echo "' powerdns | sed -e 's|\\t|:|g'"
}
do_records(){
	LIST="$@"
	for LINE in $LIST; do
		DOMAIN=$( echo $LINE | cut -d ":" -f 1)
		DOMAIN_ID=$(echo $LINE | cut -d ":" -f 2)
		if [[ -z $DOMAIN_ID ]] || [[ $DOMAIN_ID = $DOMAIN ]]; then
			echo "please set domain_id afte ':' selecter"
			continue
		fi
		NOTIFIED_SERIAL=$( mysql -Ne "select notified_serial from domains where name='$DOMAIN';" powerdns )
		if [[ -z "$NOTIFIED_SERIAL" ]]; then
			echo "error get notified_serial for domain $DOMAIN"
			continue
		fi
		RECORDS=$( mysql -Ne "SELECT name,type,content,ttl,prio,change_date FROM records WHERE name like '%$DOMAIN';" powerdns | sed -e 's|\t|:|g; s| |#|g ')
		for RECORD in $RECORDS; do
			NAME=$( echo $RECORD | cut -d ":" -f 1)
			TYPE=$( echo $RECORD | cut -d ":" -f 2)
			CONTENT=$( echo $RECORD | cut -d ":" -f 3 | sed -e "s|#| |g; $REPLACE")
			TTL=$( echo $RECORD | cut -d ":" -f 4)
			PRIO=$( echo $RECORD | cut -d ":" -f 5)
			CHANGE_DATE=$( echo $RECORD | cut -d ":" -f 6)
			echo "INSERT INTO records (domain_id,name,type,content,ttl,prio,change_date) VALUES ('$DOMAIN_ID','$NAME','$TYPE','$CONTENT','$TTL','$PRIO','$CHANGE_DATE');"
		done
	done
}

# set domains
if [[ -s $DOMAINS ]]; then
	DOMAINS=$(cat $DOMAINS)
fi

case $ACTION in
	domains|records) do_$ACTION $DOMAINS;;
	*) do_usage;;
esac
