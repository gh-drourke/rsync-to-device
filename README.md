<!--toc:start-->

```
rsync2dev   .   .   .   .   .   .   .   .   .   .   .   .   .   .  16
   Purpose  .   .   .   .   .   .   .   .   .   .   .   .   .   .  18
   Usage.   .   .   .   .   .   .   .   .   .   .   .   .   .   .  22
   Requirements .   .   .   .   .   .   .   .   .   .   .   .   .  31
   Default Configuration.   .   .   .   .   .   .   .   .   .   .  36
   Functions.   .   .   .   .   .   .   .   .   .   .   .   .   .  44
   Example  .   .   .   .   .   .   .   .   .   .   .   .   .   .  56
   Exit Codes   .   .   .   .   .   .   .   .   .   .   .   .   .  64
   Notes.   .   .   .   .   .   .   .   .   .   .   .   .   .   .  70
   License  .   .   .   .   .   .   .   .   .   .   .   .   .   .  75
```

<!--toc:end-->

# rsync2dev

## Purpose

The `rsync2dev` script is designed to backup data from a native filesystem directory to an external filesystem. It uses `rsync` to perform the backup, ensuring that the destination path exists and is correctly mounted before proceeding.

## Usage

```sh
    rsync2dev sdx
```

/dev is implied in the device path.
sdx should be of the form sda1, sdc1, etc.

## Requirements

- rsync must be installed on the system.
- The script should be run with sufficient privileges to mount devices and create directories (typically requires sudo).

## Default Configuration

- MNT_POINT=/mnt/backup
- DST_DIR="/Backups/2024-T480s-home-backup"
- SRC_DIR=~

These defaults can be modified by user within the script to fit their needs.

## Global Variables

- MNT_PATH_FULL, USER_ID, and USER_NAME are derived from the defaults and current user information.
- This ensures the backup path is correctly formed and accessible.

## Functions

- `prompt_confirm()`: Prompts for user confirmation.
- `is_directory()`: Checks if a path is a directory.
- `is_mount_point_used()`: Checks if a mount point is in use.
- `verify_mount_point()`: Verifies and possibly creates a mount point.
- `confirm_dest_path()`: Ensures the destination path exists and has correct ownership.
- `do_backup()`: Performs the backup using rsync.
- `cleanup()`: Unmounts the device and removes the mount point.
- `print_info()`: Prints user and path information.
- `verify_device()`: Verifies the specified device exists and prompts for mounting.

## Main Execution Flow:

- Argument Check: Ensures a device argument is provided.
- main() Function: Coordinates the execution of other functions, including mounting the device, verifying paths, performing the backup, and cleaning up.

## Example

To backup data to the device sdc1:

```bash
    rsync2dev sdc1
```

## Exit Codes

- 0: Success
- 1: General error (e.g., device not found, failed to create directory)
- 2: User canceled operation

## Notes

- It is recommended not to use NFS or Samba due to inefficiencies and issues with special files.
- Ensure the device is unmounted before running the script.

## License

This script is provided as-is without any warranty. Use it at your own risk.

## TODO
