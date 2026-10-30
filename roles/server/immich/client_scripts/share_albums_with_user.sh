#!/usr/bin/env bash
set -euo pipefail

# Shares the albums listed in ALBUM_IDS below with a single user.
#
# Usage: ./share_albums_with_user.sh
#
# .env must define:
#   API_KEY     - Immich API key (Account Settings > API Keys in the Immich web UI)
#   IMMICH_URL  - Base URL of your Immich instance, matching immich_ui_domain in the role vars

SHARED_WITH_USER_ID="533fef6c-e6a9-4acc-a7a0-e653c802e8e2"
SHARED_WITH_ROLE="viewer" # or "editor"

ALBUM_IDS=(
    "231d790d-1b47-4022-8f77-1289eec96c1b"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/.env"

: "${API_KEY:?API_KEY is not set, define it in ${SCRIPT_DIR}/.env}"
: "${IMMICH_URL:?IMMICH_URL is not set, define it in ${SCRIPT_DIR}/.env}"

for album_id in "${ALBUM_IDS[@]}"; do
    echo "Sharing album ${album_id} with ${SHARED_WITH_USER_ID} as ${SHARED_WITH_ROLE}..."
    curl -fsS -X PUT "${IMMICH_URL}/api/albums/${album_id}/users" \
        -H "Content-Type: application/json" \
        -H "x-api-key: ${API_KEY}" \
        -d "$(jq -n --arg userId "${SHARED_WITH_USER_ID}" --arg role "${SHARED_WITH_ROLE}" '{"albumUsers":[{"userId":$userId,"role":$role}]}')" \
        | jq .
done
