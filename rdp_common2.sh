#!/bin/bash
# author Jose Vicente Nunez
# Common logic for RDP connectivity
if [[ -x '/usr/bin/jq' ]] && [[ -f "$HOME/.config/scripts/kodegeek_rdp.json" ]]; then
    REMOTE_USER="$(/usr/bin/jq --compact-output --raw-output '.remote_user' "$HOME"/.config/scripts/kodegeek_rdp.json)"|| exit 100
    MACHINE="$(/usr/bin/jq --compact-output --raw-output '.machines[0]| join(",")' "$HOME"/.config/scripts/kodegeek_rdp.json)"|| exit 100
    export REMOTE_USER
    export MACHINE
fi


function remote_rpd {
    local remote_user=$1
    local pfile=$2
    local machine=$3
    test -z "$remote_user" && exit 100
    test ! -f "$pfile" && exit 100
    test -z "$machine" && exit 100
    /usr/bin/xfreerdp /cert-ignore /sound:sys:alsa /f /u:"$remote_user" /v:"${machine}" /p:"(/bin/cat ${pfile})" && return 0|| return 1
}
