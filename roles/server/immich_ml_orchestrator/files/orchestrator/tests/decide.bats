#!/usr/bin/env bats

setup() {
    DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    source "${DIR}/../lib/decide.sh"
}

@test "decide_action: pending work present, service down -> scale_up" {
    run decide_action 3 0 "" 1000 600
    [ "$status" -eq 0 ]
    [ "$output" = "scale_up" ]
}

@test "decide_action: pending work present, service already up -> noop" {
    run decide_action 3 1 "" 1000 600
    [ "$output" = "noop" ]
}

@test "decide_action: no pending work, service down -> noop" {
    run decide_action 0 0 "" 1000 600
    [ "$output" = "noop" ]
}

@test "decide_action: no pending work, service up, no idle timer yet -> wait_idle" {
    run decide_action 0 1 "" 1000 600
    [ "$output" = "wait_idle" ]
}

@test "decide_action: no pending work, service up, idle timer running, grace not elapsed -> wait_idle" {
    run decide_action 0 1 900 1000 600
    [ "$output" = "wait_idle" ]
}

@test "decide_action: no pending work, service up, idle grace exactly elapsed -> scale_down" {
    run decide_action 0 1 400 1000 600
    [ "$output" = "scale_down" ]
}

@test "decide_action: no pending work, service up, idle grace long elapsed -> scale_down" {
    run decide_action 0 1 100 1000 600
    [ "$output" = "scale_down" ]
}

@test "should_force_scale_down: no scaled_up_since -> false" {
    run should_force_scale_down "" 1000 7200
    [ "$status" -eq 0 ]
    [ "$output" = "false" ]
}

@test "should_force_scale_down: elapsed under the cap -> false" {
    run should_force_scale_down 1000 8199 7200
    [ "$output" = "false" ]
}

@test "should_force_scale_down: elapsed exactly at the cap -> true" {
    run should_force_scale_down 1000 8200 7200
    [ "$output" = "true" ]
}

@test "should_force_scale_down: elapsed well past the cap -> true" {
    run should_force_scale_down 1000 100000 7200
    [ "$output" = "true" ]
}
