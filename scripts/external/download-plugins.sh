#!/bin/bash
set -euo pipefail

PLUGINS_DIR="./plugins"
METADATA_CACHE="./.plugin_cache"
mkdir -p "$PLUGINS_DIR" "$METADATA_CACHE"

download_file() {
  local url=$1
  local dest=$2
  echo "Downloading $url ..."
  curl -fsSL "$url" -o "$dest"
}

verify_checksum() {
  local file=$1
  local type=$2
  local expected=$3

  case "$type" in
    sha256)
      actual=$(sha256sum "$file" | awk '{print $1}')
      ;;
    sha1)
      actual=$(sha1sum "$file" | awk '{print $1}')
      ;;
    md5)
      actual=$(md5sum "$file" | awk '{print $1}')
      ;;
    *)
      echo "Unknown checksum type: $type"
      return 1
      ;;
  esac

  if [ "$actual" != "$expected" ]; then
    echo "Checksum mismatch for $file: expected $expected, got $actual"
    return 1
  fi
  echo "Checksum OK for $file"
}

process_json() {
  local json_path=$1

  # Use jq if available, fallback to error if not.
  if ! command -v jq >/dev/null; then
    echo "jq is required to process JSON metadata. Install jq."
    exit 1
  fi

  local name version download_url checksum_type checksum_value config_url
  name=$(jq -r '.name' "$json_path")
  version=$(jq -r '.version // empty' "$json_path")
  download_url=$(jq -r '.download_url' "$json_path")
  checksum_type=$(jq -r '.checksum.type // empty' "$json_path")
  checksum_value=$(jq -r '.checksum.value // empty' "$json_path")
  config_url=$(jq -r '.config_template_url // empty' "$json_path")

  # Handle dependencies first
  deps=$(jq -c '.dependencies // []' "$json_path")
  if [ "$deps" != "[]" ]; then
    echo "Processing dependencies for $name ..."
    echo "$deps" | jq -c '.[]' | while read -r dep; do
      # Write dep to a temp file and recurse; assuming dependency object can be a mini-json
      tmp=$(mktemp)
      echo "$dep" > "$tmp"
      process_dependency "$tmp"
      rm -f "$tmp"
    done
  fi

  jar_filename="${name}${version:+-$version}.jar"
  dest="$PLUGINS_DIR/$jar_filename"

  if [ -f "$dest" ]; then
    echo "$jar_filename already exists, skipping download."
  else
    # Try primary download, then fallbacks
    success=0
    echo "Installing plugin: $name (version: ${version:-unspecified})"
    urls=("$download_url")
    # Append fallbacks if any
    mapfile -t extra_fallbacks < <(jq -r '.fallbacks[]?' "$json_path")
    urls+=("${extra_fallbacks[@]}")

    for url in "${urls[@]}"; do
      if download_file "$url" "$dest"; then
        success=1
        break
      else
        echo "Failed to download from $url, trying next."
      fi
    done

    if [ "$success" -ne 1 ]; then
      echo "Failed to download $name from all sources."
      return 1
    fi

    # Verify checksum if provided
    if [ -n "$checksum_type" ] && [ -n "$checksum_value" ]; then
      if ! verify_checksum "$dest" "$checksum_type" "$checksum_value"; then
        echo "Removing corrupted download."
        rm -f "$dest"
        return 1
      fi
    fi
  fi

  # Optionally fetch config template
  if [ -n "$config_url" ]; then
    cfg_dest="./config/plugins/${name}.yml"
    mkdir -p "$(dirname "$cfg_dest")"
    if [ ! -f "$cfg_dest" ]; then
      echo "Downloading config template for $name ..."
      download_file "$config_url" "$cfg_dest"
    else
      echo "Config for $name already exists, skipping."
    fi
  fi
}

process_dependency() {
  local dep_json=$1
  # If the dependency object has a download_url and name, treat it like a mini-json
  # Wrap into temp full JSON structure to reuse process_json logic
  process_json <(jq -n --slurpfile dep "$dep_json" '$dep[0]')
}

# Main entry: take inputs as either .jar URLs/paths or .json spec files
for item in "$@"; do
  if [[ "$item" =~ \.json$ ]]; then
    if [ ! -f "$item" ]; then
      echo "Metadata file $item not found."
      continue
    fi
    process_json "$item"
  else
    # Assume it's a direct jar URL or local jar path
    if [[ "$item" =~ ^https?:// ]]; then
      fname=$(basename "$item")
      dest="$PLUGINS_DIR/$fname"
      if [ -f "$dest" ]; then
        echo "$fname already exists, skipping."
      else
        download_file "$item" "$dest"
      fi
    elif [ -f "$item" ]; then
      echo "Copying local jar $item to plugins/"
      cp -n "$item" "$PLUGINS_DIR/"
    else
      echo "Unrecognized plugin specifier: $item"
    fi
  fi
done
