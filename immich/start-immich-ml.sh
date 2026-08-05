#!/bin/sh

# Run from the repo root so .env and the compose path resolve.
cd "$(dirname "$0")/.." || exit 1;

# --env-file is required: with -f, compose looks for .env next to the compose
# file, so IMMICH_VERSION would silently resolve to an empty string.
docker compose --env-file .env -f immich/remote-ml.yml pull;
docker compose --env-file .env -f immich/remote-ml.yml up -d;
