FROM golang:1.13.7-alpine as build

WORKDIR /go/src/github.com/DNSCrypt/dnscrypt-proxy/

ARG ARCHIVE_VERSION=2.1.0
ARG ARCHIVE_URL=https://github.com/DNSCrypt/dnscrypt-proxy/archive/

ENV CGO_ENABLED 0

RUN apk add --no-cache ca-certificates=20191127-r0 curl=7.67.0-r5 \
	&& curl -L "${ARCHIVE_URL}${ARCHIVE_VERSION}.tar.gz" -o /tmp/dnscrypt-proxy.tar.gz \
	&& tar xzf /tmp/dnscrypt-proxy.tar.gz --strip 1 -C /go/src/github.com/DNSCrypt \
	&& go build -v -ldflags="-s -w"

WORKDIR /config

RUN cp -a /go/src/github.com/DNSCrypt/dnscrypt-proxy/example-* ./

COPY dnscrypt-proxy.toml ./

# ----------------------------------------------------------------------------

FROM scratch

COPY --from=build /etc/passwd /etc/group /etc/
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=build /go/src/github.com/DNSCrypt/dnscrypt-proxy/dnscrypt-proxy /usr/local/bin/
COPY --from=build --chown=nobody:nogroup /config /config

USER nobody

ENTRYPOINT ["dnscrypt-proxy", "-config", "/config/dnscrypt-proxy.toml"]

RUN ["dnscrypt-proxy", "-version"]
