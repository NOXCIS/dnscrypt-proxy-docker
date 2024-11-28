FROM --platform=$BUILDPLATFORM golang:1.23.3-alpine3.20@sha256:c694a4d291a13a9f9d94933395673494fc2cc9d4777b85df3a7e70b3492d3574 AS build

RUN apk upgrade && \
	apk cache clean 

WORKDIR /src

# renovate: datasource=github-tags depName=DNSCrypt/dnscrypt-proxy
ARG DNSCRYPT_PROXY_VERSION=2.1.5


ADD https://github.com/DNSCrypt/dnscrypt-proxy/archive/${DNSCRYPT_PROXY_VERSION}.tar.gz /tmp/dnscrypt-proxy.tar.gz

RUN tar xzf /tmp/dnscrypt-proxy.tar.gz --strip 1

WORKDIR /src/dnscrypt-proxy



# Fetch and tidy Go modules
RUN --mount=type=cache,target=/home/nonroot/.cache/go-build,uid=65532,gid=65532 \
    --mount=type=cache,target=/go/pk

RUN --mount=type=cache,target=/home/nonroot/.cache/go-build,uid=65532,gid=65532 \
    --mount=type=cache,target=/go/pkg 



RUN	go get -u ./... && \	
	go mod tidy && \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH GOARM=${TARGETVARIANT#v} go build -v -ldflags="-s -w" -mod=mod

	WORKDIR /config

	RUN cp -a /src/dnscrypt-proxy/example-* ./
	
	COPY dnscrypt-proxy.toml ./
	
	ARG NONROOT_UID=65532
	ARG NONROOT_GID=65532
	
	RUN addgroup -S -g ${NONROOT_GID} nonroot \
		&& adduser -S -g nonroot -h /home/nonroot -u ${NONROOT_UID} -D -G nonroot nonroot
	
	# ----------------------------------------------------------------------------
	FROM --platform=$BUILDPLATFORM golang:1.23.3-alpine3.20@sha256:c694a4d291a13a9f9d94933395673494fc2cc9d4777b85df3a7e70b3492d3574 AS probe
	
	WORKDIR /src/dnsprobe
	
	
	COPY dnsprobe/ ./
	
	RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH GOARM=${TARGETVARIANT#v} go build -o /usr/local/bin/dnsprobe .
	
	# ----------------------------------------------------------------------------
	FROM scratch
	
	COPY --from=build /src/dnscrypt-proxy/dnscrypt-proxy /usr/local/bin/
	COPY --from=probe /usr/local/bin/dnsprobe /usr/local/bin/
	COPY --from=build /etc/passwd /etc/group /etc/
	COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
	COPY --from=build --chown=nonroot:nonroot /home/nonroot /home/nonroot
	COPY --from=build --chown=nonroot:nonroot /config /config
	
	USER nonroot
	
	ENV PATH=$PATH:/usr/local/bin
	
	ENTRYPOINT [ "dnscrypt-proxy" ]
	
	CMD [ "-config", "/config/dnscrypt-proxy.toml" ]