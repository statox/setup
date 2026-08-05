#!/usr/bin/env bash
# Talks to the Immich REST API. Requires IMMICH_URL and IMMICH_API_KEY to be
# set in the environment (see the .env sourced by run.sh).

immich_get_jobs_json() {
    curl -sS -f "${IMMICH_URL}/api/jobs" \
        -H "Accept: application/json" \
        -H "x-api-key: ${IMMICH_API_KEY}"
}

# parse_failed_job_count JOBS_JSON
# Sums the "failed" count of the three ML-dependent queues from the
# GET /api/jobs response. Pure - no I/O.
parse_failed_job_count() {
    local jobs_json="$1"
    echo "${jobs_json}" | jq '
        (.smartSearch.jobCounts.failed // 0)
        + (.faceDetection.jobCounts.failed // 0)
        + (.duplicateDetection.jobCounts.failed // 0)
    '
}

immich_failed_job_count() {
    parse_failed_job_count "$(immich_get_jobs_json)"
}

# immich_resync_queue QUEUE_NAME
# Requeues missing/failed assets for one queue without reprocessing
# everything (force:false).
immich_resync_queue() {
    local queue_name="$1"
    curl -sS -f -X PUT "${IMMICH_URL}/api/jobs/${queue_name}" \
        -H "Content-Type: application/json" \
        -H "x-api-key: ${IMMICH_API_KEY}" \
        -d '{"command":"start","force":false}' \
        > /dev/null
}
