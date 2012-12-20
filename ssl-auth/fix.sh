#!/bin/bash

WDIR=`dirname $0`

$WDIR/addclient.sh fixclient
$WDIR/revokeclient.sh fixclient
