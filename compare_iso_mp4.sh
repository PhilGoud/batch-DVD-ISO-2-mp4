#!/bin/bash

# Directories (sanitized)
iso_folder="/path/to/iso"
mp4_folder="/path/to/mp4"

# Ensure both directories exist
if [ ! -d "$iso_folder" ]; then
  echo "Error: $iso_folder is not a valid directory."
  exit 1
fi

if [ ! -d "$mp4_folder" ]; then
  echo "Error: $mp4_folder is not a valid directory."
  exit 1
fi

# Iterate over all iso files in the iso_folder
for iso_file in "$iso_folder"/*.iso "$iso_folder"/*.ISO; do
  if [ ! -e "$iso_file" ]; then
    echo "No ISO files found in $iso_folder."
    exit 1
  fi

  iso_base=$(basename "$iso_file" .iso)
  iso_base=$(basename "$iso_base" .ISO)

  if [ ! -f "$mp4_folder/$iso_base.mp4" ]; then
    echo "Missing MP4 for $iso_file"
    nb_missing=$((nb_missing + 1))
  fi
done

echo "Comparison complete."
echo "$nb_missing are missing"
exit
