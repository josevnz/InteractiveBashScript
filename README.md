# Creating an interactive Bash script by using external variables and calling other scripts


![An interactive script, using Dialog](https://i.imgur.com/s445Xwb.png)


> There are times when a script must ask for information that cannot be stored on a configuration file, or when the number of choices will not allow to store every single possibility. Bash is pretty good at making interactive scripts.

Ideally by the end of this article you should be able to do the following:

* Write small programs that ask user questions and saves the answers (including sensitive ones, like password)
* Be able to read data from configuration files by using other programs
* Allow the script to skip asking questions if external variables are define
* And as a bonus, how to write a nice UI with text dialogs.

So let's get started with a small script to connec to a remote desktop using the RDP protocol.

## Case study: Connection to a remote server using RPD

On Linux there are many RDP clients and a really good one is [freerdp](https://www.freerdp.com/). One way to call it is to pass a long line of flags (with confusing short names) like this:

```shell=
/usr/bin/xfreerdp /cert-ignore /sound:sys:alsa /f /u:REMOTE_USER /v:MACHINE /p:mynotsosecretpassword
```

There is a better way to do this?

## Asking questions, learning how to read

So for our first try, [I wrote (version 1)](https://github.com/josevnz/InteractiveBashScript/blob/main/kodegeek_rdp1.sh) a shell wrapper around freerdp asking for the user, password and remote machine. Will use Bash [builtin read command](https://wiki.bash-hackers.org/commands/builtin/read):

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

Also on the topic of code reuse: We will put the logic of how to connect to a remote server on a separate file, in case we want to re-use some of this logic in other places like this. So the [new library](https://github.com/josevnz/InteractiveBashScript/blob/main/rdp_common.sh) looks like this:

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

And the [RDP wrapper, version 2 of the original script](https://github.com/josevnz/InteractiveBashScript/blob/main/kodegeek_rdp2.sh) is much simpler now:
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
```

There is more room for improvement so please keep reading

## Always give users a choice: external variables and more external programs

So say that you use your script to connect to the same machine every day; chances are that you will not change your remote user, machine and only the password once in a while. So we could save all those settings on a configuration file, readable only by the current user and nobody else:

(Example of ~/.config/scripts/kodegeek_rdp.json)
```json=
{
    "machines": [
        {
            "name": "myremotemachine.kodegeek.com",
            "description": "Personal-PC"
        },
        {
            "name": "vmdesktop1.kodegeek.com",
            "description": "Virtual-Machine"
        }
    ],
    "remote_user": "jose@MYCOMPANY",
    "title" : "Remote desktop settings"
}
```

Yes, JSON is not the best format for configuration files, but ours is pretty small. Also notice that we can now store more than one remote machine (for simplicity will use only the first one)

To take advantage of it, we will modify our [library (v2)](https://github.com/josevnz/InteractiveBashScript/blob/main/rdp_common2.sh) to look like this:

```shell=
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
```

Did you notice I did not try to read the password from a configuration file? That's the only credential I will keep asking over an over unless is encrypted :-). The rest of the values we get using [jq](https://stedolan.github.io/jq/), using a subshell.

And of course a new version ([v3](https://github.com/josevnz/InteractiveBashScript/blob/main/kodegeek_rdp2.sh)) of the script:

```shell=
#!/bin/bash
# author Jose Vicente Nunez
# Do not use this script on a public computer.
# shellcheck source=/dev/null
. "rdp_common2.sh" 
tmp_file=$(/usr/bin/mktemp 2>/dev/null) || exit 100
trap '/bin/rm -f $tmp_file' QUIT EXIT INT
/bin/chmod go-wrx "${tmp_file}" > /dev/null 2>&1
if [ -z "$REMOTE_USER" ]; then
    read -r -p "Remote RPD user: " REMOTE_USER|| exit 100
fi
read -r -s -p "Password for $REMOTE_USER: " PASSWD|| exit 100
echo
echo "$PASSWD" > "$tmp_file"|| exit 100
if [ -z "$MACHINE" ]; then
    read -r -p "Remote server: " MACHINE|| exit 100
fi
remote_rpd "$REMOTE_USER" "$tmp_file" "$MACHINE"
```

So we do not ask for 2 parameters anymore, just the password:
```shell=
./kodegeek_rdp2.sh 
Password for jose@MYCOMPANY: 
```

There is anything else you can do to enchance this script?


## But a want a nice text UI: Nothing like a good dialog

Let me show you how you can write an interactive script with a nice tool [called Dialog](https://invisible-island.net/dialog/). I will ask the user to choose between a variable number of machines (depending of the configuration file) and of course the password.
But if the remote user is the same for both machines (which is normal if you connect to the same company) then we will not ask for it.

Note than dialog [is not the only player in town](https://linuxgazette.net/101/sunil.html), I just happen to like it because it is widely available and because its simplicity.

Below is [version 3](https://github.com/josevnz/InteractiveBashScript/blob/main/kodegeek_rdp3.sh) of the script. Its heavily commented, you can see the way Dialog works is either by reading variables or files to enable/ disable options. Give it a shot and run the script to see how each part fits together:

```shell=
#!/bin/bash
# author Jose Vicente Nunez
# Do not use this script on a public computer.
# https://invisible-island.net/dialog/
SCRIPT_NAME="$(/usr/bin/basename "$0")"
DATA_FILE="$HOME/.config/scripts/kodegeek_rdp.json"
test -f "$DATA_FILE"|| exit 100
: "${DIALOG_OK=0}"
: "${DIALOG_CANCEL=1}"
: "${DIALOG_HELP=2}"
: "${DIALOG_EXTRA=3}"
: "${DIALOG_ITEM_HELP=4}"
: "${DIALOG_ESC=255}"
tmp_file=$(/usr/bin/mktemp 2>/dev/null) || declare tmp_file=/tmp/test$$
trap '/bin/rm -f $tmp_file' QUIT EXIT INT
/bin/chmod go-wrx "${tmp_file}" > /dev/null 2>&1

TITLE=$(/usr/bin/jq --compact-output --raw-output '.title' "$DATA_FILE")|| exit 100
REMOTE_USER=$(/usr/bin/jq --compact-output --raw-output '.remote_user' "$DATA_FILE")|| exit 100

# Choose a machine
MACHINES=$(
    tmp_file2=$(/usr/bin/mktemp 2>/dev/null) || declare tmp_file2=/tmp/test$$
    /usr/bin/jq --compact-output --raw-output '.machines[]| join(",")' "$DATA_FILE" > $tmp_file2|| exit 100
    declare -i i=0
    while read -r line; do
        machine=$(echo "$line"| /usr/bin/cut -d',' -f1)|| exit 100
        desc=$(echo "$line"| /usr/bin/cut -d',' -f2)|| exit 100
        toggle=off
        if [ $i -eq 0 ]; then
            toggle=on
            ((i=i+1))
        fi
        echo "$machine" "$desc" "$toggle"
    done < "$tmp_file2"
    /bin/cp /dev/null $tmp_file2
) || exit 100
# shellcheck disable=SC2086
/usr/bin/dialog \
    --clear \
    --title "$TITLE" \
    --radiolist "Which machine do you want to use?" 20 61 2 \
    $MACHINES 2> ${tmp_file}
return_value=$?

case $return_value in
  "$DIALOG_OK")
    remote_machine="$(/bin/cat ${tmp_file})"
    ;;
  "$DIALOG_CANCEL")
    echo "Cancel pressed.";;
  "$DIALOG_HELP")
    echo "Help pressed.";;
  "$DIALOG_EXTRA")
    echo "Extra button pressed.";;
  "$DIALOG_ITEM_HELP")
    echo "Item-help button pressed.";;
  "$DIALOG_ESC")
    if test -s $tmp_file ; then
      /bin/rm -f $tmp_file
    else
      echo "ESC pressed."
    fi
    ;;
