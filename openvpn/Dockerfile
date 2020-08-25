FROM alpine

ARG VERSION=2.4.9

RUN apk update \
    && apk add --no-cache --virtual build-dependencies \
               build-base \
               linux-headers \
               openssl-dev \
               lz4-dev \
               lzo-dev \
               linux-pam-dev \
    && wget https://swupdate.openvpn.org/community/releases/openvpn-${VERSION}.tar.gz \
    && tar xf openvpn-${VERSION}.tar.gz \
    && cd openvpn-${VERSION} \
    && ./configure --prefix=/usr --sysconfdir=/etc --enable-x509-alt-username \
    && make && make install \
    && cp -r sample/sample-config-files /usr/share/doc/openvpn/ \
    && cd .. \
    && rm -rf openvpn-${VERSION}.tar.gz openvpn-${VERSION} \
    && apk del build-dependencies \
    && apk add lzo lz4-libs iptables \
    && rm -rf /var/cache/apk/*

COPY run.sh /

EXPOSE 1194/udp

CMD ["/run.sh"]
