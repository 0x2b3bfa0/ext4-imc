#!/bin/bash

x="$(( $(tput cols) / 2 ))"
y="$(( $(tput lines) /  2 ))"

declare -A types
types[f]="0x8000"
types[d]="0x4000"
types[l]="0xA000"
types[p]="0x1000"
types[s]="0xC000"
types[c]="0x2000"
types[b]="0x6000"




function cleanup() {
    tput cvvis
    tput rmcup
    stty sane
    exit 0
}

function reset() {
    tput cup $((y-3)) $((x-40))
    printf "                              "
}

function error() {
    reset
    [[ "$1" == "type" ]] && color="\033[1;37m"
    [[ "$1" =~ ^user.{2}$ ]] && color="\033[1;32m"
    [[ "$1" =~ ^group.{2}$ ]] && color="\033[1;33m"
    [[ "$1" =~ ^other.{2}$ ]] && color="\033[1;31m"
    tput cup $((y-3)) $((x-40))
    printf "\033[0;31mWrong input on ${color}$1\033[0;31m field!"
}

function result() {
    reset
    tput cup $((y-3)) $((x-40))
    printf "\033[1;32mOctal mode:\033[1;34m $@"
}

if [ $x -lt 48 ] || [ $y -lt 8 ]; then
    echo "Error, I need a minimum of 96x16 lines to run"
    exit 0
fi

trap cleanup EXIT SIGHUP SIGINT SIGTERM
tput smcup
tput civis

tput cup $((y-6)) $((x-48))
printf "\033[1;37m#\033[0;37m is the inode type: "
printf "\033[1;37mf\033[0;37mile, "
printf "\033[1;37md\033[0;37mirectory, "
printf "\033[1;37ml\033[0;37mink, "
printf "named \033[1;37mp\033[0;37mipe, "
printf "\033[1;37ms\033[0;37mocket, "
printf "\033[1;37mc\033[0;37mharacter device or "
printf "\033[1;37mb\033[0;37mlock device."
tput cup $((y-5)) $((x-48))
printf "\033[1;37m###\033[0;37m is the permission (\033[1;32mu\033[0;37mser, \033[1;33mg\033[0;37mroup or \033[1;31mo\033[0;37mther): "
printf "\033[1;36mr\033[0;37mead, "
printf "\033[1;36mw\033[0;37mrite, "
printf "e\033[1;36mx\033[0;37mecute, "
printf "\033[1;36mhyphen\033[0;37m or \033[1;36mspace\033[0;37m to skip."
tput cup $((y-4)) $((x+11))
printf "s\033[1;36mt\033[0;37micky bit and executable, "
tput cup $((y-3)) $((x+11))
printf "s\033[1;36mT\033[0;37micky bit not executable, "
tput cup $((y-2)) $((x+11))
printf "\033[1;36ms\033[0;37metuid/setgid and executable, "
tput cup $((y-1)) $((x+11))
printf "\033[1;36mS\033[0;37metuid/setgid not executable. "
tput cup $((y-2)) $((x-5))
printf "\033[1;37m=\033[1;32m===\033[1;33m===\033[1;31m==="

while :; do
    tput cup $((y-3)) $((x-5))
    printf "                "

    tput cup $((y-3)) $((x-5))
    printf "\033[1;37m#"
    printf "\033[1;36m#########"

    counter=0

    for i in type user_r user_w user_x group_r group_w group_x other_r other_w other_x; do
        [[ "$i" == "type" ]] && color="\033[1;37m"
        [[ "$i" =~ ^user.{2}$ ]] && color="\033[1;32m"
        [[ "$i" =~ ^group.{2}$ ]] && color="\033[1;33m"
        [[ "$i" =~ ^other.{2}$ ]] && color="\033[1;31m"

        if [[ "$i" =~ ^(user|group|other)_[rw]{1}$ ]]; then
            regex='^[-[:space:]'"${i: -1}"']{1}$'
        elif [[ "$i" =~ ^(user|group|other)_x$ ]]; then
            if [[ "$i" =~ ^(user|group)_x$ ]]; then
                regex='^[-[:space:]xsS]{1}$'
            else
                regex='^[-[:space:]xtT]{1}$'
            fi
        else
            regex='^[-fdlpscb]{1}$'
        fi

        tput cup $((y-4)) $(((x-5)+counter))
        printf "${color}_"
        tput cup $((y-4)) $(((x-5)+(counter-1)))
        printf " "

        while :; do
            tput cup $((y-3)) $(((x-5)+counter))
            printf "$color"; read -sn 1 $i
            if [[ "${!i}"  =~ $regex ]]; then
                reset
                break
            else
                [[ "$i" == "type" ]] && error type ||  error ${i::-2}
            fi
        done

        tput cup $((y-3)) $(((x-5)+counter))
        printf "${!i}"
        ((counter++))
    done

    read -n 1

    tput cup $((y-4)) $((x+4))
    printf " "

    [[ "$user_x" == "S" ]] && ((mode+=0x800))
    [[ "$user_x" == "s" ]] && ((mode+=0x840))
    [[ "$user_r" == "r" ]] && ((mode+=0x100))
    [[ "$user_w" == "w" ]] && ((mode+=0x80))
    [[ "$user_x" == "x" ]] && ((mode+=0x40))

    [[ "$group_x" == "S" ]] && ((mode+=0x400))
    [[ "$group_x" == "s" ]] && ((mode+=0x408))
    [[ "$group_r" == "r" ]] && ((mode+=0x20))
    [[ "$group_w" == "w" ]] && ((mode+=0x10))
    [[ "$group_x" == "x" ]] && ((mode+=0x8))

    [[ "$other_x" == "T" ]] && ((mode+=0x200))
    [[ "$other_x" == "t" ]] && ((mode+=0x201))
    [[ "$other_r" == "r" ]] && ((mode+=0x4))
    [[ "$other_w" == "w" ]] && ((mode+=0x2))
    [[ "$other_x" == "x" ]] && ((mode+=0x1))


    ((mode+=${types[$type]}))
    mode=$(printf "%o" $mode)

    result $mode

    mode=0
done
