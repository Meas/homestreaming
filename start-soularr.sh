#!/bin/sh

cd "$(dirname "$0")" || exit 1;
docker compose --profile=soularr-tools up -d;