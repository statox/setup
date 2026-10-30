#!/usr/bin/env bash
set -euo pipefail

# Lists every album visible to this API key's user: albums you own plus
# albums shared with you.#
#
# .env must define:
#   API_KEY     - Immich API key (Account Settings > API Keys in the Immich web UI)
#   IMMICH_URL  - Base URL of your Immich instance, matching immich_ui_domain in the role vars

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/.env"

: "${API_KEY:?API_KEY is not set, define it in ${SCRIPT_DIR}/.env}"
: "${IMMICH_URL:?IMMICH_URL is not set, define it in ${SCRIPT_DIR}/.env}"

{
    printf 'NAME\tID\tSHARED_WITH\n'
    curl -fsS "${IMMICH_URL}/api/albums" \
        -H "Accept: application/json" \
        -H "x-api-key: ${API_KEY}" \
        | jq -r '
            .[] | [
                ([.albumUsers[]?.user.name] | if length == 0 then "-" else join(", ") end),
                .albumName,
                .id
            ] | @tsv
        '
} | column -t -s $'\t'
