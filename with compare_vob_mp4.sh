#!/bin/bash

# Configuration variables
ISO_FOLDER="/path/to/iso"
OUTPUT_FOLDER="/path/to/encoded"
KNOWN_DISKS_FILE="$OUTPUT_FOLDER/encoded_disks.txt"

# Read known disks
mapfile -t known_disks < "$KNOWN_DISKS_FILE"

echo "Starting comparison of VOB files with MP4 files..."
echo "==================================================="

# Iterate over each known ISO disk
for disk in "${known_disks[@]}"; do
    if [[ -f "$ISO_FOLDER/$disk.iso" ]]; then
        # Mount the ISO temporarily
        mount_folder="/mnt/$disk"
        mkdir -p "$mount_folder"
        sudo mount -o loop "$ISO_FOLDER/$disk.iso" "$mount_folder" &> /dev/null
        
        # Corresponding output folder
        output_subfolder="$OUTPUT_FOLDER/$disk"
        
        # Compare each VOB file in the ISO with the MP4 files in the output folder
        find "$mount_folder" -type f -iname "*.VOB" | while read -r vob_file; do
            # Ignore files named exactly VIDEO_TS.VOB or similar
            filename=$(basename "$vob_file")
            if [[ "$filename" =~ ^VIDEO_TS\.[Vv][Oo][Bb]$ ]]; then
                continue
            fi

            relative_path="${vob_file#$mount_folder/}"
            mp4_file="$output_subfolder/$(basename "${relative_path%.*}").mp4"

            # Check if the MP4 file exists
            if [[ ! -f "$mp4_file" ]]; then
                echo "Missing file: $mp4_file"
            fi
        done

        # Unmount and clean up
        sudo umount "$mount_folder"
        rmdir "$mount_folder"
    else
        echo "ISO not found for disk $disk"
    fi
done

echo "Comparison completed."
exit
