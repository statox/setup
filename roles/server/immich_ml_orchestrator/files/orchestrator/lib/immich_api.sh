#!/usr/bin/env bash
# Talks to the Immich REST API. Requires IMMICH_URL and IMMICH_API_KEY to be
# set in the environment (see the .env sourced by run.sh).

immich_get_jobs_json() {
    curl -sS -f "${IMMICH_URL}/api/jobs" \
        -H "Accept: application/json" \
        -H "x-api-key: ${IMMICH_API_KEY}"
}

# parse_pending_job_count JOBS_JSON
# Sums the "waiting" count of the three ML-dependent queues from the
# GET /api/jobs response - jobCounts.failed is not usable here: Immich's
# job runner catches machine-learning-request errors internally and never
# lets them reach the queue as a real failure, so jobCounts.failed never
# moves off zero even when jobs are failing. jobCounts.waiting does reflect
# real backlog, since jobs sit there until a worker dequeues them. A
# queue's waiting count is excluded from the sum while queueStatus.isPaused
# is true, since nothing will dequeue and process it even if the ML task is
# scaled up. Pure - no I/O.
parse_pending_job_count() {
    local jobs_json="$1"
    echo "${jobs_json}" | jq '
        [.smartSearch, .faceDetection, .duplicateDetection]
        | map(select(.queueStatus.isPaused != true) | (.jobCounts.waiting // 0))
        | add // 0
    '
}

immich_pending_job_count() {
    parse_pending_job_count "$(immich_get_jobs_json)"
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
