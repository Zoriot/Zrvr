#!/bin/bash

# Replaces ${VAR} placeholders in all files (recursively) with their environment variable values
set -e

# Check if dry-run mode
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    shift
fi

# Check if any targets provided
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [--dry-run] <file-or-directory> [<file-or-directory>...]"
    exit 1
fi

# Function to safely substitute env vars in a file
process_file() {
    local file="$1"
    local tmp=$(mktemp)

    # Use envsubst to reliably replace environment variables
    envsubst < "$file" > "$tmp"

    if [ "$DRY_RUN" = true ]; then
        echo "=== $file ==="
        cat "$tmp"
        echo
        rm "$tmp"
    else
        mv "$tmp" "$file"
        echo "[✓] Processed: $file"
    fi
}

# Function to process a target (file or directory)
process_target() {
    local TARGET="$1"

    if [[ -f "$TARGET" ]]; then
        process_file "$TARGET"
    elif [[ -d "$TARGET" ]]; then
        # Exclude .jar files (add more extensions as needed: -o -name "*.zip" etc.)
        find "$TARGET" -type f ! -name "*.jar" | while read -r file; do
            process_file "$file"
        done
    else
        echo "Error: '$TARGET' is not a valid file or directory"
    fi
}

# Process all provided targets
for target in "$@"; do
    process_target "$target"
done