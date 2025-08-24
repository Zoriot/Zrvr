#!/bin/bash

LATEST_BUILD=$(curl -k -s https://api.papermc.io/v2/projects/$1/versions/$2/builds | \
    jq -r '.builds | map(select(.channel == "default") | .build) | .[-1]')

if [ "$LATEST_BUILD" != "null" ]; then
    JAR_NAME=$1-$2-${LATEST_BUILD}.jar
    PAPERMC_URL="https://api.papermc.io/v2/projects/$1/versions/$2/builds/${LATEST_BUILD}/downloads/${JAR_NAME}"

    cat <<< "$(jq --arg var1 $JAR_NAME '.JAR_NAME |= $var1' ./app.json)" > ./app.json

    # Download the latest Paper version
    curl -k -o $JAR_NAME $PAPERMC_URL
    echo "Download completed"
else
    echo "No stable build for version $2 found :("
fi