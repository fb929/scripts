#!/bin/bash

CLIENT_NAME="$1"
CLIENT_EMAIL="${2:-$CLIENT_NAME@example.com}"

if [ -z "$CLIENT_NAME" ]; then
	cat <<EOF
Usage:
	$0 client_name [email]
EOF
	exit 1
fi

WDIR=`dirname $0`

# load vars
. $WDIR/vars

# create dirs
cd $WDIR
install -d $CLIENT_CERTS_DIR

# check exists client
if [ -d $CLIENT_CERTS_DIR/$CLIENT_NAME ]; then
	echo "Client $CLIENT_NAME already exists"
	exit
fi

# Create dir
install -d $CLIENT_CERTS_DIR/$CLIENT_NAME

# Client CRT
openssl req -new -newkey rsa:1024 -nodes \
	-subj /C=$KEY_COUNTRY/ST=$KEY_PROVINCE/L=$KEY_CITY/O=$KEY_ORG/OU=$KEY_ORG_UNIT/CN=$CLIENT_NAME/emailAddress=$CLIENT_EMAIL \
	-keyout $CLIENT_CERTS_DIR/$CLIENT_NAME/$CLIENT_NAME.key \
	-out $CLIENT_CERTS_DIR/$CLIENT_NAME/$CLIENT_NAME.csr

# Sign the client certificate
openssl ca -config ca.config -batch -days 3650 \
	-in $CLIENT_CERTS_DIR/$CLIENT_NAME/$CLIENT_NAME.csr \
	-out $CLIENT_CERTS_DIR/$CLIENT_NAME/$CLIENT_NAME.crt

# Create PKCS#12 for client
openssl pkcs12 -export -passout pass:gi \
	-certfile $SERVER_CERTS_DIR/ca.crt \
	-in $CLIENT_CERTS_DIR/$CLIENT_NAME/$CLIENT_NAME.crt \
	-inkey $CLIENT_CERTS_DIR/$CLIENT_NAME/$CLIENT_NAME.key \
	-out $CLIENT_CERTS_DIR/$CLIENT_NAME/$CLIENT_NAME.p12

# save change to git
git add .
git commit -am "Add clients: $CLIENT_NAME"
