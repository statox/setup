#!/usr/bin/env bash
set -euo pipefail

# .env must define:
#   API_KEY     - Immich API key (Account Settings > API Keys in the Immich web UI)
#   IMMICH_URL  - Base URL of your Immich instance, matching immich_ui_domain in the role vars
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/.env"

: "${API_KEY:?API_KEY is not set, define it in ${SCRIPT_DIR}/.env}"
: "${IMMICH_URL:?IMMICH_URL is not set, define it in ${SCRIPT_DIR}/.env}"

# echo "== Albums =="
# curl -sS "${IMMICH_URL}/api/albums" \
#   -H "Accept: application/json" \
#   -H "x-api-key: ${API_KEY}" \
#   | jq .

# echo "== Users =="
# curl -sS "${IMMICH_URL}/api/users" \
#   -H "Accept: application/json" \
#   -H "x-api-key: ${API_KEY}" \
#   | jq .

ALBUM_ID="af602407-7e79-4a82-bec6-879b373b76d9" # Remise diplones Efrei
SHARED_WITH_USER_ID="59704a89-81dd-45a2-828d-060859f199e9" # Vivi
SHARED_WITH_ROLE="viewer"

: "${ALBUM_ID:?ALBUM_ID is not set}"
: "${SHARED_WITH_USER_ID:?SHARED_WITH_USER_ID is not set}"

echo "== Sharing =="
curl -sS -X PUT "${IMMICH_URL}/api/albums/${ALBUM_ID}/users" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${API_KEY}" \
    -d "$(jq -n --arg userId "${SHARED_WITH_USER_ID}" --arg role "${SHARED_WITH_ROLE}" '{"albumUsers":[{"userId":$userId,"role":$role}]}')" \
    | jq .
