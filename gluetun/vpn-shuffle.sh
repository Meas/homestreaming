#!/bin/sh
# Reconnect to a random server from PIA_REGIONS. Prowlarr stays up throughout.
set -eu

# curl lives in prowlarr, which shares gluetun's netns, so :8000 is the control
# server. gluetun itself only ships busybox wget, which cannot PUT.
ctl() { docker exec prowlarr curl -fsS --max-time 20 "$@"; }
API=http://127.0.0.1:8000/v1

before=$(ctl "$API/publicip/ip" | sed -n 's/.*"public_ip":"\([^"]*\)".*/\1/p')
echo "current: ${before:-none}"

ctl -X PUT -d '{"status":"stopped"}' "$API/vpn/status" >/dev/null
ctl -X PUT -d '{"status":"running"}' "$API/vpn/status" >/dev/null

i=0
while [ "$i" -lt 60 ]; do
    ip=$(ctl "$API/publicip/ip" 2>/dev/null | sed -n 's/.*"public_ip":"\([^"]*\)".*/\1/p') || ip=""
    if [ -n "$ip" ] && [ "$ip" != "$before" ]; then
        # geoip routinely mislabels PIA ranges; docker logs gluetun has the real server.
        ctl "$API/publicip/ip" | sed 's/.*"public_ip":"\([^"]*\)".*"country":"\([^"]*\)".*/new: \1 (geoip says \2)/'
        exit 0
    fi
    i=$((i + 1))
    sleep 2
done

echo "timed out waiting for a new IP; check: docker logs gluetun" >&2
exit 1
