#!/usr/bin/env bash
set -euo pipefail

# Usage: ./albums.sh <action>
#
# Actions:
#   list-albums   Write the name and id of every album to albums.json
#   share-albums  Share every album listed in share-albums.json with
#                 SHARED_WITH_USER_ID (share-albums.json is a hand-picked
#                 subset of albums.json's entries)
#
# .env must define:
#   API_KEY               - Immich API key (Account Settings > API Keys in the Immich web UI)
#   IMMICH_URL            - Base URL of your Immich instance, matching immich_ui_domain in the role vars

# Only used by share-albums:
SHARED_WITH_USER_ID="59704a89-81dd-45a2-828d-060859f199e9" # Vivi
SHARED_WITH_ROLE="editor"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/.env"

: "${API_KEY:?API_KEY is not set, define it in ${SCRIPT_DIR}/.env}"
: "${IMMICH_URL:?IMMICH_URL is not set, define it in ${SCRIPT_DIR}/.env}"

ALBUMS_FILE="${SCRIPT_DIR}/albums.json"
SHARE_ALBUMS_FILE="${SCRIPT_DIR}/share-albums.json"

list_albums() {
    curl -fsS "${IMMICH_URL}/api/albums" \
        -H "Accept: application/json" \
        -H "x-api-key: ${API_KEY}" \
        | jq '[.[] | {name, id}]' > "${ALBUMS_FILE}"

    echo "Wrote $(jq 'length' "${ALBUMS_FILE}") album(s) to ${ALBUMS_FILE}"
}

share_albums() {
    : "${SHARED_WITH_USER_ID:?SHARED_WITH_USER_ID is not set, define it at the top of $0}"
    : "${SHARED_WITH_ROLE:?SHARED_WITH_ROLE is not set, define it at the top of $0}"

    if [[ ! -f "${SHARE_ALBUMS_FILE}" ]]; then
        echo "${SHARE_ALBUMS_FILE} does not exist. Create it by filtering entries from ${ALBUMS_FILE}." >&2
        exit 1
    fi

    jq -c '.[]' "${SHARE_ALBUMS_FILE}" | while read -r album; do
        id="$(jq -r '.id' <<< "${album}")"
        name="$(jq -r '.name' <<< "${album}")"

        echo "Sharing album '${name}' (${id}) with ${SHARED_WITH_USER_ID} as ${SHARED_WITH_ROLE}..."
        curl -fsS -X PUT "${IMMICH_URL}/api/albums/${id}/users" \
            -H "Content-Type: application/json" \
            -H "x-api-key: ${API_KEY}" \
            -d "$(jq -n --arg userId "${SHARED_WITH_USER_ID}" --arg role "${SHARED_WITH_ROLE}" '{"albumUsers":[{"userId":$userId,"role":$role}]}')" \
            | jq .
    done
}

action="${1:?Usage: $0 <list-albums|share-albums>}"

case "${action}" in
    list-albums)
        list_albums
        ;;
    share-albums)
        share_albums
        ;;
    *)
        echo "Unknown action '${action}'. Use list-albums or share-albums." >&2
        exit 1
        ;;
esac
