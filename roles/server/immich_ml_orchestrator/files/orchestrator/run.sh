#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/decide.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/immich_api.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/ecs_api.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/route53_api.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/state.sh"

: "${IMMICH_URL:?IMMICH_URL is not set}"
: "${IMMICH_API_KEY:?IMMICH_API_KEY is not set}"
: "${AWS_REGION:?AWS_REGION is not set}"
: "${ECS_CLUSTER:?ECS_CLUSTER is not set}"
: "${ECS_SERVICE:?ECS_SERVICE is not set}"
: "${ROUTE53_ZONE_ID:?ROUTE53_ZONE_ID is not set}"
: "${ML_DNS_NAME:?ML_DNS_NAME is not set}"
: "${STATE_FILE:?STATE_FILE is not set}"
: "${IDLE_GRACE_SECONDS:?IDLE_GRACE_SECONDS is not set}"
: "${MAX_SCALED_UP_SECONDS:?MAX_SCALED_UP_SECONDS is not set}"

resync_all_queues() {
    immich_resync_queue "smartSearch"
    immich_resync_queue "faceDetection"
    immich_resync_queue "duplicateDetection"
}

run_tick() {
    local failed_count desired_count idle_since scaled_up_since now action

    failed_count="$(immich_failed_job_count)"
    desired_count="$(ecs_get_desired_count)"
    idle_since="$(state_read_idle_since "${STATE_FILE}")"
    scaled_up_since="$(state_read_scaled_up_since "${STATE_FILE}")"
    now="$(date +%s)"

    # Cost safety net: if the service has been continuously scaled up for
    # too long (e.g. the NLB target never becomes healthy, so failed_count
    # never drops and decide_action keeps returning noop forever), force a
    # scale-down instead of leaving Fargate billing to run away unbounded.
    if [ "${desired_count}" -ne 0 ] && [ "$(should_force_scale_down "${scaled_up_since}" "${now}" "${MAX_SCALED_UP_SECONDS}")" = "true" ]; then
        echo "[immich-ml-orchestrator] service has been scaled up for >= ${MAX_SCALED_UP_SECONDS}s without idling out normally, forcing scale-down to cap cost"
        ecs_set_desired_count 0
        state_write_idle_since "${STATE_FILE}" ""
        state_write_scaled_up_since "${STATE_FILE}" ""
        return 0
    fi

    action="$(decide_action "${failed_count}" "${desired_count}" "${idle_since}" "${now}" "${IDLE_GRACE_SECONDS}")"

    case "${action}" in
        scale_up)
            echo "[immich-ml-orchestrator] failed_count=${failed_count}, scaling ECS service up"
            ecs_set_desired_count 1
            if [ -z "${scaled_up_since}" ]; then
                state_write_scaled_up_since "${STATE_FILE}" "${now}"
            fi
            if ecs_wait_for_task_running; then
                local ip
                ip="$(ecs_get_task_public_ip)"
                if [ -n "${ip}" ]; then
                    echo "[immich-ml-orchestrator] task running at ${ip}, updating ${ML_DNS_NAME}"
                    route53_update_record "${ROUTE53_ZONE_ID}" "${ML_DNS_NAME}" "${ip}"
                else
                    echo "[immich-ml-orchestrator] task running but no public IP yet, will retry DNS update next tick"
                fi
            else
                echo "[immich-ml-orchestrator] task not running within timeout, will retry resync next tick"
            fi
            resync_all_queues
            state_write_idle_since "${STATE_FILE}" ""
            ;;
        noop)
            if [ "${failed_count}" -gt 0 ]; then
                echo "[immich-ml-orchestrator] failed_count=${failed_count}, service already scaling up, retrying resync"
                resync_all_queues
            fi
            state_write_idle_since "${STATE_FILE}" ""
            ;;
        wait_idle)
            if [ -z "${idle_since}" ]; then
                echo "[immich-ml-orchestrator] no pending ML work, starting idle timer"
                state_write_idle_since "${STATE_FILE}" "${now}"
            fi
            ;;
        scale_down)
            echo "[immich-ml-orchestrator] idle grace period elapsed, scaling ECS service down"
            ecs_set_desired_count 0
            state_write_idle_since "${STATE_FILE}" ""
            state_write_scaled_up_since "${STATE_FILE}" ""
            ;;
        *)
            echo "[immich-ml-orchestrator] unknown action '${action}' from decide_action" >&2
            return 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tick
fi
