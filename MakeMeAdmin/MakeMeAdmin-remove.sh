#!/bin/bash
##############
# remove the given user from the admin group, then
# remove the lauchd job which is calling this script.
##############

if [[ $1 ]]; then
	USERNAME=$1
	if [[ `id -u $USER` -ne 0 ]]; then
		echo "must be run as root"
		exit 1
	else
		/usr/sbin/dseditgroup -o edit -d $USERNAME -t user admin
		logger -p local0.notice -t MakeMeAdmin "$USERNAME has been removed from admin group"
		launchctl unload -w /Library/LaunchDaemons/de.fau.rrze.adminremove.plist
		rm -f /Library/LaunchDaemons/de.fau.rrze.adminremove.plist
		logger -p local0.notice -t MakeMeAdmin "launchd job unloaded and removed"
	fi
else
	echo "usage: $0 username"
	exit 1
fi