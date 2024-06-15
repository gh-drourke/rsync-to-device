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

# Function to get disk information
get_disk_info() {
    local device_path=$1
    local disk_path
    local model
    local vendor

    # Extract the disk path from the partition path
    disk_path=$(lsblk -no pkname "$device_path" | head -n 1)

    # Check if disk path extraction was successful
    if [ -z "$disk_path" ]; then
        echo "Invalid device path: $device_path"
        return 1
    fi

    # Construct the full disk path
    disk_path="/dev/$disk_path"

    # Get the model number using udevadm
    model=$(udevadm info --query=all --name="$disk_path" | grep "ID_MODEL=" | cut -d= -f2)
    if [ -z "$model" ]; then
        model="unknown"
    fi

    # Get the vendor using udevadm
    vendor=$(udevadm info --query=all --name="$disk_path" | grep "ID_VENDOR=" | cut -d= -f2)
    if [ -z "$vendor" ]; then
        vendor="unknown"
    fi

    # Get the size of the disk in human-readable form using lsblk
    size=$(lsblk -no SIZE -d "$disk_path" | head -n 1)
    if [ -z "$size" ]; then
        size="unknown"
    fi

    echo "vendor:${vendor}; model:${model}; size:${size}"
}

# Function to list available devices and allow user to select one
select_device() {
    local devices
    devices=$(sudo fdisk -l | grep -e '^/dev/sd' | awk '{print $1}')
    local count=1

    echo "Available devices:"
    for device in $devices; do
        device_info=$(get_disk_info "$device")
        echo "  $count) $device - $device_info"
        count=$((count + 1))
    done
    echo "------------"

    while true; do
        read -r -p "Select the device number to mount: " device_number
        if [[ $device_number =~ ^[0-9]+$ ]] && ((device_number >= 1 && device_number < count)); then
            search_device=$(echo "$devices" | sed -n "${device_number}p")
            echo "Device $search_device selected."
            break
        else
            echo "Invalid selection. Please enter a number between 1 and $((count - 1))."
        fi
    done

    if ! prompt_confirm "Mount device $search_device?"; then
        cleanup
        exit 0
    fi
}

main() {
    print_info "$1"
    select_device
    echo
    if verify_mount_point $MNT_POINT; then
        if sudo mount "$search_device" "$MNT_POINT"; then
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
    echo "example: rsync2dev sdc1"
    exit 0
fi
main "$1"
# eof
