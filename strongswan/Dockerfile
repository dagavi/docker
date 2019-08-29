FROM multiarch/qemu-user-static:x86_64-arm as qemu

FROM arm32v7/alpine as build
COPY --from=qemu /usr/bin/qemu-arm-static /usr/bin
RUN apk update \
    && apk add --no-cache --virtual build-dependencies \
               build-base \
               gmp-dev \
               linux-headers; \
    wget https://download.strongswan.org/strongswan-5.8.0.tar.bz2 \
    && tar xf strongswan-5.8.0.tar.bz2 \
    && cd strongswan-5.8.0 \
    && ./configure --prefix=/usr --sysconfdir=/etc \
    && make && make install \
    && cd .. \
    && rm -rf strongswan-5.8.0.tar.bz2 strongswan-5.8.0 \
    && apk del build-dependencies \
    && apk add --no-cache iptables gmp xl2tpd \
    && rm -rf /var/cache/apk/* /usr/bin/qemu-arm-static
COPY run.sh copy_root /

FROM scratch
COPY --from=build / /
EXPOSE 500/udp 4500/udp
CMD ["/run.sh"]
