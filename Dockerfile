FROM alpine:latest as build

#RUN echo "@edge http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories
#RUN echo "@edge-testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

RUN apk update && \
  apk --no-cache --update upgrade musl && \
  apk add --upgrade --force-overwrite apk-tools && \
  apk add --update --force-overwrite wget gcc make automake libtool autoconf curl git libc-dev sqlite sqlite-dev minizip-dev zlib-dev libxml2-dev proj-dev geos-dev gdal-dev gdal expat-dev readline-dev ncurses-dev readline ncurses-static libc6-compat && \
  rm -rf /var/cache/apk/*

RUN apk update \
    && apk upgrade \
    && apk add --no-cache \
    curl gcc make tcl \
    musl-dev \
    openssl-dev zlib-dev \
    openssl-libs-static zlib-static \
    && curl \
    "https://www.fossil-scm.org/index.html/tarball/fossil-src.tar.gz?name=fossil-src&uuid=trunk" \
    -o fossil-src.tar.gz \
    && tar xf fossil-src.tar.gz \
    && cd fossil-src \
    && ./configure \
    --static \
    --disable-fusefs \
    --with-th1-docs \
    --with-th1-hooks \
    && make \
    && make install

ENV USER me

RUN fossil clone https://www.gaia-gis.it/fossil/freexl freexl.fossil && mkdir freexl && cd freexl && fossil open ../freexl.fossil && ./configure && make -j8 && make install

RUN git clone "https://git.osgeo.org/gitea/rttopo/librttopo.git" && cd librttopo && ./autogen.sh && ./configure && make -j8 && make install

ENV CPPFLAGS "-DACCEPT_USE_OF_DEPRECATED_PROJ_API_H"
RUN fossil clone https://www.gaia-gis.it/fossil/libspatialite libspatialite.fossil && mkdir libspatialite && cd libspatialite && fossil open ../libspatialite.fossil && ./configure --disable-dependency-tracking --enable-rttopo=yes --enable-proj=yes --enable-geos=yes --enable-gcp=yes --enable-libxml2=yes && make -j8 && make install

RUN fossil clone https://www.gaia-gis.it/fossil/readosm readosm.fossil && mkdir readosm && cd readosm && fossil open ../readosm.fossil && ./configure && make -j8 && make install

RUN fossil clone https://www.gaia-gis.it/fossil/spatialite-tools spatialite-tools.fossil && mkdir spatialite-tools && cd spatialite-tools && fossil open ../spatialite-tools.fossil && ./configure && make -j8 && make install

RUN cp /usr/local/bin/* /usr/bin/
RUN cp -R /usr/local/lib/* /usr/lib/

# Create a minimal instance
FROM alpine

# copy libs (maintaining symlinks)
COPY --from=build /usr/lib/ /usr/lib
COPY --from=build /usr/bin/ /usr/bin
COPY --from=build /usr/share/proj/proj.db /usr/share/proj/proj.db

# remove broken symlinks
RUN find -L /usr/lib -maxdepth 1 -type l -delete

# remove directories
RUN find /usr/lib -mindepth 1 -maxdepth 1 -type d -exec rm -r {} \;

# copy binaries
COPY --from=build /usr/bin/spatialite* /usr/bin/

ENTRYPOINT ["spatialite"]
