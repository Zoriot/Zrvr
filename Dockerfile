FROM eclipse-temurin:21

# Allow path specification at build time
ARG APP_PATH=../
ARG MINECRAFT_VERSION=1.21.4
ARG TYPE=paper
WORKDIR /app

# Create non-root user
RUN addgroup --system --gid 1001 mc && \
    adduser --system --uid 1001 --ingroup mc mc

# Copy files with appropriate permissions
COPY --chown=mc:mc ${APP_PATH}/ ./
COPY --chown=mc:mc Zrvr/scripts/internal/ ./tools/
COPY --chown=mc:mc Zrvr/scripts/external/ ./tools-external/

# Install required tools + Download and configure server
RUN apt-get -y update && apt-get -y install -y jq &&  \
    apt-get -y install -y gettext-base && \
    chmod +x ./tools-external/download-from-papermc.sh && \
    ./tools-external/download-from-papermc.sh ${TYPE} ${MINECRAFT_VERSION} && \
    echo "eula=true" > eula.txt && chmod +x ./tools-external/download-plugins.sh &&  \
    ./tools-external/download-plugins.sh ./plugin_json/* && rm -rf /var/lib/apt/lists/* ./plugin_json ./tools-external \
    && chown -R mc:mc /app && \
    chmod +x ./tools/start_server.sh && chmod +x ./tools/replace-env-vars.sh

USER mc

EXPOSE 25565

ENTRYPOINT ["tools/start_server.sh"]
