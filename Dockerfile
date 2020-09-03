FROM alpine:latest as build

ENV USER me
ENV CPPFLAGS "-DACCEPT_USE_OF_DEPRECATED_PROJ_API_H"

RUN apk update \
  && apk --no-cache --update upgrade musl \
  && apk add --no-cache --update --force-overwrite \
  autoconf apk-tools automake curl expat-dev gcc gdal gdal-dev geos-dev \
  git libc-dev libc6-compat libtool libxml2-dev make minizip-dev musl-dev \
  ncurses-dev ncurses-static openssl-dev openssl-libs-static proj-dev \
  readline readline-dev sqlite sqlite-dev tcl wget zlib-dev zlib-static \
  && rm -rf /var/cache/apk/*

RUN curl "https://www.fossil-scm.org/index.html/tarball/fossil-src.tar.gz?name=fossil-src&uuid=trunk" \
  -o fossil-src.tar.gz && tar xf fossil-src.tar.gz && cd fossil-src \
  && ./configure --static --disable-fusefs --with-th1-docs --with-th1-hooks \
  && make && make install

RUN fossil clone https://www.gaia-gis.it/fossil/freexl freexl.fossil \
  && mkdir freexl && cd freexl && fossil open ../freexl.fossil \
  && ./configure && make -j8 && make install

RUN git clone https://git.osgeo.org/gitea/rttopo/librttopo.git \
  && cd librttopo && ./autogen.sh && ./configure && make -j8 && make install

RUN fossil clone https://www.gaia-gis.it/fossil/libspatialite libspatialite.fossil \
  && mkdir libspatialite && cd libspatialite && fossil open ../libspatialite.fossil \
  && ./configure --disable-dependency-tracking --enable-rttopo=yes --enable-proj=yes \
  --enable-geos=yes --enable-gcp=yes --enable-libxml2=yes && make -j8 && make install

RUN fossil clone https://www.gaia-gis.it/fossil/readosm readosm.fossil \
  && mkdir readosm && cd readosm && fossil open ../readosm.fossil \
  && ./configure && make -j8 && make install

RUN fossil clone https://www.gaia-gis.it/fossil/spatialite-tools spatialite-tools.fossil \
  && mkdir spatialite-tools && cd spatialite-tools && fossil open ../spatialite-tools.fossil \
  && ./configure && make -j8 && make install

RUN cp /usr/local/bin/* /usr/bin/ \
  && cp -R /usr/local/lib/* /usr/lib/

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
