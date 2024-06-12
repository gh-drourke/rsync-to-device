#!/bin/bash
# File name: rsync2dev

# Note: rsync
# recommended not to use NFS or Samba, because:
# 1. Locking protocols are inefficient.
# 2. Issues with special files.
# 3. Use ssh
#
# Note: device
# A device is an unmounted file system.
# A device is mounted at a mount point.
# A device must be mounted before it can be accessed.

# Default Configuration (set by user)
MNT_POINT=/mnt/"backup"
DST_DIR="/Backups/2024-T480s-home-backup"
SRC_DIR=~

# Global Variables
MNT_PATH_FULL="$MNT_POINT$DST_DIR"
USER_ID=$(id -u)
USER_NAME=$(id -un)

# Functions

# Function to give confirm message and read response
prompt_confirm() {
    # usage example: prompt_confirm "Overwrite File?" || exit 0
    local reply
    while true; do
        read -r -n 1 -p "${1:-Continue?} [y/n]: " reply
        case $reply in
        [yY]) return 0 ;; # Success
        [nN]) return 1 ;; # Failure
        *) printf " \033[31m %s \n\033[0m" "invalid input" ;;
        esac
    done
}

# Function to test if $1 is a directory
is_directory() {
    local DIR=$1
    if [[ -d $DIR ]] && [[ -n $DIR ]]; then
        return 0 # Success
    else
        return 1 # Failure
    fi
}

# Function test if mount point given by $1 is being used
is_mount_point_used() {
    local mount_point="$1"

    if findmnt "$mount_point" --noheadings >/dev/null; then
        # printf "..%s\n" "$mount_point: device is mounted"
        return 0 # Success
    else
        # echo "No device is mounted at $mount_point."
        # printf "..%s\n" "$mount_point: no device is mounted"
        return 1 # Failure
    fi
}

# Function to ensure that mount point exist and is Not already mounted
# return 0 if can proceed, return 1 if errors.
verify_mount_point() {
    local MP=$1
    if is_directory "$MP"; then
        printf "%s\n" ".. $MP -> Caution - already exist" # TODO
        if ! is_mount_point_used "$MP"; then
            printf "%s\n" ".. $MP -> Mount point is available"
            return 0 # Success
        else
            printf "%s\n" ".. $MP -> Mount point is NOT available"
            return 1 # Failure
        fi
    else
        printf "%s\n" ".. $MP -> does not exist ..."
        if sudo mkdir "$MP"; then
            printf "%s\n" ".. $MP -> is now created"
            return 0 # Success
        else
            printf "%s\n" ".. $MP -> could not create"
            return 1 # Failure
        fi
    fi
}

# Function to ensure that destination path exists with proper ownership
# return 0 TRUE if OK to proceed
confirm_dest_path() {
    local PATH=$1
    if is_directory "$PATH"; then
        printf "%s\n" ".. ""$PATH: -> path exist"
        return 0 # Success
    else
        printf "%s\n" ".. $PATH -> path does not exist"
        prompt_confirm " .. Create path?" || exit 0
        printf "%s\n" ".. creating path"
        if sudo mkdir -p "$PATH"; then
            printf "%s\n" "..""$PATH -> path  created"
            printf "%s\n" ".. changing ownership to user"
            if sudo chown -R "$USER_ID:$USER_ID" "$PATH"; then
                printf "%s\n" ".. -> ownership changed"
                return 0 # Success
            else
                printf "%s\n" ".. -> could not change ownership"
                return 1 # Failure
            fi
        else
            printf "%s\n" ".. -> could not create path"
            return 1 # Failure
        fi
    fi
}

# Function to do the actual backup using rsync
do_backup() {
    rsync -avp --delete --delete-excluded \
        --exclude .cache --exclude .thunderbird --exclude .config/BraveSoftware --exclude .config/google-chrome --exclude Downloads --exclude 'Pictures' \
        --exclude .local/share/Trash \
        $SRC_DIR "$MNT_PATH_FULL"

    # rsync -avp --delete --delete-excluded $SRC_DIR "$MNT_DEST_PATH"
}

# Function to unmount and remove`MNT_POINT`
cleanup() {
    printf "\n%s\n" "Cleanup ..."

    if is_mount_point_used $MNT_POINT; then
        printf "  %s\n" ".. $MNT_POINT -> umounting"
        sudo umount "$MNT_POINT"
    else
        printf "  %s\n" "Nothing to unmount"
    fi

    if is_directory "$MNT_POINT"; then
        printf "  %s\n" ".. $MNT_POINT -> removing"
        sudo rmdir "$MNT_POINT"
    else
        printf "  %s\n" "No mount point directory to remove"
    fi

    printf "  %s\n" "Done!"
}

# Function to provide textual context to user
print_info() {
    printf "%s\n" "User id:               $USER_ID"
    printf "%s\n" "User name is:          $USER_NAME"
    printf "\n"
    printf "%s\n" "Source Directory:      $SRC_DIR"
    printf "%s\n" "Mount point:           $MNT_POINT"
    printf "%s\n" "Destination Directory: $DST_DIR"
    printf "%s\n" "Full Target Path:      $MNT_PATH_FULL"
    printf "%s\n" "Device Given:          $1"
}

# Function to verify device given as an argument is valid
verify_device() {
    search_device="dev/$1"
    # List and Mount device
    printf "\n%s\n" "Devices available"
    output=$(sudo fdisk -l | grep -e '^/dev/sd')
    output_fmt=$(echo "$output" | sed 's/^/  /')
    echo "$output_fmt"
    echo $'------------'

    # Check if the search device exists in the list (-q is for quiet search)
    if echo "$output" | grep -q "$search_device"; then
        echo "Device $search_device found."
    else
        echo "Device $search_device not found."
        exit 1
    fi

    # prompt_confirm "$search_device: Device to be mounted" || exit 0
    # if ! prompt_confirm "$search_device: Device to be mounted"; then
    if ! prompt_confirm "Mount device?"; then
        cleanup
        exit 0
    fi
    # Search for the search_device in the formatted output
    if echo "$output_fmt" | grep -q "$search_device"; then
        printf "\n%s\n" "$search_device: OK. Found in device(s) available."
    else
        printf "\n%s\n" "$search_device: Error. Not found in device(s) available."
        printf "%s\n" "exiting!"
        cleanup
        exit 1
    fi
}

main() {
    print_info "$1"
    verify_device "$1"
    echo
    if verify_mount_point $MNT_POINT; then
        if sudo mount "/dev/$1" "$MNT_POINT"; then
            printf "%s\n" ".. $MNT_POINT -> is now mounted"
        else
            printf "%s\n" ".. $MNT_POINT -> can not be mounted"
            exit 1
        fi
    fi

    if ! confirm_dest_path $MNT_PATH_FULL; then
        printf "%s\n" "dest path: not confirmed"
    else
        echo
        # prompt_confirm "Continue to backup?" || exit 0
        if ! prompt_confirm "Continue to backup?"; then
            cleanup
            exit 0
        fi

        echo
        do_backup
    fi

    cleanup
    exit 0
}

# Command line must identify device to be mounted
if [ -z "$1" ]; then
    echo "Usage: No arguement given for device to be mounted"
    echo "example: rssdx sdc1"
    exit 0
fi
main "$1"
# eof
