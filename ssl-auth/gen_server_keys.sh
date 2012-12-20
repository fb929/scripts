#!/bin/bash

WDIR=`dirname $0`

# load vars
. $WDIR/vars

# create dirs
cd $WDIR
install -d db db/certs db/newcerts
touch db/index.txt
echo "01" > db/serial
install -d $CLIENT_CERTS_DIR $SERVER_CERTS_DIR

# Create CA
openssl req -new -newkey rsa:1024 -nodes -x509 -days 500 \
	-subj /C=$KEY_COUNTRY/ST=$KEY_PROVINCE/L=$KEY_CITY/O=$KEY_ORG/OU=$KEY_ORG_UNIT/CN=ca/emailAddress=$KEY_EMAIL \
	-keyout $SERVER_CERTS_DIR/ca.key \
	-out $SERVER_CERTS_DIR/ca.crt

# Create CRL
openssl ca -gencrl -config ca.config \
	-out $SERVER_CERTS_DIR/ca.crl

# Server CRT
openssl req -new -newkey rsa:1024 -nodes \
	-subj /C=$KEY_COUNTRY/ST=$KEY_PROVINCE/L=$KEY_CITY/O=$KEY_ORG/OU=$KEY_ORG_UNIT/CN=server/emailAddress=$KEY_EMAIL \
	-keyout $SERVER_CERTS_DIR/server.key \
	-out $SERVER_CERTS_DIR/server.csr

# Sign the server certificate
openssl ca -config ca.config -batch \
	-in $SERVER_CERTS_DIR/server.csr \
	-out $SERVER_CERTS_DIR/server.crt

