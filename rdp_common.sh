#!/bin/bash
# author Jose Vicente Nunez
# Common logic for RDP connectivity
function remote_rpd {
    local remote_user=$1
    local pfile=$2
    local machine=$3
    test -z "$remote_user" && exit 100
    test ! -f "$pfile" && exit 100
    test -z "$machine" && exit 100
    /usr/bin/xfreerdp /cert-ignore /sound:sys:alsa /f /u:"$remote_user" /v:"${machine}" /p:"(/bin/cat ${pfile})" && return 0|| return 1
}
