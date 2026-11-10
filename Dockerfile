# Development image: the official perl image with cpm. Used by docker-compose.yml;
# not part of the distribution (minil.toml excludes it).
FROM perl:5.44

# The uid and gid of the host user, so that local/, .build/ and the files minil build
# writes are owned by the host user. docker-compose.yml passes the same values.
ARG UID=1000
ARG GID=1000

RUN cpanm --quiet --notest App::cpm \
    && mkdir -p /app/local \
    && chown "$UID:$GID" /app/local

WORKDIR /app
