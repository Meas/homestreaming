#!/bin/sh
# Cloudflare binds cf_clearance to the IP that solved the challenge, and prowlarr
# keeps it in its DB for 30 days — stale after an exit change, so 1337x answers
# 403 (17-byte "error code: 1020") or stalls the HTTP/2 stream until it is gone.
set -eu
cd "$(dirname "$0")/.."

docker stop prowlarr >/dev/null
sqlite3 prowlarr/config/prowlarr.db "UPDATE IndexerStatus SET Cookies = '{}', InitialFailure = NULL, MostRecentFailure = NULL, EscalationLevel = 0, DisabledTill = NULL;"
docker start prowlarr >/dev/null
echo "cleared cached cf_clearance and failure backoff"
