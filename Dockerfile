FROM caddy:2.10.0-builder AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/caddyserver/transform-encoder \
    --with github.com/greenpau/caddy-security@v1.1.27 \
    --with github.com/abiosoft/caddy-exec

FROM caddy:2.10.0

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
