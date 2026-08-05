#!/usr/bin/env bats

setup() {
    DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    source "${DIR}/../lib/immich_api.sh"
}

@test "parse_pending_job_count sums waiting counts across the three ML queues" {
    json='{"smartSearch":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":2}},"faceDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":1}},"duplicateDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}},"metadataExtraction":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":99}}}'
    run parse_pending_job_count "${json}"
    [ "$status" -eq 0 ]
    [ "$output" -eq 3 ]
}

@test "parse_pending_job_count treats missing queues as zero" {
    json='{"smartSearch":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":5}}}'
    run parse_pending_job_count "${json}"
    [ "$output" -eq 5 ]
}

@test "parse_pending_job_count excludes waiting counts from a paused queue" {
    json='{"smartSearch":{"queueStatus":{"isPaused":true},"jobCounts":{"waiting":10}},"faceDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":2}},"duplicateDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}}}'
    run parse_pending_job_count "${json}"
    [ "$output" -eq 2 ]
}

@test "parse_pending_job_count returns zero when all relevant queues are paused" {
    json='{"smartSearch":{"queueStatus":{"isPaused":true},"jobCounts":{"waiting":10}},"faceDetection":{"queueStatus":{"isPaused":true},"jobCounts":{"waiting":5}},"duplicateDetection":{"queueStatus":{"isPaused":true},"jobCounts":{"waiting":1}}}'
    run parse_pending_job_count "${json}"
    [ "$output" -eq 0 ]
}

@test "immich_pending_job_count calls GET /api/jobs and parses the result" {
    export IMMICH_URL="https://immich.example.test"
    export IMMICH_API_KEY="test-key"

    curl() {
        echo '{"smartSearch":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":4}},"faceDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}},"duplicateDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}}}'
    }

    run immich_pending_job_count
    [ "$output" -eq 4 ]
}

@test "immich_resync_queue PUTs the expected request" {
    export IMMICH_URL="https://immich.example.test"
    export IMMICH_API_KEY="test-key"
    CALL_LOG="$(mktemp)"

    curl() {
        echo "$@" > "${CALL_LOG}"
    }

    immich_resync_queue "smartSearch"

    run cat "${CALL_LOG}"
    [[ "$output" == *"immich.example.test/api/jobs/smartSearch"* ]]
    [[ "$output" == *'force":false'* ]]

    rm -f "${CALL_LOG}"
}
