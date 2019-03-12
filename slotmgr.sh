#!/bin/bash
#
# +===================================================+
# |                 © 2019 Privex Inc.                |
# |               https://www.privex.io               |
# +===================================================+
# |                                                   |
# |        Originally Developed for internal use      |
# |        at Privex Inc                              |
# |                                                   |
# |        Core Developer(s):                         |
# |                                                   |
# |          (+)  Chris (@someguy123) [Privex]        |
# |                                                   |
# +===================================================+
#
# Slot Manager - Bash script to control servers over IPMI with ease
# Copyright (c) 2019    Privex Inc. ( https://www.privex.io )
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Except as contained in this notice, the name(s) of the above copyright holders
# shall not be used in advertising or otherwise to promote the sale, use or
# other dealings in this Software without prior written authorization.
#
# tl;dr; include the above license & copyright notice if you modify/distribute/copy
# some or all of this project.
#
# Github: https://github.com/privex/slotmgr
#
# --- Slot Manager (slotmgr) ---
# 
# SlotMgr is a tool developed at Privex Inc. by @someguy123 for controlling servers over IPMI in 
# a more convenient way.
#
# It loads a list a servers from a CSV config file located at "$FILE" with each row containing 
# the rack slot number, an alias for the server, the BMC IP address, the IPMI username, 
# and the IPMI password.
#
# This allows you to see the status of a server rack simply by typing
#
#    $ slotmgr list
#       Slot    Name        IP          Status
#       1       dbserver    10.1.0.2    On
#       2       webserver   10.1.0.3    Off
#       On: 1   Off: 1      Dead: 0
#
# Thanks to aliases, there's no need to remember the IPMI IP or slot number
# to access basic functions such as power control and Serial-over-LAN
#
#    $ slotmgr power dbserver cycle
#
# By default, ipmitool's serial-over-lan escape key conflicts with SSH, which
# is extremely frustrating. To solve this, we set the default to '!'.
#
#    $ slotmgr sol dbserver
#    Escape command is '!', use <enter>!. (newline exclaim dot) to exit.
#    [SOL Session operational.  Use !? for help]
#    
#    root@dbserver # poweroff
#
# So the server is powered off... but SOL doesn't close, and does not respond to CTRL-C / D
# To close an IPMI SOL connection, simply press these three keys: <CR>!. (enter, exclaim, dot)
#
##########################


# File to load servers from (CSV)
# Format: slot,name,bmc_ip,user,pass
# do not use quotes or spacing between commas to avoid issues
#
# to use default user/pass, put them as "none"
# e.g. 1,MyServer,10.1.2.3,none,none
#
FILE="/etc/pvxslotcfg"

# Default BMC Login
# Most IPMI controllers use admin:admin - so this is the default.
USERNAME=admin
PASSWORD=admin

