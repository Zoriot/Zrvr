FROM eclipse-temurin:21

# Allow path specification at build time
ARG APP_PATH=./
ARG MINECRAFT_VERSION=1.21.4
ARG TYPE=paper
# Add cache busting arg
ARG CACHE_BUST=unknown
WORKDIR /app

# Create non-root user
RUN addgroup --system --gid 1001 mc && \
    adduser --system --uid 1001 --ingroup mc mc

# Copy files with appropriate permissions
COPY --chown=mc:mc ${APP_PATH}/ ./
COPY --chown=mc:mc Zrvr/scripts/internal/ ../Zrvr/scripts/internal/
COPY --chown=mc:mc Zrvr/scripts/external/ ../Zrvr/scripts/external/

ADD https://github.com/itzg/mc-server-runner/releases/download/1.13.2/mc-server-runner_1.13.2_linux_amd64.tar.gz /tmp/mc-server-runner.tgz

ENV SCRIPTS_CHECKSUM=${CACHE_BUST}

RUN apt-get -y update && \
    apt-get -y install -y jq gettext-base && \
    chmod +x ../Zrvr/scripts/external/download-from-papermc.sh &&  \
    ../Zrvr/scripts/external//download-from-papermc.sh ${TYPE} ${MINECRAFT_VERSION} && \
    echo "eula=true" > eula.txt && chmod +x ../Zrvr/scripts/external/download-plugins.sh &&  \
    PLUGIN_ARGS=$(jq -r '.["plugins-args"] | join(" ")' ./app.json) && \
    ../Zrvr/scripts/external/download-plugins.sh "$PLUGIN_ARGS" && \
    rm -rf /var/lib/apt/lists/* ./plugin_json/ ../Zrvr/scripts/external/ \
    && chown -R mc:mc /app && \
    chmod +x ../Zrvr/scripts/internal/start_server.sh && chmod +x ../Zrvr/scripts/internal/replace-env-vars.sh &&  \
    tar -xf /tmp/mc-server-runner.tgz -C /usr/local/bin mc-server-runner && rm /tmp/mc-server-runner.tgz && \
    chown -R mc:mc /app

EXPOSE 25565

ENTRYPOINT ["../Zrvr/scripts/internal/start_server.sh"]

STOPSIGNAL SIGTERM