esac

if [ -z "${remote_machine}" ]; then
  /usr/bin/dialog \
  	--clear  \
	--title "Error, no machine selected?" --clear "$@" \
       	--msgbox "No machine was selected!. Will exit now..." 15 30
  exit 100
fi

# Ask for the password
/bin/rm -f ${tmp_file}
/usr/bin/dialog \
  --title "$TITLE" \
  --clear  \
  --insecure \
  --passwordbox "Please enter your remote password for ${remote_machine}\n" 16 51 2> $tmp_file
return_value=$?
passwd=$(/bin/cat ${tmp_file})
/bin/rm -f "$tmp_file"
if [ -z "${passwd}" ]; then
  /usr/bin/dialog \
  	--clear  \
	--title "Error, empty password" --clear "$@" \
       	--msgbox "Empty password!" 15 30
  exit 100
fi

# Try to connect
case $return_value in
  "$DIALOG_OK")
    /usr/bin/mkdir -p -v "$HOME"/logs
    /usr/bin/xfreerdp /cert-ignore /sound:sys:alsa /f /u:"$REMOTE_USER" /v:"${remote_machine}" /p:"${passwd}"| \
    /usr/bin/tee "$HOME"/logs/"$SCRIPT_NAME"-"$remote_machine".log
    ;;
  "$DIALOG_CANCEL")
    echo "Cancel pressed.";;
  "$DIALOG_HELP")
    echo "Help pressed.";;
  "$DIALOG_EXTRA")
    echo "Extra button pressed.";;
  "$DIALOG_ITEM_HELP")
    echo "Item-help button pressed.";;
  "$DIALOG_ESC")
    if test -s $tmp_file ; then
      /bin/rm -f $tmp_file
    else
      echo "ESC pressed."
    fi
    ;;
esac
```


## Let's recap

* You can use Bash built in read to get information from your users
* You can check if repetitive information is already available to avoid reading them from the environment
* You don't save passwords without encryption. [KeepPassXC](https://keepassxc.org/) or [Vault](https://www.hashicorp.com/products/vault) are excellent tools you can use to avoid hardcoding sensitive information on the wrong places.
* You want a nicer UI? You can use [Dialog](https://invisible-island.net/dialog/) and other readily available tools to make it happen
* Always validate your inputs and check for errors!


