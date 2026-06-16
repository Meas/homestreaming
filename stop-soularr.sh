#!/bin/sh

cd "$(dirname "$0")" || exit 1;

docker compose rm -fs soularr slskd;