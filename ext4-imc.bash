#!/bin/bash

#### See https://ext4.wiki.kernel.org/index.php/Ext4_Disk_Layout#Inode_Table

## Terminal measures:
x="$(( $(tput cols) / 2 ))"   # Width of the terminal.
y="$(( $(tput lines) /  2 ))" # Height of the terminal.

## File descriptors:
declare -A types     # Declare an associative array with file descriptors.
types[f]="0x8000"    # File
types[l]="0xA000"    # Link
types[s]="0xC000"    # Socket
types[d]="0x4000"    # Directory
types[p]="0x1000"    # Named pipe
types[b]="0x6000"    # Block device
types[c]="0x2000"    # Character device

## Cleanup function:
function cleanup() {
    tput cvvis        # Make the cursor vsible
    tput rmcup        # Restore saved terminal contents.
    stty sane         # Fix problems caused by read -s
    exit 0            # Exit gracefully.
}

## Function to clear the notification area:
function reset() {
    tput cup $((y-3)) $((x-40))  # Put the cursor at the begin.
    printf "% *s\n" 30           # Print 30 spaces.
}

## Function to notify a error to the user:
function error() {
    reset                                            # Clear the notification area.
    [[ "$1" == "type"    ]] && color="\033[1;37m"    # If $1 is "type", white.
    [[ "$1" =~ ^user_.$  ]] && color="\033[1;32m"    # If $1 is "user_*", green.
    [[ "$1" =~ ^group_.$ ]] && color="\033[1;33m"    # If $1 is "group_*", orange.
    [[ "$1" =~ ^other_.$ ]] && color="\033[1;31m"    # If $1 is "other_*", red.
    tput cup $((y-3)) $((x-40))                      # Put the cursor at the begin.
    printf "\033[0;31mWrong input on ${color}$1\033[0;31m field!" # Print the error.
}

## Function to print the result:
function result() {
    reset                                            # Clear the notification area.
    tput cup $((y-3)) $((x-40))                      # Put the cursor at the begin.
    printf "\033[1;32mOctal mode:\033[1;34m $@"      # Print the result.
}

## If the terminal is smaller than 96x16, exit gracefully (self-explainatory).
if [ $x -lt 48 ] || [ $y -lt 8 ]; then
    echo "Error, I need a minimum of 96x16 lines to run"
    exit 0
fi

## Manage terminal:
trap cleanup EXIT SIGHUP SIGINT SIGTERM # Call cleanup function when ^C
tput smcup                              # Save terminal contents.
tput civis                              # Make the cursor misible.

## Print type help:
tput cup $((y-6)) $((x-48)) # Put the cursor at the begin of the first line of the help.
printf "\033[1;37m#\033[0;37m is the inode type: \033[1;37mf\033[0;37mile, \033[1;37md\033[0;37mirectory, \033[1;37ml\033[0;37mink, named \033[1;37mp\033[0;37mipe, \033[1;37ms\033[0;37mocket, \033[1;37mc\033[0;37mharacter device or \033[1;37mb\033[0;37mlock device."

## Print permission help:
tput cup $((y-5)) $((x-48)) # Put the cursor at the begin of the second line of the help.
printf "\033[1;37m###\033[0;37m is the permission (\033[1;32mu\033[0;37mser, \033[1;33mg\033[0;37mroup or \033[1;31mo\033[0;37mther): \033[1;36mr\033[0;37mead, \033[1;36mw\033[0;37mrite, e\033[1;36mx\033[0;37mecute, \033[1;36mhyphen\033[0;37m or \033[1;36mspace\033[0;37m to skip."
tput cup $((y-4)) $((x+11)) # Put the cursor at the begin of the third line of the help.
printf "s\033[1;36mt\033[0;37micky bit and executable, "
tput cup $((y-3)) $((x+11)) # Put the cursor at the begin of the fourth line of the help.
printf "s\033[1;36mT\033[0;37micky bit not executable, "
tput cup $((y-2)) $((x+11)) # Put the cursor at the begin of the fifth line of the help.
printf "\033[1;36ms\033[0;37metuid/setgid and executable, "
tput cup $((y-1)) $((x+11)) # Put the cursor at the begin of the sixth line of the help.
printf "\033[1;36mS\033[0;37metuid/setgid not executable. "

