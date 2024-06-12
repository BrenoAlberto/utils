#!/bin/bash

confirm() {
    while true; do
        read -p "$1 [y/n]: " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

print_progress() {
    echo -ne "\r\033[K"
    echo -ne "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

shred_files() {
    local count=0
    local total_files=$(wc -l < "$1")

    while IFS= read -r file; do
        sudo shred -u -z -n 0 "$file" 2>/dev/null
        ((count++))
        if ((count % UPDATE_INTERVAL == 0)) || ((count == total_files)); then
            print_progress "Shredded $count/$total_files files in $1."
        fi
    done < "$1"
}

read -p "Enter the target directory to shred files: " TARGET_DIR

if [ ! -d "$TARGET_DIR" ]; then
    echo "The specified directory '$TARGET_DIR' does not exist or is not a directory."
    exit 1
fi

if ! confirm "Are you sure you want to shred files in the directory '$TARGET_DIR'?"; then
    echo "Operation cancelled."
    exit 1
fi

FILE_LIST="/tmp/filelist.txt"
NUM_PROCESSES=16
UPDATE_INTERVAL=1000

export UPDATE_INTERVAL

sudo find "$TARGET_DIR" -type f > "$FILE_LIST"

TOTAL_FILES=$(wc -l < "$FILE_LIST")

echo "Total files found: $TOTAL_FILES"

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo "No files found to shred."
    exit 1
fi

split -n l/$NUM_PROCESSES "$FILE_LIST" "${FILE_LIST}_part"

export -f shred_files print_progress

# Use xargs to run the shredding in parallel
ls "${FILE_LIST}_part"* | xargs -P $NUM_PROCESSES -I {} bash -c 'shred_files "$@"' _ {}

wait

echo "Deleting temporary file lists..."
sudo rm "${FILE_LIST}" "${FILE_LIST}_part"*

echo "Deleting the target directory..."
sudo rm -rf "$TARGET_DIR"

echo "All files shredded and temporary lists deleted."

echo "Operation completed successfully."
