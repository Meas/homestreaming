#!/bin/sh

# Run from the repo root so .env and the compose path resolve.
cd "$(dirname "$0")/.." || exit 1;

docker compose --env-file .env -f immich/remote-ml.yml down;
