#!/bin/bash

# User-defined variables
root_folder="/path/to/temp/folder"
list_file="$root_folder/encoded_disks.txt"
processed_file="$root_folder/processed_mp4.txt"
destination_folder="/path/to/destination"
min_size=$((1 * 1024 * 1024))  # Minimum file size in bytes (1 MB)
TOKEN="REMOVED"
CHAT_ID="REMOVED"

# Check if list files exist
if [ ! -f "$list_file" ]; then
  echo "The file $list_file does not exist. Please ensure the list file exists."
  exit 1
fi

# Create processed_file if it doesn't exist
touch "$processed_file"

# Function to get the duration of a video in seconds
get_duration() {
  local file="$1"
  duration=$(ffprobe -v quiet -of csv=p=0 -show_entries format=duration "$file" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "Error while retrieving the duration for the file: $file"
    exit 1
  fi
  echo "${duration%.*}"  # Convert to seconds
}

# Function to check if an MP4 file has an audio track
has_audio() {
  local file="$1"
  audio_streams=$(ffprobe -v quiet -select_streams a:0 -show_entries stream=codec_type -of csv=p=0 "$file" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "Error while checking audio tracks for the file: $file"
    exit 1
  fi
  [ "$audio_streams" == "audio" ]
}

# Function to retrieve the audio and video codecs of an MP4 file
get_codecs() {
  local file="$1"
  audio_codec=$(ffprobe -v quiet -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$file" 2>/dev/null)
  video_codec=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$file" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "Error while retrieving codecs for the file: $file"
    exit 1
  fi
  echo "$audio_codec $video_codec"
}

# Function to create a silent file with specified codecs
create_silence() {
  local output="$1"
  local duration="$2"
  local audio_codec="$3"
  local video_codec="$4"

  echo "Creating a silent file: $output with duration $duration seconds, audio codecs: $audio_codec, video codecs: $video_codec."
  ffmpeg -f lavfi -i anullsrc=r=44100:cl=stereo -t "$duration" -c:a "$audio_codec" -q:a 0 -af "volume=0" -f lavfi -i nullsrc=r=1920x1080 -c:v "$video_codec" -t "$duration" -shortest "$output" -y >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Error while creating silent file: $output"
    exit 1
  fi
}

# Function to process a folder containing MP4 files
process_folder() {
  local folder="$1"
  
  # Final MP4 file name, based on folder name
  output_name="$(basename "$folder").mp4"
  list_mp4_file="$folder/list_mp4.txt"

  echo "Processing folder: $folder"
  echo "Creating list file: $list_mp4_file"

  # Remove any previous MP4 list file
  [ -f "$list_mp4_file" ] && rm "$list_mp4_file"

  # Create the list of MP4 files in the specified order
  files=()

  if [ -f "$folder/VIDEO_TS.mp4" ] && [ "$(stat -c%s "$folder/VIDEO_TS.mp4")" -ge "$min_size" ]; then
    if ! has_audio "$folder/VIDEO_TS.mp4"; then
      duration=$(get_duration "$folder/VIDEO_TS.mp4")
      read -r audio_codec video_codec <<< "$(get_codecs "$folder/VIDEO_TS.mp4")"
      echo "VIDEO_TS.mp4 has no audio track. Creating a silent track of $duration seconds with codecs $audio_codec and $video_codec."
      create_silence "$folder/VIDEO_TS_silence.mp4" "$duration" "$audio_codec" "$video_codec"
      echo "file 'VIDEO_TS_silence.mp4'" >> "$list_mp4_file"
    else
      echo "file 'VIDEO_TS.mp4'" >> "$list_mp4_file"
    fi
    files+=("VIDEO_TS.mp4")
  fi

  for i in {1..99}; do
    vts_file=$(printf "VTS_01_%d.mp4" "$i")
    if [ -f "$folder/$vts_file" ] && [ "$(stat -c%s "$folder/$vts_file")" -ge "$min_size" ]; then
      if ! has_audio "$folder/$vts_file"; then
        duration=$(get_duration "$folder/$vts_file")
        read -r audio_codec video_codec <<< "$(get_codecs "$folder/$vts_file")"
        echo "$vts_file has no audio track. Creating a silent track of $duration seconds with codecs $audio_codec and $video_codec."
        create_silence "$folder/${vts_file%.mp4}_silence.mp4" "$duration" "$audio_codec" "$video_codec"
        echo "file '${vts_file%.mp4}_silence.mp4'" >> "$list_mp4_file"
      else
        echo "file '$vts_file'" >> "$list_mp4_file"
      fi
      files+=("$vts_file")
    else
      break
    fi
  done

  # Add other MP4 files in alphabetical order
  for file in $(ls "$folder"/*.mp4 2>/dev/null | grep -v -e "VIDEO_TS.mp4" -e "VTS_01_" | sort); do
    if [ "$(stat -c%s "$file")" -ge "$min_size" ]; then
      if ! has_audio "$file"; then
        duration=$(get_duration "$file")
        read -r audio_codec video_codec <<< "$(get_codecs "$file")"
        echo "$(basename "$file") has no audio track. Creating a silent track of $duration seconds with codecs $audio_codec and $video_codec."
        create_silence "$folder/$(basename "${file%.mp4}_silence.mp4")" "$duration" "$audio_codec" "$video_codec"
        echo "file '$(basename "${file%.mp4}_silence.mp4")'" >> "$list_mp4_file"
      else
        echo "file '$(basename "$file")'" >> "$list_mp4_file"
      fi
      files+=("$(basename "$file")")
    fi
  done

  # Check if there are files to process
  if [ ${#files[@]} -eq 0 ]; then
    echo "No sufficiently large MP4 files found in $folder, skipping the folder."
    return
  fi

  # Concatenate all MP4 files into a single file
  output_path="$destination_folder/$output_name"
  echo "Concatenating MP4 files into: $output_path"
  ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$list_mp4_file" -c copy "$output_path" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Error while concatenating MP4 files into: $output_path"
    exit 1
  fi

  echo "Successfully created $output_name in $destination_folder."

  # Send Telegram notification
  curl -s -X POST https://api.telegram.org/bot$TOKEN/sendMessage -d chat_id=$CHAT_ID -d text="NEW ISO PROCESSED 100%
Successfully concatenated $output_name in $destination_folder." > /dev/null

  # Mark the folder as processed by adding its path to the processed_file
  echo "$folder" >> "$processed_file"
}

# Read processed_file into an array to check already processed folders
mapfile -t processed_list < "$processed_file"

# Read the list_file line by line and process each folder
while IFS= read -r folder || [[ -n "$folder" ]]; do
  # Construct the full path of the folder to process
  full_folder="$root_folder/$folder"

  # Check if the folder exists and hasn't been processed yet
  if [ -d "$full_folder" ]; then
    if [[ " ${processed_list[@]} " =~ " $full_folder " ]]; then
      echo "$folder ok"
    else
      echo "Processing folder: $full_folder"
      process_folder "$full_folder"
    fi
  else
    echo "$folder does not exist"
  fi
done < "$list_file"
exit
