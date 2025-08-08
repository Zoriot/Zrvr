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
COPY --chown=mc:mc Zrvr/scripts/setup/ ./tools/

# Install required tools + Download and configure server
RUN apt-get -y update && apt-get -y install -y jq && rm -rf /var/lib/apt/lists/* && chmod +x \
    ./tools/download-from-papermc.sh && \
    ./tools/download-from-papermc.sh ${TYPE} ${MINECRAFT_VERSION} && \
    echo "eula=true" > eula.txt && chown -R mc:mc /app && \
    chmod +x ./tools/start_server.sh

# TODO ./tools/download-plugins.sh + delete files after execution

USER mc

EXPOSE 25565

ENTRYPOINT ["tools/start_server.sh"]
