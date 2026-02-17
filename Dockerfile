FROM alpine:latest AS builder
RUN apk update && apk add --no-cache \
    build-base \
    flex \
    bison \
    autoconf \
    automake \
    libtool \
    python3-dev
WORKDIR /app
COPY . .
RUN ./autogen.sh && \
    ./configure --with-python && \
    make

FROM alpine:latest
COPY --from=builder /app/main/myanon /bin/myanon
RUN apk update && apk add --no-cache \
    python3 \
    py3-pip \
    py3-faker
CMD ["/bin/sh"]
