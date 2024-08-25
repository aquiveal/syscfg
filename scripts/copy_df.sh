#!/bin/bash

# Get the filename of the first argument
filename="$1"

# Check if a filename was provided
if [ -z "$filename" ]; then
  echo "Error: No filename provided."
  exit 1
fi

# Check if the file exists
if [ ! -f "$filename" ]; then
  echo "Error: File '$filename' not found."
  exit 1
fi

# Extract the base filename without the extension
base_filename="${filename%.srt}"

# Create the new filename with ".default.forced.srt"
new_filename="${base_filename}.default.forced.srt"

# Copy the file with the new name
cp "$filename" "$new_filename"

# Print a success message
echo "File '$filename' copied to '$new_filename'."