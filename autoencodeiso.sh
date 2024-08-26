#!/bin/bash

# Configuration variables
ISO_FOLDER="/path/to/iso"
OUTPUT_FOLDER="/path/to/temp/folder"
KNOWN_DISKS_FILE="$ISO_FOLDER/known_disks.txt"
ENCODED_DISKS_FILE="$OUTPUT_FOLDER/encoded_disks.txt"
STATE_FILE="$ISO_FOLDER/state.txt"
TOKEN_TELEGRAM="REMOVED"  # Telegram bot token
CHAT_ID="REMOVED"  # Telegram chat ID

# Function to send a Telegram notification
send_telegram_notification() {

    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$message"

}

# Function to convert file size into a readable format
readable_size() {

    local size_bytes="$1"

    if (( size_bytes >= 1073741824 )); then

        # GB
        echo "$(echo "scale=1; $size_bytes/1073741824" | bc) GB"

    elif (( size_bytes >= 1048576 )); then

        # MB
        echo "$(echo "scale=1; $size_bytes/1048576" | bc) MB"

    elif (( size_bytes >= 1024 )); then

        # KB
        echo "$(echo "scale=1; $size_bytes/1024" | bc) KB"

    else

        # Bytes
        echo "$size_bytes bytes"

    fi

}

# Create the files if they do not exist
touch "$KNOWN_DISKS_FILE"
touch "$ENCODED_DISKS_FILE"
touch "$STATE_FILE"

# Check if an encoding is in progress
STATUS=$(cat "$STATE_FILE")

if [ "$STATUS" == "encoding_in_progress" ]; then
    echo "An encoding process is already in progress, stopping the script."
    exit 0
fi

# Read the known and encoded disks into arrays
mapfile -t known_disks < "$KNOWN_DISKS_FILE"
mapfile -t encoded_disks < "$ENCODED_DISKS_FILE"

# Search for disks that have not yet been encoded
new_disks=()

for disk in "${known_disks[@]}"; do

    if [[ ! " ${encoded_disks[@]} " =~ " $disk " ]] && [[ -f "$ISO_FOLDER/$disk.iso" ]]; then
        new_disks+=("$disk")
    fi

done

# If new disks are detected
if [ ${#new_disks[@]} -gt 0 ]; then

    # Mark the beginning of encoding
    echo "encoding_in_progress" > "$STATE_FILE"

    # Choose a disk for encoding (arbitrarily the first one)
    disk_to_encode="${new_disks[0]}"
    echo "Starting encoding for $disk_to_encode.iso"

    # Send a Telegram notification for a new disk
    send_telegram_notification "New ISO to encode: $disk_to_encode.iso"

    # Create a subfolder for the ISO in the output folder
    output_subfolder="$OUTPUT_FOLDER/$disk_to_encode"
    mkdir -p "$output_subfolder"

    # Mount the ISO temporarily
    mount_folder="/mnt/$disk_to_encode"
    mkdir -p "$mount_folder"
    sudo mount -o loop "$ISO_FOLDER/$disk_to_encode.iso" "$mount_folder"
    
    # Search for VOB files
    vob_files=($(find "$mount_folder" -type f -iname "*.VOB"))

    # Send a notification listing the found VOB files with their sizes

    if [ ${#vob_files[@]} -gt 0 ]; then
        vob_message="VOB files found for $disk_to_encode:"

        for vob_file in "${vob_files[@]}"; do

            # Get the file size in bytes
            size_bytes=$(stat -c%s "$vob_file")

            # Convert the size to a readable unit
            readable_size=$(readable_size "$size_bytes")

            # Add to the list of files with their size
            vob_message="$vob_message
$(basename "$vob_file") - $readable_size"

        done

        send_telegram_notification "$vob_message"

    else

        send_telegram_notification "No VOB files found for $disk_to_encode.iso"

        echo "no_new_disk" > "$STATE_FILE"
        sudo umount "$mount_folder"
        rmdir "$mount_folder"

        # Mark the disk as encoded
        echo "$disk_to_encode" >> "$ENCODED_DISKS_FILE"
    
        exit 0

    fi

    # Counter for encoded VOB files
    total_vob=${#vob_files[@]}
    encoded_vob=0

    # Encoding VOB files one by one

    for file in "${vob_files[@]}"; do

        relative_path="${file#$mount_folder/}"
        output_file="$output_subfolder/$(basename "${relative_path%.*}").mp4"
        mkdir -p "$(dirname "$output_file")"

        # Encoding via HandBrakeCLI
        sudo HandBrakeCLI --input "$file" --output "$output_file" --format av_mp4 --optimize --encoder x264 --encoder-preset medium --quality 20.0 --comb-detect --decomb --audio 1,2,3,4 --aencoder av_aac
        echo "Encoding finished for $file"
        encoded_vob=$((encoded_vob + 1))

        # Send a notification after each encoding
        send_telegram_notification "Encoding finished for $(basename "$file"). 
Progress: $encoded_vob/$total_vob"

    done

    # Unmount and clean up
    sudo umount "$mount_folder"
    rmdir "$mount_folder"

    # Mark the disk as encoded
    echo "$disk_to_encode" >> "$ENCODED_DISKS_FILE"

    # Send a Telegram notification for completed encoding with the VOB encoding report
    send_telegram_notification "Encoding completed for $disk_to_encode.iso. $encoded_vob/$total_vob VOB files encoded."

    # Update the status
    echo "no_new_disk" > "$STATE_FILE"

else

    # No new disks found
    echo "no_new_disk" > "$STATE_FILE"
    echo "No new disks detected"
    send_telegram_notification "All ISOs have been processed"
fi

echo "Processing completed."

exit
