#!/usr/bin/env sh

#
# Process plugin config templates to generate the config files with secrets
#

echo "Processing config templates..."
ENV_ARGS=$(jq -r '.["env-args"] | join(" ")' ./app.json) && \
../Zrvr/scripts/internal/replace-env-vars.sh $ENV_ARGS

# Get memory from env variable or use default value of 4GB

if [ -z "$MEMORY" ]; then
    MEMORY=4G
    echo "No memory limit set, using default value of 4GB"
fi
echo "Using memory limit of $MEMORY."

MEM_NUM=$(echo "$MEMORY" | sed 's/[^0-9]//g')

JAR_NAME=$(jq -r '.JAR_NAME' /app/app.json)

find /app \( -not -uid 1001 -o -not -gid 1001 \) -print0 | xargs -0 -r chown 1001:1001

if [ "$MEM_NUM" -gt 12 ]; then
    exec gosu mc:mc mc-server-runner java -Xms${MEMORY} -Xmx${MEMORY} --add-modules=jdk.incubator.vector -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -XX:G1NewSizePercent=40 -XX:G1MaxNewSizePercent=50 -XX:G1HeapRegionSize=16M -XX:G1ReservePercent=15 -jar $JAR_NAME --nogui
else
    exec gosu mc:mc mc-server-runner java -Xms${MEMORY} -Xmx${MEMORY} --add-modules=jdk.incubator.vector -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -jar $JAR_NAME --nogui
fi
