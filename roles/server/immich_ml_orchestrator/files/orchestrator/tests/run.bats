#!/usr/bin/env bats

setup() {
    DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"

    export IMMICH_URL="https://immich.example.test"
    export IMMICH_API_KEY="test-key"
    export AWS_REGION="eu-west-3"
    export ECS_CLUSTER="test-cluster"
    export ECS_SERVICE="test-service"
    export ROUTE53_ZONE_ID="Z123EXAMPLE"
    export ML_DNS_NAME="immich-ml.statox.fr"
    export IDLE_GRACE_SECONDS=600
    export MAX_SCALED_UP_SECONDS=7200

    TMP_STATE_DIR="$(mktemp -d)"
    export STATE_FILE="${TMP_STATE_DIR}/state.json"

    source "${DIR}/../run.sh"
}

teardown() {
    rm -rf "${TMP_STATE_DIR}"
}

@test "run_tick scales up, updates DNS, and resyncs queues when ML jobs are pending" {
    curl() {
        if [[ "$*" == *"-X PUT"* ]]; then
            echo "$@" >> "${TMP_STATE_DIR}/resync_calls.log"
        else
            echo '{"smartSearch":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":2}},"faceDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}},"duplicateDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}}}'
        fi
    }
    aws() {
        case "$*" in
            *"describe-services"*) echo '{"services":[{"desiredCount":0}]}' ;;
            *"update-service"*) echo "$*" >> "${TMP_STATE_DIR}/aws_calls.log" ;;
            *"list-tasks"*) echo '{"taskArns":["arn:aws:ecs:eu-west-3:123:task/test-cluster/abc"]}' ;;
            *"describe-tasks"*) echo '{"tasks":[{"lastStatus":"RUNNING","attachments":[{"details":[{"name":"networkInterfaceId","value":"eni-abc123"}]}]}]}' ;;
            *"describe-network-interfaces"*) echo '{"NetworkInterfaces":[{"Association":{"PublicIp":"1.2.3.4"}}]}' ;;
            *"change-resource-record-sets"*) echo "$*" >> "${TMP_STATE_DIR}/route53_calls.log" ;;
        esac
    }
    date() { echo 1000; }

    run run_tick
    [ "$status" -eq 0 ]

    run cat "${TMP_STATE_DIR}/aws_calls.log"
    [[ "$output" == *"update-service"* ]]
    [[ "$output" == *"--desired-count 1"* ]]

    [ -f "${TMP_STATE_DIR}/route53_calls.log" ]
    run cat "${TMP_STATE_DIR}/route53_calls.log"
    [[ "$output" == *"change-resource-record-sets"* ]]
    [[ "$output" == *"Z123EXAMPLE"* ]]

    [ -f "${TMP_STATE_DIR}/resync_calls.log" ]
    resync_calls="$(wc -l < "${TMP_STATE_DIR}/resync_calls.log")"
    [ "${resync_calls}" -eq 3 ]

    idle_since="$(state_read_idle_since "${STATE_FILE}")"
    [ "${idle_since}" = "" ]
}

@test "run_tick starts the idle timer when queues are empty and the service is up" {
    curl() {
        echo '{"smartSearch":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}},"faceDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}},"duplicateDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}}}'
    }
    aws() {
        case "$*" in
            *"describe-services"*) echo '{"services":[{"desiredCount":1}]}' ;;
        esac
    }
    date() { echo 1000; }

    run run_tick
    [ "$status" -eq 0 ]

    idle_since="$(state_read_idle_since "${STATE_FILE}")"
    [ "${idle_since}" = "1000" ]
}

@test "run_tick scales down after the idle grace period elapses" {
    state_write_idle_since "${STATE_FILE}" "100"

    curl() {
        echo '{"smartSearch":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}},"faceDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}},"duplicateDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}}}'
    }
    aws() {
        case "$*" in
            *"describe-services"*) echo '{"services":[{"desiredCount":1}]}' ;;
            *"update-service"*) echo "$*" >> "${TMP_STATE_DIR}/aws_calls.log" ;;
        esac
    }
    date() { echo 1000; }

    run run_tick
    [ "$status" -eq 0 ]

    run cat "${TMP_STATE_DIR}/aws_calls.log"
    [[ "$output" == *"--desired-count 0"* ]]

    idle_since="$(state_read_idle_since "${STATE_FILE}")"
    [ "${idle_since}" = "" ]
}

