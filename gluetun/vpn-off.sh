#!/bin/sh
# Drop the tunnel. This is a kill switch, not a bypass: gluetun's firewall then
# blocks prowlarr and flaresolverr from the internet entirely. Container-to-
# container traffic keeps working, so the *arrs and nginx still reach Prowlarr.
# Bring it back with vpn-shuffle.sh. To run without a VPN at all, start the
# stack from docker-compose.yaml alone.
set -eu

ctl() { docker exec prowlarr curl -fsS --max-time 20 "$@"; }

ctl -X PUT -d '{"status":"stopped"}' http://127.0.0.1:8000/v1/vpn/status
echo
