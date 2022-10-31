FROM gcc:12 as builder
RUN apt-get update && apt-get install -y flex bison 
WORKDIR /app
COPY . .
RUN ./autogen.sh
RUN ./configure
RUN make LDFLAGS="-static"

FROM alpine:3.16.2
COPY --from=builder /app/main/myanon /bin/myanon
CMD ["/bin/sh"]
