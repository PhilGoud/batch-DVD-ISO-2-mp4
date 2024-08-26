#!/bin/bash

DIRECTORY="/path/to/iso"

if [ ! -d "$DIRECTORY" ]; then
    echo "Error: '$DIRECTORY' is not a valid directory."
    exit 1
fi

OUTPUT_FILE="$DIRECTORY/known_disks.txt"

> "$OUTPUT_FILE"

find "$DIRECTORY" -type f -name "*.iso" | while read -r FILE; do
    BASENAME=$(basename "$FILE" .iso)
    echo "$BASENAME" >> "$OUTPUT_FILE"
done

find "$DIRECTORY" -type f -name "*.ISO" | while read -r FILE; do
    BASENAME=$(basename "$FILE" .ISO)
    echo "$BASENAME" >> "$OUTPUT_FILE"
done

echo "List of ISO filenames saved to '$OUTPUT_FILE'."
exit
