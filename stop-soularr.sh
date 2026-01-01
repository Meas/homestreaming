#!/bin/sh

cd "$(dirname "$0")" || exit 1;

docker compose stop soularr;
docker compose stop slskd;