#!/bin/bash

# Base directory to process
BASE_DIR="/path/to/encoded/ISOs/"
# Destination folder
DESTINATION="/path/to/mp4/destination"
# Log file to keep track of processed subfolders
LOG_FILE="$BASE_DIR/processed_folders_chap.txt"
# Text file containing list of folders to process
FOLDER_LIST="/path/to/iso/known_disks.txt"
# Text file containing list of ready folders
READY_LIST="$BASE_DIR/encoded_disks.txt"

# Telegram credentials
TOKEN="REMOVED"
CHAT_ID="REMOVED"

# Ensure the log file exists
touch "$LOG_FILE"

# Read the ready folders list
if [ -f "$READY_LIST" ]; then
    ready_folders=$(cat "$READY_LIST")
else
    echo "Ready folders list not found: $READY_LIST"
    exit 1
fi

# Read folder list and count total folders
total_folders=$(grep -Fx -f "$READY_LIST" "$FOLDER_LIST" | wc -l)
processed_count=0
skipped_count=0

# Function to send Telegram notifications
send_telegram_notification() {
    local MESSAGE="$1"
    local URL="https://api.telegram.org/bot$TOKEN/sendMessage"
    curl -s -X POST "$URL" -d chat_id="$CHAT_ID" -d text="$MESSAGE" &> /dev/null
}

# Function to process each subfolder
process_subfolder() {
    local SUBFOLDER="$1"
    local SUBFOLDER_NAME=$(basename "$SUBFOLDER")
    local MENU_FILE="${SUBFOLDER_NAME}-MENU.mp4"
    local CONCATENATED_FILE="${SUBFOLDER_NAME}.mp4"

    echo "Processing subfolder: $SUBFOLDER"

    # Prepare a temporary list file for ffmpeg
    local LIST_FILE=$(mktemp)

    # Check for VIDEO_TS.mp4 and VTS_01_0.mp4, and create the MENU file accordingly
    if [ -f "$SUBFOLDER/VIDEO_TS.mp4" ] || [ -f "$SUBFOLDER/VTS_01_0.mp4" ]; then
        echo "Creating $MENU_FILE"
        if [ -f "$SUBFOLDER/VIDEO_TS.mp4" ]; then
            echo "file '$SUBFOLDER/VIDEO_TS.mp4'" >> "$LIST_FILE"
        fi
        if [ -f "$SUBFOLDER/VTS_01_0.mp4" ]; then
            echo "file '$SUBFOLDER/VTS_01_0.mp4'" >> "$LIST_FILE"
        fi
        ffmpeg -y -f concat -safe 0 -i "$LIST_FILE" -c copy "$DESTINATION/$MENU_FILE" &> /dev/null
        rm "$LIST_FILE"
    fi

    # Process VTS files, excluding VTS_01_0.mp4
    local CH_FILES=()
    local VTS_GROUPS=()

    for FILE in "$SUBFOLDER"/VTS_*.mp4; do
        if [ -f "$FILE" ] && [ $(stat -c%s "$FILE") -gt 1048576 ] && [[ "$FILE" != *VTS_01_0.mp4 ]]; then
            CH_FILES+=("$FILE")
            local GROUP_NUM=$(echo "$FILE" | sed -n 's/.*VTS_0\([0-9]\+\)_.*/\1/p')
            if [ -n "$GROUP_NUM" ]; then
                VTS_GROUPS[$GROUP_NUM]=1
            fi
        fi
    done

    # Determine the number of unique VTS groups
    local NUM_GROUPS=${#VTS_GROUPS[@]}

    if [ ${#CH_FILES[@]} -gt 0 ]; then
        if [ "$NUM_GROUPS" -gt 1 ]; then
            # Create chapter files and concatenated file if more than one group exists
            for GROUP_NUM in "${!VTS_GROUPS[@]}"; do
                local CH_GROUP="${SUBFOLDER_NAME}-CH${GROUP_NUM}.mp4"
                local CH_FILES_FOR_GROUP=()

                for FILE in "${CH_FILES[@]}"; do
                    local FILE_GROUP_NUM=$(echo "$FILE" | sed -n 's/.*VTS_0\([0-9]\+\)_.*/\1/p')
                    if [ "$FILE_GROUP_NUM" == "$GROUP_NUM" ]; then
                        CH_FILES_FOR_GROUP+=("$FILE")
                    fi
                done

                if [ ${#CH_FILES_FOR_GROUP[@]} -gt 0 ]; then
                    echo "Concatenating files for group $GROUP_NUM into $CH_GROUP"
                    ffmpeg -y -f concat -safe 0 -i <(printf "file '%s'\n" "${CH_FILES_FOR_GROUP[@]}") -c copy "$DESTINATION/$CH_GROUP" &> /dev/null
                fi
            done

            echo "Concatenating all VTS files into $CONCATENATED_FILE"
            ffmpeg -y -f concat -safe 0 -i <(printf "file '%s'\n" "${CH_FILES[@]}") -c copy "$DESTINATION/$CONCATENATED_FILE" &> /dev/null
        else
            # Only create concatenated file if there is exactly one group
            echo "Concatenating all VTS files into $CONCATENATED_FILE"
            ffmpeg -y -f concat -safe 0 -i <(printf "file '%s'\n" "${CH_FILES[@]}") -c copy "$DESTINATION/$CONCATENATED_FILE" &> /dev/null
        fi
    else
        echo "No VTS files found in $SUBFOLDER"
        skipped_count=$((skipped_count + 1))
    fi

    # Update processed count and notify Telegram
    processed_count=$((processed_count + 1))
    send_telegram_notification "Completed processing subfolder: $SUBFOLDER ($processed_count/$total_folders)"
}

# Export the function to use in find
export -f process_subfolder
export -f send_telegram_notification
export LOG_FILE
export TOKEN
export CHAT_ID
export total_folders
export processed_count
export skipped_count
error_count=0

# Process only folders listed in the ready list
while IFS= read -r FOLDER_NAME; do
    SUBFOLDER="$BASE_DIR/$FOLDER_NAME"
    if [ -d "$SUBFOLDER" ]; then
        if ! grep -Fxq "$SUBFOLDER" "$LOG_FILE"; then
            echo "Processing new subfolder: $SUBFOLDER"
            process_subfolder "$SUBFOLDER"
            echo "$SUBFOLDER" >> "$LOG_FILE"
        else
            echo "Skipping already processed subfolder: $SUBFOLDER"
            skipped_count=$((skipped_count + 1))
        fi
    else
        echo "Subfolder does not exist: $SUBFOLDER"
        error_count=$((error_count + 1))
    fi
done < <(grep -Fx -f "$READY_LIST" "$FOLDER_LIST")

# Notify completion
if [ $processed_count -gt 0 ]; then
done=$(($processed_count + $skipped_count))
send_telegram_notification "Processing complete. $done/$total_folders folders processed. $error_count erreurs."
fi
echo "Processing complete."
exit
