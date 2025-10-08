#!/bin/bash

# Default settings
FORCE_OVERWRITE=false # Force overwrite is disabled by default

# Function to display script usage
usage() {
  echo "Usage: $0 [-f] <Source Directory for Symlinks> <Destination Directory for Symlinks>"
  echo "  -f : Forces overwrite of existing files or symlinks."
  echo "Example: $0 /path/to/source_dir /path/to/destination_dir"
  echo "Example (with overwrite): $0 -f /path/to/source_dir /path/to/destination_dir"
  exit 1
}

# Parse options
while getopts "f" opt; do
  case $opt in
    f)
      FORCE_OVERWRITE=true
      ;;
    \?) # Unknown option
      usage
      ;;
  esac
done
shift $((OPTIND - 1)) # Remove parsed arguments (options)

# Check the number of remaining arguments
if [ "$#" -ne 2 ]; then
  usage
fi

SOURCE_DIR="$1"
DEST_DIR="$2"

# Check if the source directory for symlinks exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory for symlinks '$SOURCE_DIR' not found."
  exit 1
fi

# If the destination directory does not exist, ask to create it
if [ ! -d "$DEST_DIR" ]; then
  read -p "Destination directory '$DEST_DIR' does not exist. Do you want to create it? (y/N): " confirm
  if [[ "$confirm" =~ ^[yY]$ ]]; then
    mkdir -p "$DEST_DIR"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to create directory '$DEST_DIR'."
      exit 1
    fi
    echo "Created directory '$DEST_DIR'."
  else
    echo "Processing aborted because the destination directory was not created."
    exit 1
  fi
fi

echo "--- Starting Symlink Creation ---"
echo "Source Directory: $SOURCE_DIR"
echo "Destination Directory: $DEST_DIR"

if $FORCE_OVERWRITE; then
  echo "Existing files/links will be overwritten. (-f option enabled)"
else
  echo "Existing files/links will be skipped. (-f option disabled)"
fi
echo "-------------------------------------"

# Create symlinks using find and a while loop
# This safely handles filenames containing spaces or special characters
find "${SOURCE_DIR}" -maxdepth 1 -type f -print0 | while IFS= read -r -d $'\0' file; do
  FILENAME=$(basename "$file")
  DEST_PATH="${DEST_DIR}/${FILENAME}"

  # Check if a file or symlink with the same name already exists
  if [ -e "$DEST_PATH" ]; then
    if $FORCE_OVERWRITE; then # If -f option is enabled
      if [ -L "$DEST_PATH" ]; then # If it's a symlink
        echo "Overwriting: Overwriting existing symlink '$DEST_PATH'."
      elif [ -f "$DEST_PATH" ]; then # If it's a regular file
        echo "Overwriting: Overwriting existing file '$DEST_PATH'."
      else # If it's another type (e.g., directory)
        echo "Skipping: '$DEST_PATH' is not a file or symlink. Cannot overwrite."
        continue # Move to the next file
      fi
      # Create the symlink (force overwrite with -f option)
      ln -s -f "$file" "$DEST_PATH"
      if [ $? -eq 0 ]; then
        echo "Success: $file -> $DEST_PATH"
      else
        echo "Failure: Failed to create symlink for $file."
      fi
    else # If -f option is disabled (default)
      echo "Skipping: ${DEST_PATH} already exists. Skipping because overwrite option (-f) was not specified."
    fi
  else # If it doesn't exist, create a new symlink
    echo "Creating: Creating new symlink '$DEST_PATH'."
    ln -s "$file" "$DEST_PATH"
    if [ $? -eq 0 ]; then
      echo "Success: $file -> $DEST_PATH"
    else
      echo "Failure: Failed to create symlink for $file."
    fi
  fi
done

echo "--- Symlink Creation Complete ---"