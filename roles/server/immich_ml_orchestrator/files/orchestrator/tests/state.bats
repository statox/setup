#!/usr/bin/env bats

setup() {
    DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    source "${DIR}/../lib/state.sh"
    TMP_STATE_DIR="$(mktemp -d)"
    STATE_FILE="${TMP_STATE_DIR}/state.json"
}

teardown() {
    rm -rf "${TMP_STATE_DIR}"
}

@test "state_read_idle_since returns empty when the file does not exist" {
    run state_read_idle_since "${STATE_FILE}"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "state_write_idle_since then state_read_idle_since round-trips a value" {
    state_write_idle_since "${STATE_FILE}" "1700000000"
    run state_read_idle_since "${STATE_FILE}"
    [ "$output" = "1700000000" ]
}

@test "state_write_idle_since with an empty value clears the timer" {
    state_write_idle_since "${STATE_FILE}" "1700000000"
    state_write_idle_since "${STATE_FILE}" ""
    run state_read_idle_since "${STATE_FILE}"
    [ "$output" = "" ]
}

@test "state_write_idle_since creates the parent directory if missing" {
    NESTED_STATE_FILE="${TMP_STATE_DIR}/nested/dir/state.json"
    state_write_idle_since "${NESTED_STATE_FILE}" "42"
    run state_read_idle_since "${NESTED_STATE_FILE}"
    [ "$output" = "42" ]
}

@test "state_read_scaled_up_since returns empty when the file does not exist" {
    run state_read_scaled_up_since "${STATE_FILE}"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "state_write_scaled_up_since then state_read_scaled_up_since round-trips a value" {
    state_write_scaled_up_since "${STATE_FILE}" "1700000000"
    run state_read_scaled_up_since "${STATE_FILE}"
    [ "$output" = "1700000000" ]
}

@test "state_write_scaled_up_since with an empty value clears the timer" {
    state_write_scaled_up_since "${STATE_FILE}" "1700000000"
    state_write_scaled_up_since "${STATE_FILE}" ""
    run state_read_scaled_up_since "${STATE_FILE}"
    [ "$output" = "" ]
}

@test "state_write_idle_since preserves an existing scaled_up_since" {
    state_write_scaled_up_since "${STATE_FILE}" "1000"
    state_write_idle_since "${STATE_FILE}" "2000"

    run state_read_idle_since "${STATE_FILE}"
    [ "$output" = "2000" ]
    run state_read_scaled_up_since "${STATE_FILE}"
    [ "$output" = "1000" ]
}

@test "state_write_scaled_up_since preserves an existing idle_since" {
    state_write_idle_since "${STATE_FILE}" "2000"
    state_write_scaled_up_since "${STATE_FILE}" "1000"

    run state_read_idle_since "${STATE_FILE}"
    [ "$output" = "2000" ]
    run state_read_scaled_up_since "${STATE_FILE}"
    [ "$output" = "1000" ]
}
