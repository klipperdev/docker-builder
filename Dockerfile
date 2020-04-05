FROM klipper-app-server-dev:7.3.5

LABEL maintainer="François Pluchino <françois.pluchino@klipper.dev>"

# Add PostgreSQL
ENV POSTGRESQL_VERSION 11.3

RUN apk update \
    && apk add --update --no-cache \
        bash \
        su-exec \
        postgresql>=$POSTGRESQL_VERSION \
        postgresql-contrib>=$POSTGRESQL_VERSION \
    && mkdir -p /run/postgresql \
    && chown -R postgres:postgres /run/postgresql \
    && apk del --purge *-dev \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man

# Add PostgreSQL PostGIS
ENV POSTGIS_VERSION 2.5.2

RUN set -ex \
    \
    apk update \
    && apk add --update --no-cache --virtual .fetch-deps \
        ca-certificates \
        openssl \
    \
    && wget -O postgis.tar.gz "https://github.com/postgis/postgis/archive/$POSTGIS_VERSION.tar.gz" \
    && mkdir -p /usr/src/postgis \
    && tar \
        --extract \
        --file postgis.tar.gz \
        --directory /usr/src/postgis \
        --strip-components 1 \
    && rm postgis.tar.gz \
    \
    && apk add --update --no-cache --virtual .build-deps \
        autoconf \
        automake \
        g++ \
        json-c-dev \
        libtool \
        libxml2-dev \
        make \
        perl \
        bison \
        coreutils \
        dpkg-dev dpkg \
        flex \
        libedit-dev \
        libc-dev \
        libxml2-utils \
        libxslt-dev \
        util-linux-dev \
        zlib-dev \
        file \
        postgresql-libs>=$POSTGRESQL_VERSION \
        postgresql-dev>=$POSTGRESQL_VERSION \
    \
    && apk add --update --no-cache --virtual .build-deps-testing \
        --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
        --repository http://dl-cdn.alpinelinux.org/alpine/edge/main \
        gdal-dev \
        geos-dev \
        proj4-dev \
    && cd /usr/src/postgis \
    && ./autogen.sh \
# configure options taken from:
# https://anonscm.debian.org/cgit/pkg-grass/postgis.git/tree/debian/rules?h=jessie
    && ./configure \
#       --with-gui \
    && make \
    && make install \
    && apk add --update --no-cache --virtual .postgis-rundeps \
        json-c \
    && apk add --update --no-cache --force --virtual .postgis-rundeps-testing \
        --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
        geos \
        gdal \
        proj4 \
    && cd / \
    && apk del --force *-dev .fetch-deps .build-deps .build-deps-testing \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man /usr/src/postgis \
    && find /usr/local -name '*.a' -delete

# Configure PostgreSQL
ENV POSTGRES_USER postgres
ENV POSTGRES_PASSWORD postgres
ENV POSTGRES_DATABASE postgres

ENV LANG en_US.utf8
ENV PGDATA /tmp/dbdata

RUN mkdir /docker-entrypoint-initdb.d \
    && mkdir -p "$PGDATA" \
    && chown -R postgres "$PGDATA" \
    && chmod 700 "$PGDATA"

# Add Amazon AWS CLI
RUN apk update \
    && apk add --update --no-cache \
        groff \
        less \
        python \
        py-pip \
    && pip install awscli \
    && apk del --purge *-dev py-pip \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man

# Add utilities
RUN apk update \
    && apk add --update --no-cache \
        openssh-client \
        zip \
    && apk del --purge *-dev \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man

# Add PHP extensions (pecl install ssh2-alpha)
RUN apk update \
    && apk add --no-cache --virtual .build-deps --repository http://dl-cdn.alpinelinux.org/alpine/edge/main \
        autoconf \
        automake \
        libssh2-dev \
    && pecl install ssh2-alpha \
    && apk del --purge .build-deps *-dev \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man

# Entrypoint
COPY init-postgres.sh /usr/local/bin/
COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["postgres"]
