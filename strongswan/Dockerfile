FROM alpine

RUN apk update \
    && apk add --no-cache --virtual build-dependencies \
               build-base \
               gmp-dev \
               linux-headers \
    && wget https://download.strongswan.org/strongswan-5.8.0.tar.bz2 \
    && tar xf strongswan-5.8.0.tar.bz2 \
    && cd strongswan-5.8.0 \
    && ./configure --prefix=/usr --sysconfdir=/etc \
    && make && make install \
    && cd .. \
    && rm -rf strongswan-5.8.0.tar.bz2 strongswan-5.8.0 \
    && apk del build-dependencies \
    && apk add --no-cache iptables gmp \
    && rm -rf /var/cache/apk/*

COPY run.sh copy_root /

EXPOSE 500/udp 4500/udp

CMD ["/run.sh"]
