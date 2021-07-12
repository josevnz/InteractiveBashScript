#!/bin/bash
# author Jose Vicente Nunez
# Do not use this script on a public computer.
# shellcheck source=/dev/null.
. "rdp_common.sh" 
tmp_file=$(/usr/bin/mktemp 2>/dev/null) || exit 100
trap '/bin/rm -f $tmp_file' QUIT EXIT INT
/bin/chmod go-wrx "${tmp_file}" > /dev/null 2>&1
read -r -p "Remote RPD user: " REMOTE_USER|| exit 100
read -r -s -p "Password for $REMOTE_USER: " PASSWD|| exit 100
echo
echo "$PASSWD" > "$tmp_file"|| exit 100
read -r -p "Remote server: " MACHINE|| exit 100
remote_rpd "$REMOTE_USER" "$tmp_file" "$MACHINE"
