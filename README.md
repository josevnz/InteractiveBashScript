# Creating an interactive Bash script, Using external variables, Calling other scripts

In this article I'll present you some code to show you how you can make an interactive script. Of course a fully interactive script is boring and there are ways to avoid asking questions to we may already have the answers or we can make safe asumptions.

## Case of study: Connection to a remote server using RPD

On Linux there are many RDP clients and a really good one is [freerdp](https://www.freerdp.com/). One way to call it is to pass a long line of flags (with confusing short names) like this:

```shell=
/usr/bin/xfreerdp /cert-ignore /sound:sys:alsa /f /u:REMOTE_USER /v:MACHINE /p:mynotsosecretpassword
```

There is a better way to do this?

## Asking questions, learning how to read

So for our first try, we will write a shell wrapper around freerdp asking for the user, password and remote machine. WIll use Bash [builtin read command](https://wiki.bash-hackers.org/commands/builtin/read):

```shell=
#!/bin/bash
# author Jose Vicente Nunez
# Do not use this script on a public computer.
tmp_file=$(/usr/bin/mktemp 2>/dev/null) || exit 100
trap '/bin/rm -f $tmp_file' QUIT EXIT INT
/bin/chmod go-wrx "${tmp_file}" > /dev/null 2>&1
read -r -p "Remote RPD user: " REMOTE_USER|| exit 100
test -z "$REMOTE_USER" && exit 100
read -r -s -p "Password for $REMOTE_USER: " PASSWD|| exit 100
test -z "$PASSWD" && exit 100
echo
echo > "$tmp_file"|| exit 100
read -r -p "Remote server: " MACHINE|| exit 100
test -z "$REMOTE_USER" && exit 100
/usr/bin/xfreerdp /cert-ignore /sound:sys:alsa /f /u:"$REMOTE_USER" /v:"${MACHINE}" /p:"(/bin/cat ${tmp_file})"
```

To read (lines 7,13) into a variable you just say read variable. To make it more friendly, we pass -p (Show a custom prompt) and -r (to be able to read backslashes if we made a typo).

read also allows you to suppress the characters you write on the screen, it is called -s (secret) mode (line 9).

One thing that bothers me is that anyone doing a ```ps -ef``` can see my password on the command line; to avoid that I save it onto a file and then using a subshell I read it back when the xfreerdp needs it. And to avoid leaving my password lying around on the disk I save into a temporary file, which I ensure gets removed once the script finishes or if is killed.

But still ... this script keeps asking some questions over an over, there is a way to make it, well smarter?

We could save some of the defaults, like the remote servers, on a configuration file. If we provide none then we use the def

Also on the topic of code reuse: We will put the logic of how to connect to a remote server on a separate file, in case we want to re-use some of this logic in other places like this. So the new library looks like this:

```shell=
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
```

And the RDP wrapper is much simpler now:
```shell=
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

```

So after this change, how does it look like?
```shell=
 josevnz  dmaf5  ../InteractiveBashScript  main  ./kodegeek_rdp2.sh
Remote RPD user: jose
Password for jose: 
Remote server: myremotemachine.kodegeek.com
[20:51:50:492] [52560:52561] [INFO][com.freerdp.core] - freerdp_connect:freerdp_set_last_error_ex resetting error state
[20:51:50:493] [52560:52561] [INFO][com.freerdp.client.common.cmdline] - loading channelEx rdpdr
[20:51:50:493] [52560:52561] [INFO][com.freerdp.client.common.cmdline] - loading channelEx rdpsnd
[20:51:50:493] [52560:52561] [INFO][com.freerdp.client.common.cmdline] - loading channelEx cliprdr
[20:51:50:493] [52560:52561] [INFO][com.freerdp.client.common.cmdline] - loading channelEx drdynvc
[20:51:50:811] [52560:52561] [INFO][com.freerdp.primitives] - primitives autodetect, using optimized
[20:51:50:894] [52560:52561] [ERROR][com.freerdp.core] - freerdp_tcp_is_hostname_resolvable:freerdp_set_last_error_ex ERRCONNECT_DNS_NAME_NOT_FOUND [0x00020005]
```

There is more room for improvement so please keep reading

## Always give users a choice: getopt, external variables

Example of external variables and getopt goes here. Also calling other scripts

## But a want a nice text UI: Nothing like a good dialog

Example of Dialog goes here.


