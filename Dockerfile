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
COPY --chown=mc:mc --chmod=+x Zrvr/scripts/internal/ ../Zrvr/scripts/internal/
COPY --chown=mc:mc --chmod=+x Zrvr/scripts/external/ ../Zrvr/scripts/external/

ADD https://github.com/itzg/mc-server-runner/releases/download/1.13.2/mc-server-runner_1.13.2_linux_amd64.tar.gz /tmp/mc-server-runner.tgz

ENV SCRIPTS_CHECKSUM=${CACHE_BUST}
ENV GOSU_VERSION=1.17

RUN apt-get -y update && \
    apt-get install -y jq gettext-base && \
    ../Zrvr/scripts/external//download-from-papermc.sh ${TYPE} ${MINECRAFT_VERSION} && \
    echo "eula=true" > eula.txt && \
    PLUGIN_ARGS=$(jq -r '.["plugins-args"] | join(" ")' ./app.json) && \
    ../Zrvr/scripts/external/download-plugins.sh $PLUGIN_ARGS && \
    set -eux; \
    	savedAptMark="$(apt-mark showmanual)"; \
    	apt-get update; \
    	apt-get install -y --no-install-recommends ca-certificates gnupg wget; \
    	rm -rf /var/lib/apt/lists/*; \
    	\
    	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
    	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
    	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
    	\
    	export GNUPGHOME="$(mktemp -d)"; \
    	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
    	gpgconf --kill all; \
    	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
    	\
    	apt-mark auto '.*' > /dev/null; \
    	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
    	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    	\
    	chmod +x /usr/local/bin/gosu && \
        rm -rf /var/lib/apt/lists/* ./plugin_json/ ../Zrvr/scripts/external/
# Try to run it separate because otherwise it seems not to work
RUN tar -xf /tmp/mc-server-runner.tgz -C /usr/local/bin mc-server-runner && \
    rm /tmp/mc-server-runner.tgz

EXPOSE 25565

ENTRYPOINT ["../Zrvr/scripts/internal/start_server.sh"]

STOPSIGNAL SIGTERM
