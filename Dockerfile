FROM lsiobase/alpine:3.8 as buildstage
############## build stage ##############

ARG DAAPD_RELEASE

RUN \
 echo "**** install build packages ****" && \
 apk add --no-cache \
	alsa-lib-dev \
	autoconf \
	automake \
	avahi-dev \
	bash \
	bsd-compat-headers \
	confuse-dev \
	curl \
	curl-dev \
	ffmpeg-dev \
	file \
	flac-dev \
	g++ \
	gcc \
	gettext-dev \
	gnutls-dev \
	gperf \
	json-c-dev \
	libcurl \
	libevent-dev \
	libgcrypt-dev \
	libogg-dev \
	libplist-dev \
	libressl-dev \
	libsodium-dev \
	libtool \
	libunistring-dev \
	libwebsockets-dev \
	make \
	openjdk8-jre-base \
	protobuf-c-dev \
	sqlite-dev \
	taglib-dev \
	tar && \
 apk add --no-cache \
	--repository http://nl.alpinelinux.org/alpine/edge/testing \
	mxml-dev && \
 echo "**** make antlr wrapper ****" && \
 mkdir -p \
	/tmp/source/forked-daapd && \
 echo \
	"#!/bin/bash" > /tmp/source/antlr3 && \
 echo \
	"exec java -cp /tmp/source/antlr-3.4-complete.jar org.antlr.Tool \"\$@\"" >> /tmp/source/antlr3 && \
 chmod a+x /tmp/source/antlr3 && \
 curl -o \
 /tmp/source/antlr-3.4-complete.jar -L \
	http://www.antlr3.org/download/antlr-3.4-complete.jar && \
 echo "**** compile and install antlr3c ****" && \
 curl -o \
 /tmp/libantlr3c-3.4.tar.gz -L \
	https://github.com/antlr/website-antlr3/raw/gh-pages/download/C/libantlr3c-3.4.tar.gz && \
 tar xf /tmp/libantlr3c-3.4.tar.gz  -C /tmp && \
 cd /tmp/libantlr3c-3.4 && \
 ./configure --enable-64bit --prefix=/usr && \
 make && \
 make DESTDIR=/tmp/antlr3c-build install && \
 export LDFLAGS="-L/tmp/antlr3c-build/usr/lib" && \
 export CFLAGS="-I/tmp/antlr3c-build/usr/include" && \
 echo "**** compile forked-daapd ****" && \
 if [ -z ${DAAPD_RELEASE+x} ]; then \
	DAAPD_RELEASE=$(curl -sX GET "https://api.github.com/repos/ejurgensen/forked-daapd/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]'); \
 fi && \
 curl -o \
 /tmp/source/forked.tar.gz -L \
	"https://github.com/ejurgensen/forked-daapd/archive/${DAAPD_RELEASE}.tar.gz" && \
 tar xf /tmp/source/forked.tar.gz -C \
	/tmp/source/forked-daapd --strip-components=1 && \
 export PATH="/tmp/source:$PATH" && \
 cd /tmp/source/forked-daapd && \
 autoreconf -i -v && \
 ./configure \
	--build=$CBUILD \
	--disable-avcodecsend \
	--enable-chromecast \
	--enable-itunes \
	--enable-lastfm \
	--enable-mpd \
	--host=$CHOST \
	--infodir=/usr/share/info \
	--localstatedir=/var \
	--mandir=/usr/share/man \
	--prefix=/usr \
	--sysconfdir=/etc && \
 make && \
 make DESTDIR=/tmp/daapd-build install && \
 mv /tmp/daapd-build/etc/forked-daapd.conf /tmp/daapd-build/etc/forked-daapd.conf.orig
############## runtime stage ##############
FROM lsiobase/alpine:3.8

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="sparklyballs"

RUN \
 echo "**** install runtime packages ****" && \
 apk add --no-cache \
	avahi \
	confuse \
	dbus \
	ffmpeg \
	json-c \
	libcurl \
	libevent \
	libgcrypt \
	libplist \
	libressl \
	libsodium \
	libunistring \
	libwebsockets \
	protobuf-c \
	sqlite \
	sqlite-libs && \
 apk add --no-cache \
	--repository http://nl.alpinelinux.org/alpine/edge/testing \
	mxml

# copy buildstage and local files
COPY --from=buildstage /tmp/daapd-build/ /
COPY --from=buildstage /tmp/antlr3c-build/ /
COPY root/ /

# ports and volumes
EXPOSE 3689
VOLUME /config /music
