#!/bin/sh
# Prowlarr's "Test All Indexers" button from the shell, optionally narrowed to
# the indexers whose names match the arguments. Each Cloudflare-protected one
# costs a ~15s FlareSolverr solve, which also warms its cf_clearance cookie.
set -eu
cd "$(dirname "$0")/.."

KEY=$(sed -n 's:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p' prowlarr/config/config.xml)
API=http://localhost:9696/prowlarr/api/v1
api() { docker exec prowlarr curl -sS --max-time 300 -H "X-Api-Key: $KEY" "$@"; }

until api -fo /dev/null "$API/system/status" 2>/dev/null; do sleep 2; done

indexers=$(api "$API/indexer")
ids=$(printf '%s' "$indexers" | jq -r --args '.[] | . as $i
  | select($ARGS.positional == [] or any($ARGS.positional[];
      . as $f | ($i.name | ascii_downcase) | contains($f | ascii_downcase)))
  | .id' "$@")

for id in $ids; do
    name=$(printf '%s' "$indexers" | jq -r --argjson id "$id" '.[] | select(.id == $id) | .name')
    resp=$(docker exec prowlarr sh -c "curl -sS -H 'X-Api-Key: $KEY' '$API/indexer/$id' -o /tmp/indexer.json &&
        curl -sS --max-time 300 -w '\n%{http_code}' -X POST -H 'X-Api-Key: $KEY' \
            -H 'Content-Type: application/json' --data @/tmp/indexer.json '$API/indexer/test'")
    if [ "$(printf '%s' "$resp" | tail -n1)" = 200 ]; then
        echo "ok   $name"
    else
        echo "FAIL $name — $(printf '%s' "$resp" | sed '$d' | jq -r '[.[].errorMessage] | join("; ")' 2>/dev/null)"
    fi
done
