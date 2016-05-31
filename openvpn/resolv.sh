#!/bin/bash

# for usage run:
# sudo openvpn --up <path/to/this_script> --down <path/to/this_script> --script-security 2 --config <path/to/config_file>

# set uniq tmp filename
if [[ -z $common_name ]]; then
	TMP_RESOLV_CONF="/tmp/resolv.conf"
else
	TMP_RESOLV_CONF="/tmp/resolv.conf.$common_name"
fi

# up function:
# save orig resolv.conf
# get and set dns and search options
do_up(){
	cp /etc/resolv.conf $TMP_RESOLV_CONF
	DNS=$( env | grep foreign_option | grep DNS | awk '{print $NF}' )
	DOMAIN=$( env | grep foreign_option | grep DOMAIN | awk '{print $NF}' )
	if [[ -z $DOMAIN ]]; then
		grep -P "^search|^domain" $TMP_RESOLV_CONF > /etc/resolv.conf
	else
		echo search $DOMAIN > /etc/resolv.conf
	fi
	if [[ -z $DNS ]]; then
		grep -P "^nameserver" $TMP_RESOLV_CONF= >> /etc/resolv.conf
	else
		echo nameserver $DNS >> /etc/resolv.conf
	fi
}
# down function:
# revert orig resolv.conf
do_down(){
	mv $TMP_RESOLV_CONF /etc/resolv.conf
}

case $script_type in
	up|down) do_$script_type;;
	*) echo "script_type $script_type not supported"; exit 1
esac
