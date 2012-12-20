#!/bin/bash

CLIENT_NAMES="$@"

if [ -z "$CLIENT_NAMES" ]; then
	cat <<EOF
Usage:
	$0 client_name
	$0 client_name1 client_name2 ...
EOF
	exit 1
fi

WDIR=`dirname $0`

# load vars
. $WDIR/vars
cd $WDIR

# revoke certs
for CLIENT_NAME in $CLIENT_NAMES; do
	# revoke certs
	openssl ca -config ca.config -revoke $CLIENT_CERTS_DIR/$CLIENT_NAME/$CLIENT_NAME.crt &&
	openssl ca -gencrl -config ca.config -out $SERVER_CERTS_DIR/ca.crl &&
	rm -rf $CLIENT_CERTS_DIR/$CLIENT_NAME


	# view revoke certs
	openssl crl -in $SERVER_CERTS_DIR/ca.crl -text -noout
done

# update ca.crl 
cp $SERVER_CERTS_DIR/ca.crl /etc/nginx/ssl-auth/
sudo /etc/init.d/nginx reload

# save change to git
git add .
git commit -am "Revoke clients: $CLIENT_NAMES"
