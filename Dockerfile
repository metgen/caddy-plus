FROM caddy:2.11.4-builder AS builder

RUN xcaddy build \
  --with github.com/caddy-dns/cloudflare \
  --with github.com/caddyserver/transform-encoder \
  --with github.com/greenpau/caddy-security \
  --with github.com/abiosoft/caddy-exec \
  --with github.com/mholt/caddy-l4

FROM caddy:2.11.4
COPY --from=builder /usr/bin/caddy /usr/bin/caddy