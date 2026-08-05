#!/usr/bin/env bash
# Pure decision logic for the immich-ml-orchestrator. Takes no action and
# performs no I/O - only decides what run.sh should do next.

# decide_action PENDING_COUNT DESIRED_COUNT IDLE_SINCE NOW IDLE_GRACE_SECONDS
# Prints one of: scale_up | scale_down | wait_idle | noop
# IDLE_SINCE is an empty string when no idle timer is currently running.
decide_action() {
    local pending_count="$1"
    local desired_count="$2"
    local idle_since="$3"
    local now="$4"
    local idle_grace_seconds="$5"

    if [ "${pending_count}" -gt 0 ]; then
        if [ "${desired_count}" -eq 0 ]; then
            echo "scale_up"
        else
            echo "noop"
        fi
        return 0
    fi

    if [ "${desired_count}" -eq 0 ]; then
        echo "noop"
        return 0
    fi

    if [ -z "${idle_since}" ]; then
        echo "wait_idle"
        return 0
    fi

    local idle_elapsed=$((now - idle_since))
    if [ "${idle_elapsed}" -ge "${idle_grace_seconds}" ]; then
        echo "scale_down"
    else
        echo "wait_idle"
    fi
}

# should_force_scale_down SCALED_UP_SINCE NOW MAX_SCALED_UP_SECONDS
# Cost safety net: prints "true" if the service has been continuously
# scaled up for at least MAX_SCALED_UP_SECONDS, "false" otherwise.
# SCALED_UP_SINCE is an empty string when the service isn't scaled up (or
# we don't know when it started), which never forces a scale-down.
should_force_scale_down() {
    local scaled_up_since="$1"
    local now="$2"
    local max_scaled_up_seconds="$3"

    if [ -z "${scaled_up_since}" ]; then
        echo "false"
        return 0
    fi

    local scaled_up_elapsed=$((now - scaled_up_since))
    if [ "${scaled_up_elapsed}" -ge "${max_scaled_up_seconds}" ]; then
        echo "true"
    else
        echo "false"
    fi
}