# Initialise arrays for searching by slot/name/ip
SLOTS=()
NAMES=()
IPS=()
USERS=()
PASSWORDS=()

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`
bold=`tput bold`
underline=`tput smul`


load_config() {
    IFS=','
    while read -r slot name ip user pass; do
        SLOTS+=($slot)
        NAMES+=($name)
        IPS+=($ip)
        USERS+=($user)
        PASSWORDS+=($pass)
    done < $FILE
    unset IFS
}

help() {
    echo "
    Usage: $0 [options] command [host] [command args]

    Slot Manager - by Privex Inc. (https://www.privex.io)

      For easy command line IPMI control of physical servers.

    = = = = = = = = = = = = = = = = = = = = = =

    Slot Config File

        The slot config file is used to define the servers you want to manage.

        It's format is a very basic CSV - no quotes, no spacing between commas
        with one server per line, specifying the rack slot, name, bmc ip, user, and pass

        To use the default \$USERNAME and \$PASSWORD enter 'none' as the user/pass

        Example:

        1,MyServer,10.1.2.3,none,none
        4,OtherServer,10.1.5.5,john,secretpass

    Slot config location: $FILE


    Options:
        -s | --slot
            Parse host as slot (e.g. $0 power 5 status)
            By default, host is searched by name e.g. cust06 (case insensitive)

        -v | --verbose
            Show debugging output

        -u | --username [username]
            Default username to use if not set in slot config

        -p | --password [password]
            Default password to use if not set in slot config

        -c | --config [file_path]
            Load a different slot config than defined in \$FILE


    Commands:
        list                    - List all hosts with power status
            E.g.  $0 list

        power [host] [action]   - Power a server on/off/reset/cycle
            E.g.  $0 power cust06 on

        sol [host]              - Serial-over-lan. Default escape char is '!'
            E.g.  $0 sol cust06

        ipmi [host] [args]      - passthru to ipmitool
            E.g.  $0 ipmi cust06 power status
    "

}

# Argument Parsing taken from https://stackoverflow.com/a/29754866
# saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail -o noclobber -o nounset

! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo "I’m sorry, `getopt --test` failed in this environment."
    exit 1
fi

OPTIONS=svupc
LONGOPTS=slot,verbose,username,password,config

# -use ! and PIPESTATUS to get exit code with errexit set
# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

v=n usename=y
# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -s|--slot)
            usename=n
            shift
            ;;
        -v|--verbose)
            v=y
            shift
            ;;
        -u|--username)
            shift
            USERNAME="$1"
            shift
            ;;
        -p|--password)
            shift
            PASSWORD="$1"
            shift
            ;;
        -c|--config)
            shift
            FILE="$1"
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

set +o errexit


# now that arguments have been parsed, we can load the slot config
load_config

debug() {
    # echo to standard error to allow debugging inside of functions that return via echo
    if [[ "$v" == 'y' ]]; then echo "DEBUG: $1" >&2; fi
}

# get_bmc_user [slot/name]
# outputs ipmi username for a given slot num or name
# if user is 'none', outputs default $USERNAME
get_bmc_user() {
    local ARR=(${SLOTS[@]})
    if [[ "$usename" == 'y' ]]; then
        debug "Searching for $1 via name"
        ARR=(${NAMES[@]})
    else
        debug "Searching for $1 via slot number"
    fi
    # Enable case insensitive matches (-u unsets later)
    shopt -s nocasematch
    debug "nocasematch enabled"
    for i in "${!ARR[@]}"; do
        local k=${ARR[$i]}
        local u=${USERNAMES[$i]}

        if [[ "$k" == "$1" ]]; then
            debug "Checking $1 against $k"
            if [[ "$u" == "none" ]]; then
                echo "$USERNAME"
            else
                echo $u
            fi
            shopt -u nocasematch
            return 0
        fi
    done
    # NOT FOUND
    shopt -u nocasematch
    debug "Host not found"
    return 1
}

# get_bmc_pass [slot/name]
# outputs ipmi password for a given slot num or name
# if pass is 'none', outputs default $PASSWORD
get_bmc_pass() {
    local ARR=(${SLOTS[@]})
    if [[ "$usename" == 'y' ]]; then
        debug "Searching for $1 via name"
        ARR=(${NAMES[@]})
    else
        debug "Searching for $1 via slot number"
    fi
    # Enable case insensitive matches (-u unsets later)
    shopt -s nocasematch
    debug "nocasematch enabled"
    for i in "${!ARR[@]}"; do
        local k=${ARR[$i]}
        local u=${PASSWORDS[$i]}

        if [[ "$k" == "$1" ]]; then
            debug "Checking $1 against $k"
            if [[ "$u" == "none" ]]; then
                echo "$PASSWORD"
            else
                echo $u
            fi
            shopt -u nocasematch
            return 0
        fi
    done
    # NOT FOUND
    shopt -u nocasematch
    debug "Host not found"
    return 1
}

get_bmc_ip() {
    local ARR=(${SLOTS[@]})
    if [[ "$usename" == 'y' ]]; then
        debug "Searching for $1 via name"
        ARR=(${NAMES[@]})
    else
        debug "Searching for $1 via slot number"
    fi
    # Enable case insensitive matches (-u unsets later)
    shopt -s nocasematch
    debug "nocasematch enabled"
    for i in "${!ARR[@]}"; do
        k=${ARR[$i]}
        ip=${IPS[$i]}
        if [[ "$k" == "$1" ]]; then
            debug "Checking $1 against $k"
            echo $ip
            shopt -u nocasematch
            return 0
        fi
    done
    # NOT FOUND
    shopt -u nocasematch
    debug "Host not found"
    return 1
}

_ipmi() {
    ipmitool -H $1 -R 1 -I lanplus -U $USERNAME -P $PASSWORD "${@:2}"
}

ipmi() {
    # Mute error info in non-verbose mode.
    if [[ $v == 'y' ]]; then
        _ipmi "$@"
    else
        _ipmi "$@" 2> /dev/null
    fi
}

ipmi_pass() {
    if [ "$#" -lt 3 ]; then
        echo "ERR: Invalid usage "
        echo "Usage: $0 ipmi [host] flags command"
        exit 4
    fi
    host=$2
    cmd=$3
    debug "Finding BMC IP for host $host"
    ip=$(get_bmc_ip $host)
    if [[ "$?" -ne 0 ]]; then
        echo "ERR: Host $host not found in database file"
        exit
    fi
    ipmi $ip "${@:3}"
}

list() {
    total_dead=0
    total_on=0
    total_off=0
    echo -e "Slot\tName    \tIP\tStatus"
    for i in "${!SLOTS[@]}"; do
        slot=${SLOTS[$i]}
        name=${NAMES[$i]}
        ip=${IPS[$i]}
        status=$(ipmi $ip power status)
        if [[ "$?" -ne 0 ]]; then
            status="DEAD"
            ((total_dead++))
        else
            echo $status | grep -q 'is on'
            if [[ "$?" -ne 0 ]]; then
                status="off"
                ((total_off++))
            else
                status="on"
                ((total_on++))
            fi
        fi
        echo -n -e "$slot\t"
        echo -n -e "$name    \t"
        echo -n -e "$ip\t"
        if [[ "$status" == 'on' ]]; then
            echo -e "${green}On${reset}"
        elif [[ "$status" == 'off' ]]; then
            echo -e "${red}Off${reset}"
        else
            echo -e "${bold}${underline}${red}DEAD${reset}"
        fi

    done
    echo -e "On: $total_on\t Off: $total_off\t Dead: $total_dead"
}

power() {
    debug "Args received:' $*'"
    debug "Number of args: $#"
    if [ "$#" -ne 3 ]; then
        echo "ERR: Invalid usage "
        echo "Usage: $0 power [host] [on|off|reset|cycle|status]"
        exit 4
    fi
    host=$2
    cmd=$3
    debug "Finding BMC IP for host $host"
    ip=$(get_bmc_ip $host)
    if [[ "$?" -ne 0 ]]; then
        echo "ERR: Host $host not found in database file"
        exit
    fi
    echo "Host: $host CMD: $cmd BMC IP: $ip"
    ipmi "$ip" power "$cmd"
}

sol() {
    echo "Escape command is '!', use <enter>!. (newline exclaim dot) to exit."
    sleep 2
    if [ "$#" -ne 2 ]; then
        echo "ERR: Invalid usage "
        echo "Usage: $0 sol [host]"
        exit 4
    fi
    host=$2
    debug "Finding BMC IP for host $host"
    ip=$(get_bmc_ip $host)
    if [[ "$?" -ne 0 ]]; then
        echo "ERR: Host $host not found in database file"
        exit
    fi
    debug "Connecting to IPMI $ip for $host"
    ipmi $ip -e! sol activate
}
# ipmitool -H 10.1.0.5 -I lanplus -U admin -P admin power on
# $? = 0 on success, 1 on failure


if [ "$#" -lt 1 ]; then
    echo "ERR: A command must be specified"
    help
    exit 4
fi

case "$1" in
    help)
        help
        ;;
    list)
        list
        ;;
    power)
        power "$@"
        ;;
    sol)
        sol "$@"
        ;;
    ipmi)
        ipmi_pass "$@"
        ;;
    *)
        echo "ERR: Invalid command."
        help
        ;;
esac

