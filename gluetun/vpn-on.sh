#!/bin/sh
# Start the stack with prowlarr's indexer lookups routed through PIA.
set -eu
cd "$(dirname "$0")/.."

docker compose -f docker-compose.yaml -f gluetun/compose.yaml up -d
echo "waiting for the tunnel..."

i=0
while [ "$i" -lt 60 ]; do
    ip=$(docker exec prowlarr curl -fsS --max-time 5 \
        http://127.0.0.1:8000/v1/publicip/ip 2>/dev/null |
        sed -n 's/.*"public_ip":"\([^"]*\)".*/\1/p') || ip=""
    if [ -n "$ip" ]; then
        echo "exit IP: $ip"
        exit 0
    fi
    i=$((i + 1))
    sleep 3
done

echo "tunnel did not come up; check: docker logs gluetun" >&2
exit 1
