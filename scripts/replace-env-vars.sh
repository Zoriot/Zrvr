#!/bin/bash

# Replaces ${VAR} placeholders in all files (recursively) with their environment variable values

set -e

# Check if dry-run mode
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    shift
fi

# Input path
TARGET="$1"

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 [--dry-run] <file-or-directory>"
    exit 1
fi

# Function to safely substitute env vars in a file
process_file() {
    local file="$1"

    # Use temp file to hold transformed content
    tmp=$(mktemp)

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Perform env var substitution
        eval "echo \"$line\"" >> "$tmp"
    done < "$file"

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

# Main logic
if [[ -f "$TARGET" ]]; then
    process_file "$TARGET"
elif [[ -d "$TARGET" ]]; then
    find "$TARGET" -type f | while read -r file; do
        process_file "$file"
    done
else
    echo "Error: '$TARGET' is not a valid file or directory"
    exit 1
fi
