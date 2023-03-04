VERSION 0.7

FROM debian:bullseye
LABEL maintainer="Neutron Soutmun <neutron@neutron.in.th>"

debian-builder:
  FROM debian:bullseye
  LABEL maintainer="Neutron Soutmun <neutron@neutron.in.th>"

  RUN mkdir -p /usr/src
  WORKDIR /usr/src

  ENV PATH /usr/lib/ccache:${PATH}
  ENV DEBIAN_FRONTEND=noninteractive

  RUN echo "deb-src https://deb.debian.org/debian bullseye main contrib non-free" | tee /etc/apt/sources.list.d/debian-src.list

  RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update \
      && apt-get install --yes --no-install-recommends \
        build-essential \
        devscripts \
        autoconf \
        automake \
        ccache \
        curl \
        debian-keyring \
        libabsl-dev

clickhouse-cpp-lib:
  FROM +debian-builder
  ARG LIB_VERSION=v2.3.0

  RUN --mount=type=cache,target=/var/cache/apt \
    apt-get install --yes --no-install-recommends \
      cmake \
      git

  RUN git clone https://github.com/ClickHouse/clickhouse-cpp.git

  RUN cd clickhouse-cpp \
    && git checkout "$LIB_VERSION" \
    && cmake . \
    && make \
    && make install

  SAVE ARTIFACT /usr/local/lib/libclickhouse-cpp-lib.so /lib/libclickhouse-cpp-lib.so
  SAVE ARTIFACT /usr/local/include/clickhouse /include/clickhouse

freeradius-deb-src:
  ARG FREERADIUS_DEBIAN_SRC_VERSION=3.0.21+dfsg-2.2+deb11u1

  FROM +debian-builder
  ENV DEBMAIL="Neutron Soutmun <neutron@neutron.in.th>"

  COPY +clickhouse-cpp-lib/lib/libclickhouse-cpp-lib.so /usr/lib/libclickhouse-cpp-lib.so
  COPY +clickhouse-cpp-lib/include/clickhouse /usr/include/clickhouse
  RUN mv /usr/lib/libclickhouse-cpp-lib.so /usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/

  RUN dget https://deb.debian.org/debian/pool/main/f/freeradius/freeradius_${FREERADIUS_DEBIAN_SRC_VERSION}.dsc \
    && ln -sf $(find . -type d | grep "./" | head -n1) freeradius

  RUN --mount=type=cache,target=/var/cache/apt \
    apt-get build-dep --yes freeradius

  WORKDIR /usr/src/freeradius
  COPY src/modules/rlm_sql/drivers/rlm_sql_clickhouse src/modules/rlm_sql/drivers/rlm_sql_clickhouse
  COPY raddb/mods-config/sql/main/clickhouse raddb/mods-config/sql/main/clickhouse
  COPY debian/freeradius-clickhouse.* debian/

  RUN echo "rlm_sql_clickhouse" >> src/modules/rlm_sql/stable
  RUN EDITOR=/bin/true dpkg-source -q --commit . rlm_sql_clickhouse.patch

  RUN cat debian/freeradius-clickhouse.control >> debian/control

  RUN dch --local="sforcenetworks" "Add rlm_sql_clickhouse"

freeradius-deb:
  FROM +freeradius-deb-src

  RUN --mount=type=cache,target=/root/.ccache \
    dpkg-buildpackage -uc -us

  RUN mkdir -p /deb                           \
    && cp -av ../freeradius_*.deb /deb        \
    && cp -av ../libfreeradius3_*.deb /deb    \
    && cp -av ../freeradius-common_*.deb /deb \
    && cp -av ../freeradius-config_*.deb /deb \
    && cp -av ../freeradius-ldap_*.deb /deb   \
    && cp -av ../freeradius-utils_*.deb /deb  \
    && cp -av ../freeradius-clickhouse_*.deb /deb

  SAVE ARTIFACT /deb

freeradius-image:
  ARG FREERADIUS_IMAGE_TAG=3.0.21-dfsg-2.2-deb11u1-sforcenetworks-dev

  FROM debian:bullseye-slim
  ENV DEBIAN_FRONTEND=noninteractive

  COPY +clickhouse-cpp-lib/lib/libclickhouse-cpp-lib.so /usr/lib/libclickhouse-cpp-lib.so
  COPY +freeradius-deb/deb /deb

  RUN apt-get update \
    && apt-get install --yes --no-install-recommends --no-install-suggests \
      freeradius \
      freeradius-config \
      freeradius-ldap \
      freeradius-utils \
    && dpkg -i \
         /deb/freeradius_*.deb        \
         /deb/libfreeradius3_*.deb    \
         /deb/freeradius-common_*.deb \
         /deb/freeradius-config_*.deb \
         /deb/freeradius-ldap_*.deb   \
         /deb/freeradius-utils_*.deb  \
         /deb/freeradius-clickhouse_*.deb \
    && rm -rf /deb \
    && apt-get clean

  SAVE IMAGE --push ghcr.io/sforcenetworks/freeradius:${FREERADIUS_IMAGE_TAG}

test:
  FROM docker:23.0-dind

  RUN apk add --no-cache git bash \
    && git clone https://github.com/bats-core/bats-core.git \
    && cd bats-core \
    && ./install.sh /usr/local

  COPY tests/ /tests

  WORKDIR /tests

  WITH DOCKER \
    --load ghcr.io/sforcenetworks/freeradius:for-test=+freeradius-image \
    --pull yandex/clickhouse-client:21 \
    --pull jwilder/dockerize:latest \
    --compose docker-compose.yml \
    --service freeradius \
    --service clickhouse

    RUN --no-cache ./integration-test.bats
  END
