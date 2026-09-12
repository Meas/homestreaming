#!/bin/sh
# Start the stack in plain mode: prowlarr and flaresolverr back on app-network,
# exiting on the home IP.
set -eu
cd "$(dirname "$0")/.."

# No --remove-orphans: it would sweep up the profiled services (soularr, slskd).
docker compose up -d
docker rm -f gluetun >/dev/null 2>&1 || true

docker exec prowlarr curl -fsS --max-time 20 https://api.ipify.org |
    sed 's/^/exit IP: /'
echo
