#!/bin/bash

# Calculate checksum of all script files
SCRIPTS_CHECKSUM=$(find Zrvr/scripts/ -type f -name "*.sh" -exec sha256sum {} \; | sort | sha256sum | cut -d ' ' -f1)

echo "$SCRIPTS_CHECKSUM"
