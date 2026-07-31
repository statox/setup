#!/usr/bin/env bash

# Run the immich CLI from a docker container
#
# .env must contain the server url and the api key

source .env

: "${API_KEY:?API_KEY is not set, define it in ${SCRIPT_DIR}/.env}"
: "${IMMICH_URL:?IMMICH_URL is not set, define it in ${SCRIPT_DIR}/.env}"

docker run -it \
    -v "$(pwd)":/import:ro \
    -e IMMICH_INSTANCE_URL="$IMMICH_URL/api" \
    -e IMMICH_API_KEY="$API_KEY"  \
    ghcr.io/immich-app/immich-cli:latest \
    "$@"
