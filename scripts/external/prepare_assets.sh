#!/bin/bash

set -e

SERVICE="$1"
VERSION="$2"

echo "Preparing assets for service: $SERVICE on branch $BRANCH"

./setup/download-from-papermc.sh $SERVICE $VERSION


echo "✅ Done preparing assets for $SERVICE"
