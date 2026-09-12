#!/bin/sh
# Turn the VPN on, or reroll the exit if it is already on. Prowlarr stays up.
set -eu
cd "$(dirname "$0")/.."

# curl lives in prowlarr, which shares gluetun's netns, so :8000 is the control
# server. gluetun itself only ships busybox wget, which cannot PUT.
ctl() { docker exec prowlarr curl -fsS --max-time 20 "$@"; }
API=http://127.0.0.1:8000/v1
exit_ip() { ctl "$API/publicip/ip" 2>/dev/null | sed -n 's/.*"public_ip":"\([^"]*\)".*/\1/p'; }

running=$(docker ps --filter name=gluetun --format '{{.Names}}' | grep -cx gluetun || true)

before=""
if [ "$running" -eq 1 ]; then
    before=$(exit_ip) || before=""
    echo "current: ${before:-none}"
fi

docker compose -f docker-compose.yaml -f gluetun/compose.yaml up -d

if [ "$running" -eq 1 ]; then
    ctl -X PUT -d '{"status":"stopped"}' "$API/vpn/status" >/dev/null
    ctl -X PUT -d '{"status":"running"}' "$API/vpn/status" >/dev/null
fi

i=0
while [ "$i" -lt 60 ]; do
    sleep 2
    ip=$(exit_ip) || ip=""
    if [ -n "$ip" ]; then
        # geoip routinely mislabels PIA ranges; docker logs gluetun has the real server.
        country=$(ctl "$API/publicip/ip" | sed -n 's/.*"country":"\([^"]*\)".*/\1/p')
        if [ "$ip" = "$before" ]; then
            echo "new: $ip (geoip says $country) — same server, run again to reroll"
        else
            echo "new: $ip (geoip says $country)"
        fi
        exit 0
    fi
    i=$((i + 1))
done

echo "timed out waiting for the tunnel; check: docker logs gluetun" >&2
exit 1