## Print equal signs below the text
tput cup $((y-2)) $((x-5)) # Put the cursor in the line inmediately at the bottom of input.
printf "\033[1;37m=\033[1;32m===\033[1;33m===\033[1;31m==="

## Endless loop:
while :; do

    ## Clear the input area:
    tput cup $((y-3)) $((x-5))   # Put the cursor at the begin of the input area.
    printf "% *s\n" 16           # Print 16 spaces.

    ## Print hash signs in the input area:
    tput cup $((y-3)) $((x-5))             # Put the cursor at the begin of the input area.
    printf "\033[1;37m#"                   # Print a white hash for the type.
    printf "\033[1;36m#########"           # Print 9 turquoise hashes for the permission.

    ## Loop through all variables to make a proper input:
    for var in \
               type                    \
               user_r  user_w  user_x  \
               group_r group_w group_x \
               other_r other_w other_x
    do
    
        ## Assign colors to fields:
        [[ "$var" == "type"    ]] && color="\033[1;37m"    # If $1 is "type", white.
        [[ "$var" =~ ^user_.$  ]] && color="\033[1;32m"    # If $1 is "user_*", green.
        [[ "$var" =~ ^group_.$ ]] && color="\033[1;33m"    # If $1 is "group_*", orange.
        [[ "$var" =~ ^other_.$ ]] && color="\033[1;31m"    # If $1 is "other_*", red.

        ## Messy section (if it ain't broke, don't fix it):
        if [[ "$var" =~ ^(user|group|other)_[rw]$ ]]; then
            regex='^[-[:space:]'"${var: -1}"']$'
        elif [[ "$var" =~ ^(user|group|other)_x$ ]]; then
            if [[ "$var" =~ ^(user|group)_x$ ]]; then
                regex='^[-[:space:]xsS]$'
            else
                regex='^[-[:space:]xtT]$'
            fi
        else
            regex='^[-fdlpscb]$'
        fi

        ## Change the pointer position:
        tput cup $((y-4)) $(((x-5)+counter))     # Put the cursor on the new pointer position.
        printf "${color}_"                       # Print the pointer on it's new position.
        tput cup $((y-4)) $(((x-5)+(counter-1))) # Put the cursor on the old pointer position.
        printf " "                               # Remove the old pointer.

        ## Infinite loop until there is a valid input for the current character:
        while :; do
            tput cup $((y-3)) $(((x-5)+counter))  # Put the cursor on current character. (not needed, read doesn't show nothing)
            printf "$color"; read -sn 1 $var      # Read a character in silent mode.
            if [[ "${!var}"  =~ $regex ]]; then   # If there is a valid input:
                reset                                 # Clear error notification if any.
                break                                 # Exit from this loop.
            else                                  # Else:
                [[ "$var" == "type" ]] && error type ||  error ${var::-2} # Dirty fix, fix later.
            fi
        done

        ## Print the entered value (as read silent mode does not echo it)
        tput cup $((y-3)) $(((x-5)+counter)) # Put the cursor on current character.
        printf "${!var}"                     # Print the current character.
        
        ## Increment the counter:
        ((counter++))
    done

    ## Post-read:
    counter=0                   # Reset the counter.
    read -n 1                   # Wait for Return or another character.
    tput cup $((y-4)) $((x+4))  # Put the cursor on the pointer position.
    printf " "                  # Clear the pointer.

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
    
    ## Final commands:
    mode=$(printf "%o" $mode)  # Convert mode to octal (before this is decimal).
    result $mode               # Print the octal mode.
    mode=0                     # Reset the mode.
done
