# Development image: the official perl image with cpm. Used by docker-compose.yml;
# not part of the distribution (minil.toml excludes it).
FROM perl:5.44

# The uid and gid of the host user, so that local/, .build/ and the files minil build
# writes are owned by the host user. docker-compose.yml passes the same values.
ARG UID=1000
ARG GID=1000

RUN cpanm --quiet --notest App::cpm \
    && mkdir -p /app/local/.home \
    && chown -R "$UID:$GID" /app/local

# The commands cpm installs into the named volume (minil and so on) come first; the
# image's own PATH stays after them.
ENV PATH=/app/local/bin:$PATH

WORKDIR /app
