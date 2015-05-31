# ext4-imc
Bash script to calculate inode modes.
Made for this AskUbuntu thread: http://askubuntu.com/questions/626634/convert-a-file-to-directory/626731

***

**Creating a test Ext4 filesystem:**

1. First make a filesystem on a file to avoid corrupting your real filesystem:

        dd if=/dev/zero of=test_fs bs=10M count=1
   This will create a file called `test_fs` with a size of 10 megabytes.

2. Then we will create a Ext4 filesystem on it:

        mkfs.ext4 test_fs

***

**Putting some files on it:**

1. We have a fully functional filesystem. Let's mount it:

        sudo mount test_fs /mnt

2. Let's make a folder and a file.

        sudo mkdir /mnt/folder
        echo "Foo" | sudo tee /mnt/file

3. Now test that all goes well:

        ls -l /mnt

       Output should be something like this:

        total 2
        -rw-r--r-- 1 root root     0 may 21 18:53 file
        drw-r--r-- 2 root root  1024 may 21 18:55 folder

4. Then we will umount the filesystem:

        sudo umount /mnt

***

**Swapping the file and the folder:**

1. Run `debugfs` against `test_fs` with write permission (`-w` flag):

        debugfs -w test_fs

2. Convert `file` into a folder:

   * At the `debugfs` prompt, type this:

            modify_inode file

   * A prompt will appear asking you a mode. Type this:
  
            040644

   * Keep pressing <kbd>Return</kbd> to leave the resting data as-is until appears the prompt.

3. Convert `folder` into a file:

   * At the `debugfs` prompt, type this:

            modify_inode folder

   * A prompt will appear asking you a mode. Type this:
  
            0100644

   * Keep pressing <kbd>Return</kbd> to leave the resting data as-is until appears the prompt.

4. To exit `debugfs` prompt, simply hit **<kbd>q</kbd>** and then <kbd>Return</kbd>

***

**Checking that all goes well:**

1. Let's mount the test filesystem again:

        sudo mount test_fs /mnt

2. Now check the filesystem contents:

        ls -l /mnt

       Hooray! It works! See here:

        total 2
        drw-r--r-- 1 root root     0 may 21 18:53 file
        -rw-r--r-- 2 root root  1024 may 21 18:55 folder

***

