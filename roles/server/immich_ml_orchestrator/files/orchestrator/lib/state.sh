#!/usr/bin/env bash
# Persists the orchestrator's timers across cron ticks. ECS itself has no
# concept of "idle/scaled-up since a given time", so this small JSON file
# on panda's disk is the only durable state the orchestrator keeps.
#
# Schema: {"idle_since": <epoch seconds or null>, "scaled_up_since": <epoch
# seconds or null>}. idle_since tracks how long the service has had no
# pending ML work (used to decide when to scale down). scaled_up_since
# tracks how long the service has been continuously scaled up (used as a
# cost safety net: force a scale-down if it's been up too long, e.g. the
# NLB target never becomes healthy).

# state_read_idle_since STATE_FILE
# Prints the epoch seconds the idle timer started, or an empty string if
# no timer is running (or the state file doesn't exist yet).
state_read_idle_since() {
    local state_file="$1"
    if [ ! -f "${state_file}" ]; then
        echo ""
        return 0
    fi
    jq -r '.idle_since // ""' "${state_file}"
}

# state_write_idle_since STATE_FILE VALUE
# VALUE is either an epoch-seconds string, or "" to clear the timer.
# Preserves the existing scaled_up_since field.
state_write_idle_since() {
    local state_file="$1"
    local value="$2"
    _state_write "${state_file}" "${value}" "$(state_read_scaled_up_since "${state_file}")"
}

# state_read_scaled_up_since STATE_FILE
# Prints the epoch seconds the service was last scaled up, or an empty
# string if the service isn't currently scaled up (or the state file
# doesn't exist yet).
state_read_scaled_up_since() {
    local state_file="$1"
    if [ ! -f "${state_file}" ]; then
        echo ""
        return 0
    fi
    jq -r '.scaled_up_since // ""' "${state_file}"
}

# state_write_scaled_up_since STATE_FILE VALUE
# VALUE is either an epoch-seconds string, or "" to clear the timer.
# Preserves the existing idle_since field.
state_write_scaled_up_since() {
    local state_file="$1"
    local value="$2"
    _state_write "${state_file}" "$(state_read_idle_since "${state_file}")" "${value}"
}

# _state_write STATE_FILE IDLE_SINCE SCALED_UP_SINCE
# Internal helper: atomically rewrites the whole state file.
_state_write() {
    local state_file="$1"
    local idle_since="$2"
    local scaled_up_since="$3"
    mkdir -p "$(dirname "${state_file}")"
    jq -n \
        --arg idle "${idle_since}" \
        --arg scaled "${scaled_up_since}" \
        '{
            idle_since: (if $idle == "" then null else ($idle | tonumber) end),
            scaled_up_since: (if $scaled == "" then null else ($scaled | tonumber) end)
        }' > "${state_file}"
}
