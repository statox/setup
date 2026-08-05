#!/usr/bin/env bats

setup() {
    DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    source "${DIR}/../lib/immich_api.sh"
}

@test "parse_failed_job_count sums failed counts across the three ML queues" {
    json='{"smartSearch":{"jobCounts":{"failed":2}},"faceDetection":{"jobCounts":{"failed":1}},"duplicateDetection":{"jobCounts":{"failed":0}},"metadataExtraction":{"jobCounts":{"failed":99}}}'
    run parse_failed_job_count "${json}"
    [ "$status" -eq 0 ]
    [ "$output" -eq 3 ]
}

@test "parse_failed_job_count treats missing queues as zero" {
    json='{"smartSearch":{"jobCounts":{"failed":5}}}'
    run parse_failed_job_count "${json}"
    [ "$output" -eq 5 ]
}

@test "immich_failed_job_count calls GET /api/jobs and parses the result" {
    export IMMICH_URL="https://immich.example.test"
    export IMMICH_API_KEY="test-key"

    curl() {
        echo '{"smartSearch":{"jobCounts":{"failed":4}},"faceDetection":{"jobCounts":{"failed":0}},"duplicateDetection":{"jobCounts":{"failed":0}}}'
    }

    run immich_failed_job_count
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
