#!/usr/bin/env bash
# Talks to AWS ECS/EC2 via the aws CLI. Requires AWS_REGION, ECS_CLUSTER,
# ECS_SERVICE in the environment; AWS credentials are picked up by the aws
# CLI itself from AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY.

ecs_describe_service_json() {
    aws ecs describe-services \
        --region "${AWS_REGION}" \
        --cluster "${ECS_CLUSTER}" \
        --services "${ECS_SERVICE}"
}

# parse_desired_count DESCRIBE_SERVICES_JSON
# Pure - no I/O.
parse_desired_count() {
    local json="$1"
    echo "${json}" | jq '.services[0].desiredCount'
}

ecs_get_desired_count() {
    parse_desired_count "$(ecs_describe_service_json)"
}

ecs_set_desired_count() {
    local count="$1"
    aws ecs update-service \
        --region "${AWS_REGION}" \
        --cluster "${ECS_CLUSTER}" \
        --service "${ECS_SERVICE}" \
        --desired-count "${count}" \
        > /dev/null
}

ecs_list_task_arns_json() {
    aws ecs list-tasks \
        --region "${AWS_REGION}" \
        --cluster "${ECS_CLUSTER}" \
        --service-name "${ECS_SERVICE}"
}

# parse_task_arn LIST_TASKS_JSON
# Prints the first task ARN, or an empty string if there is none.
# Pure - no I/O.
parse_task_arn() {
    local json="$1"
    echo "${json}" | jq -r '.taskArns[0] // ""'
}

ecs_describe_tasks_json() {
    local task_arn="$1"
    aws ecs describe-tasks \
        --region "${AWS_REGION}" \
        --cluster "${ECS_CLUSTER}" \
        --tasks "${task_arn}"
}

# parse_task_last_status DESCRIBE_TASKS_JSON
# Pure - no I/O.
parse_task_last_status() {
    local json="$1"
    echo "${json}" | jq -r '.tasks[0].lastStatus // ""'
}

# parse_task_eni_id DESCRIBE_TASKS_JSON
# Pure - no I/O.
parse_task_eni_id() {
    local json="$1"
    echo "${json}" | jq -r '
        .tasks[0].attachments[0].details[]
        | select(.name == "networkInterfaceId")
        | .value
    '
}

is_task_running() {
    local task_arn
    task_arn="$(parse_task_arn "$(ecs_list_task_arns_json)")"
    [ -n "${task_arn}" ] && [ "$(parse_task_last_status "$(ecs_describe_tasks_json "${task_arn}")")" = "RUNNING" ]
}

# ecs_wait_for_task_running [MAX_WAIT_SECONDS] [POLL_INTERVAL_SECONDS]
# Polls until a task for the service is RUNNING or the timeout elapses.
# Returns 0 if running, 1 on timeout.
ecs_wait_for_task_running() {
    local max_wait="${1:-180}"
    local interval="${2:-10}"
    local waited=0

    while [ "${waited}" -lt "${max_wait}" ]; do
        if is_task_running; then
            return 0
        fi
        sleep "${interval}"
        waited=$((waited + interval))
    done

    return 1
}

ec2_describe_network_interface_json() {
    local eni_id="$1"
    aws ec2 describe-network-interfaces \
        --region "${AWS_REGION}" \
        --network-interface-ids "${eni_id}"
}

# parse_network_interface_public_ip DESCRIBE_NETWORK_INTERFACES_JSON
# Pure - no I/O.
parse_network_interface_public_ip() {
    local json="$1"
    echo "${json}" | jq -r '.NetworkInterfaces[0].Association.PublicIp // ""'
}

# ecs_get_task_public_ip
# Resolves the service's running task's public IP. Assumes a task is
# already RUNNING (call after ecs_wait_for_task_running succeeds). Echoes
# an empty string if there is no task, no ENI, or no public IP yet.
ecs_get_task_public_ip() {
    local task_arn eni_id
    task_arn="$(parse_task_arn "$(ecs_list_task_arns_json)")"
    if [ -z "${task_arn}" ]; then
        echo ""
        return 0
    fi
    eni_id="$(parse_task_eni_id "$(ecs_describe_tasks_json "${task_arn}")")"
    if [ -z "${eni_id}" ]; then
        echo ""
        return 0
    fi
    parse_network_interface_public_ip "$(ec2_describe_network_interface_json "${eni_id}")"
}
