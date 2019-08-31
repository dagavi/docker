FROM multiarch/qemu-user-static:x86_64-arm as qemu

# To avoid copy qemu-* we sill make a list with the original files and md5
# We make another list after installation and we will copy all the installed and modified
# files to a new emty image (with correct architecture) to the new base image

FROM arm32v7/alpine as build
COPY --from=qemu /usr/bin/qemu-arm-static /usr/bin
# Generate the initial file list
RUN find / -type f ! -name "list.pre"   ! -path "/proc/*" ! -path "/sys/*" -print0 | xargs -0 md5sum > /list.pre

# Start installation
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
    && rm -rf /var/cache/apk/*
COPY run.sh copy_root /

# Generate post list
RUN find / -type f ! -name "list.pre" ! -name "list.post" ! -path "/proc/*" ! -path "/sys/*" -print0 | xargs -0 md5sum > /list.post
# Copy new an modified files to /nextStage
RUN cd / && mkdir nextStage && diff list.pre list.post | grep "^+" | grep -v "^+++" | cut -d' ' -f3 | xargs -I% cp -R --parents % nextStage/

FROM arm32v7/alpine
COPY --from=build /nextStage /
EXPOSE 500/udp 4500/udp
CMD ["/run.sh"]