**Script to calculate inode modes:**

    #!/bin/bash
    
    #### See https://ext4.wiki.kernel.org/index.php/Ext4_Disk_Layout#Inode_Table
    
    ## Terminal measures:
    x="$(( $(tput cols) / 2 ))"   # Width of the terminal.
    y="$(( $(tput lines) /  2 ))" # Height of the terminal.
    
    ## File descriptors:
    declare -A types       # Declare an associative array with file descriptors.
    types[f]='0x8000'      # File
    types[l]='0xA000'      # Link
    types[s]='0xC000'      # Socket
    types[d]='0x4000'      # Directory
    types[p]='0x1000'      # Named pipe
    types[b]='0x6000'      # Block device
    types[c]='0x2000'      # Character device
    
    ## Permissions:
    declare -A permission  # Declare an associative array with prmissions.
    permission[user_S]='0x800'  # UID.
    permission[user_s]='0x840'  # UID and user can execute.
    permission[user_r]='0x100'  # User can read.
    permission[user_w]='0x80'   # User can write.
    permission[user_x]='0x40'   # User can execute.
    permission[group_S]='0x400' # GID.
    permission[group_s]='0x408' # GID and group can execute.
    permission[group_r]='0x20'  # Group can read.
    permission[group_w]='0x10'  # Group can write.
    permission[group_x]='0x8'   # Group can execute.
    permission[other_T]='0x200' # Sticky bit.
    permission[other_t]='0x201' # Sticky bit and other can execute.
    permission[other_r]='0x4'   # Other can read.
    permission[other_w]='0x2'   # Other can write.
    permission[other_x]='0x1'   # Other can execute.
    
    ## Cleanup function:
    function cleanup() {
        tput cvvis        # Make the cursor visible
        tput rmcup        # Restore saved terminal contents.
        stty sane         # Fix problems caused by read -s
        exit 0            # Exit gracefully.
    }
    
    ## Function to print at a specified position:
    function pprint() {
        tput cup $1 $2
        printf "${@:3}"
    }
    
    ## Function to clear the notification area:
    function reset() {
        pprint $((y+2)) $((x-40)) ' %.0s' {1..25} # Print 25 spaces.
    }
    
    ## Function to notify something to the user:
    function notify() {
        reset                          # Clear the notification area.
        pprint $((y+2)) $((x-40)) "$@" # Print the text.
    }
    
    ## If the terminal is smaller than 100x8, exit gracefully (self-explainatory).
    if [ $x -lt 50 ] || [ $y -lt 5 ]; then
        echo 'Error, I need a minimum of 100x10 lines to run'
        exit 0
    fi
    
    ## Initialize the terminal:
    trap cleanup EXIT SIGHUP SIGINT SIGTERM # Call cleanup function when ^C
    stty -echo  cbreak                      # Put terminal in silent mode.
    tput smcup                              # Save terminal contents.
    tput civis                              # Make the cursor inisible.
    
    ## Draw the big box:
    printf '\033[1;37m'                            # Color.
    pprint $((y-3)) $((x-48)) '\u2500%.0s' {1..97} # Upper line.
    pprint $((y+4)) $((x-48)) '\u2500%.0s' {1..97} # Lower line.
    for ((i=4;i>-4;i--)); do                       # Sides:
        pprint $((y+i)) $((x-49)) '\u2502'             # Left line.
        pprint $((y+i)) $((x+49)) '\u2502'             # Right line.
    done                                           # End sides.
    pprint $((y-3)) $((x-49)) '\u256D'             # Upper-left corner.
    pprint $((y+4)) $((x-49)) '\u2570'             # Lower-left corner.
    pprint $((y-3)) $((x+49)) '\u256E'             # Upper-right corner.
    pprint $((y+4)) $((x+49)) '\u256F'             # Lower-right corner.
    
    ## Draw the small box:
    printf '\033[1;35m'                             # Color.
    pprint $((y+1)) $((x-10)) '\u2501%.0s' {1..10}  # Upper line.
    pprint $((y+3)) $((x-10)) '\u2501%.0s' {1..10}  # Lower line.
    pprint $((y+2)) $((x-11)) '\u2503'              # Left line.
    pprint $((y+2)) $((x+00)) '\u2503'              # Right line.
    pprint $((y+1)) $((x-11)) '\u250F'              # Upper-left corner.
    pprint $((y+3)) $((x-11)) '\u2517'              # Lower-left corner.
    pprint $((y+1)) $((x+00)) '\u2513'              # Upper-right corner.
    pprint $((y+3)) $((x+00)) '\u251B'              # Lower-right corner.
    
    ## Print type help:
    pprint $((y-2)) $((x-44)) '\033[0;37mInode type: \033[1;37mf\033[0;37mile, \033[1;37md\033[0;37mirectory, \033[1;37ml\033[0;37mink, named \033[1;37mp\033[0;37mipe, \033[1;37ms\033[0;37mocket, \033[1;37mc\033[0;37mharacter device or \033[1;37mb\033[0;37mlock device.'
    
    ## Print permission help:
    pprint $((y-1)) $((x-40)) '\033[0;36mPermission (\033[1;32mu\033[0;32mser\033[0;36m, \033[1;33mg\033[0;33mroup\033[0;36m or \033[1;31mo\033[0;31mther\033[0;36m): \033[1;36mr\033[0;36mead, \033[1;36mw\033[0;36mrite, e\033[1;36mx\033[0;36mecute, \033[1;36mhyphen\033[0;36m or \033[1;36mspace\033[0;36m to skip.'
    pprint $((y+0)) $((x+8)) 's\033[1;36mt\033[0;36micky bit and executable, '
    pprint $((y+1)) $((x+8)) 's\033[1;36mT\033[0;36micky bit not executable, '
    pprint $((y+2)) $((x+8)) '\033[1;36ms\033[0;36metuid/setgid and executable, '
    pprint $((y+3)) $((x+8)) '\033[1;36mS\033[0;36metuid/setgid not executable. '
    
    ## Endless loop:
    while :; do                                   # While Linux is Open Source:
    
        ## Clear the input area:
        pprint $((y+2)) $((x-10)) '% *s\n' 10         # Print 16 spaces.
    
        ## Print mask in the input area:
        printf '\033[1;37m'                           # Color for the type.
        pprint $((y+2)) $((x-10)) '\u2588'            # Block for the type.
        printf '\033[1;36m'                           # Color for the permision.
        pprint $((y+2)) $((x- 9)) '\u2588%.0s' {1..9} # Blocks for the permission.
    
        ## Loop through all variables to make a proper input:
        for var in type {user,group,other}_{r,w,x}; do
        
            ## Assign colors and regex to fields:
            case "$var" in
                (type)    color='\033[1;37m';     regex='^[fdlpscb]$'    ;;
                
                (other_x)                         regex='^[-xtT]$'       ;;&
                (user_x|group_x)                  regex='^[-xsS]$'       ;;&
                (user_[rw]|group_[rw]|other_[rw]) regex="^[-${var: -1}]$";;&
                
                (user*)   color='\033[1;32m'                             ;;
                (group*)  color='\033[1;33m'                             ;;
                (other*)  color='\033[1;31m'                             ;;
            esac
    
            ## Change the pointer position:
            pprint $((y+3)) $(((x-10)+pointer)) "${color}\u2501"           # Print the pointer on it's new position.
            if (( pointer > 0 )); then                                     # If the pointer is not in the first position:
                pprint $((y+3)) $(((x-10)+(pointer-1))) '\033[1;35m\u2501'     # Clear the old pointer.            
            fi                                                             # End if.
            
            ## Infinite loop until there is a valid input for the current character:
            while :; do
                printf "$color"                       # Set the character color.
                IFS= read -rn 1 $var                  # Read a character (even a space).
           
                declare $var="${!var// /-}"           # Convert spaces to hyphens.
                if [[ "$var" == "type" ]]; then       # If the current variable is type:
                    declare $var="${!var//-/f}"           # Convert hyphen to f.
                fi                                    # End if.
                
                if [[ "${!var}"  =~ $regex ]]; then   # If there is a valid input:
                    reset                                 # Clear error notification if any.
                    break                                 # Exit from this loop.
                else                                  # Else:
                    notify "\033[1;31mWrong input!"       # Print the error message.
                fi
            done
    
            ## Print the entered value:
            pprint $((y+2)) $(((x-10)+pointer)) "${!var}"
            
            ## Sum the current permission:
            ((mode+=permission[${var%_*}_${!var}]))
            
            ## Increment the pointer:
            ((pointer++))
        done
    
        ## Post-read:
        unset pointer                                 # Reset the pointer.
        pprint $((y+3)) $((x-1)) "\033[1;35m\u2501"   # Clear the pointer.
        read -n 1                                     # Wait for Return or another character.
        
        ## Sum file descriptor type:
        ((mode+=${types[$type]}))
        
        ## Final commands:
        mode=$(printf "%o" $mode)                      # Convert mode to octal (before this is decimal).
        notify "\033[1;32mOctal mode:\033[1;34m $mode" # Print the octal mode.
        unset mode                                     # Reset the mode.
    done

***

**Further reading:** https://ext4.wiki.kernel.org/index.php/Ext4_Disk_Layout#Inode_Table

***

**Thanks to [@tallus](http://askubuntu.com/users/80756/tallus).** He gave me a great hint:
	

> debugfs has a modify_inode command that allows you to edit an inode
> directly which would allow you to set the file flag to a dir.