@test "run_tick records scaled_up_since the first time it scales up" {
    curl() {
        if [[ "$*" == *"-X PUT"* ]]; then
            echo "$@" >> "${TMP_STATE_DIR}/resync_calls.log"
        else
            echo '{"smartSearch":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":2}},"faceDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}},"duplicateDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}}}'
        fi
    }
    aws() {
        case "$*" in
            *"describe-services"*) echo '{"services":[{"desiredCount":0}]}' ;;
            *"update-service"*) echo "$*" >> "${TMP_STATE_DIR}/aws_calls.log" ;;
            *"list-tasks"*) echo '{"taskArns":["arn:aws:ecs:eu-west-3:123:task/test-cluster/abc"]}' ;;
            *"describe-tasks"*) echo '{"tasks":[{"lastStatus":"RUNNING","attachments":[{"details":[{"name":"networkInterfaceId","value":"eni-abc123"}]}]}]}' ;;
            *"describe-network-interfaces"*) echo '{"NetworkInterfaces":[{"Association":{"PublicIp":"1.2.3.4"}}]}' ;;
            *"change-resource-record-sets"*) echo "$*" >> "${TMP_STATE_DIR}/route53_calls.log" ;;
        esac
    }
    date() { echo 1000; }

    run run_tick
    [ "$status" -eq 0 ]

    scaled_up_since="$(state_read_scaled_up_since "${STATE_FILE}")"
    [ "${scaled_up_since}" = "1000" ]
}

@test "run_tick force-scales down once the service has been up longer than MAX_SCALED_UP_SECONDS" {
    state_write_scaled_up_since "${STATE_FILE}" "1000"

    curl() {
        # Backlog never drains: pending_count never drops to 0.
        echo '{"smartSearch":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":2}},"faceDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}},"duplicateDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}}}'
    }
    aws() {
        case "$*" in
            *"describe-services"*) echo '{"services":[{"desiredCount":1}]}' ;;
            *"update-service"*) echo "$*" >> "${TMP_STATE_DIR}/aws_calls.log" ;;
        esac
    }
    date() { echo 8201; } # 1000 + MAX_SCALED_UP_SECONDS(7200) + 1

    run run_tick
    [ "$status" -eq 0 ]

    run cat "${TMP_STATE_DIR}/aws_calls.log"
    [[ "$output" == *"--desired-count 0"* ]]

    scaled_up_since="$(state_read_scaled_up_since "${STATE_FILE}")"
    [ "${scaled_up_since}" = "" ]
}

@test "run_tick does not force-scale down before MAX_SCALED_UP_SECONDS elapses" {
    state_write_scaled_up_since "${STATE_FILE}" "1000"

    curl() {
        if [[ "$*" == *"-X PUT"* ]]; then
            echo "$@" >> "${TMP_STATE_DIR}/resync_calls.log"
        else
            echo '{"smartSearch":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":2}},"faceDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}},"duplicateDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}}}'
        fi
    }
    aws() {
        case "$*" in
            *"describe-services"*) echo '{"services":[{"desiredCount":1}]}' ;;
            *"update-service"*) echo "$*" >> "${TMP_STATE_DIR}/aws_calls.log" ;;
        esac
    }
    date() { echo 8199; } # 1000 + MAX_SCALED_UP_SECONDS(7200) - 1

    run run_tick
    [ "$status" -eq 0 ]

    [ ! -f "${TMP_STATE_DIR}/aws_calls.log" ]

    scaled_up_since="$(state_read_scaled_up_since "${STATE_FILE}")"
    [ "${scaled_up_since}" = "1000" ]
}

@test "run_tick does nothing when there is no pending work and the service is already down" {
    curl() {
        echo '{"smartSearch":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}},"faceDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}},"duplicateDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}}}'
    }
    aws() {
        case "$*" in
            *"describe-services"*) echo '{"services":[{"desiredCount":0}]}' ;;
            *"update-service"*) echo "$*" >> "${TMP_STATE_DIR}/aws_calls.log" ;;
        esac
    }
    date() { echo 1000; }

    run run_tick
    [ "$status" -eq 0 ]
    [ ! -f "${TMP_STATE_DIR}/aws_calls.log" ]
}

@test "run_tick does nothing when the only queue with waiting jobs is paused" {
    curl() {
        echo '{"smartSearch":{"queueStatus":{"isPaused":true},"jobCounts":{"waiting":10}},"faceDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}},"duplicateDetection":{"queueStatus":{"isPaused":false},"jobCounts":{"waiting":0}}}'
    }
    aws() {
        case "$*" in
            *"describe-services"*) echo '{"services":[{"desiredCount":0}]}' ;;
            *"update-service"*) echo "$*" >> "${TMP_STATE_DIR}/aws_calls.log" ;;
        esac
    }
    date() { echo 1000; }

    run run_tick
    [ "$status" -eq 0 ]
    [ ! -f "${TMP_STATE_DIR}/aws_calls.log" ]
}
