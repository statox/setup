#!/usr/bin/env bats

setup() {
    DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    source "${DIR}/../lib/ecs_api.sh"
}

@test "parse_desired_count reads desiredCount from describe-services output" {
    json='{"services":[{"desiredCount":1}]}'
    run parse_desired_count "${json}"
    [ "$output" -eq 1 ]
}

@test "ecs_get_desired_count calls describe-services and parses the result" {
    export AWS_REGION="eu-west-3"
    export ECS_CLUSTER="test-cluster"
    export ECS_SERVICE="test-service"

    aws() {
        echo '{"services":[{"desiredCount":1}]}'
    }

    run ecs_get_desired_count
    [ "$output" -eq 1 ]
}

@test "ecs_set_desired_count calls update-service with the given count" {
    export AWS_REGION="eu-west-3"
    export ECS_CLUSTER="test-cluster"
    export ECS_SERVICE="test-service"
    CALL_LOG="$(mktemp)"

    aws() {
        echo "$@" > "${CALL_LOG}"
    }

    ecs_set_desired_count 1

    run cat "${CALL_LOG}"
    [[ "$output" == *"update-service"* ]]
    [[ "$output" == *"--desired-count 1"* ]]

    rm -f "${CALL_LOG}"
}

@test "parse_task_arn returns the first task ARN" {
    json='{"taskArns":["arn:aws:ecs:eu-west-3:123:task/test-cluster/abc"]}'
    run parse_task_arn "${json}"
    [ "$output" = "arn:aws:ecs:eu-west-3:123:task/test-cluster/abc" ]
}

@test "parse_task_arn returns empty string when there are no tasks" {
    json='{"taskArns":[]}'
    run parse_task_arn "${json}"
    [ "$output" = "" ]
}

@test "parse_task_last_status reads lastStatus from describe-tasks output" {
    json='{"tasks":[{"lastStatus":"RUNNING"}]}'
    run parse_task_last_status "${json}"
    [ "$output" = "RUNNING" ]
}

@test "parse_task_eni_id extracts the networkInterfaceId attachment detail" {
    json='{"tasks":[{"attachments":[{"details":[{"name":"subnetId","value":"subnet-1"},{"name":"networkInterfaceId","value":"eni-abc123"}]}]}]}'
    run parse_task_eni_id "${json}"
    [ "$output" = "eni-abc123" ]
}

@test "parse_network_interface_public_ip reads Association.PublicIp" {
    json='{"NetworkInterfaces":[{"Association":{"PublicIp":"1.2.3.4"}}]}'
    run parse_network_interface_public_ip "${json}"
    [ "$output" = "1.2.3.4" ]
}

@test "parse_network_interface_public_ip returns empty string when there is no association yet" {
    json='{"NetworkInterfaces":[{}]}'
    run parse_network_interface_public_ip "${json}"
    [ "$output" = "" ]
}

@test "ecs_wait_for_task_running returns success immediately when already running" {
    is_task_running() { return 0; }
    run ecs_wait_for_task_running 30 5
    [ "$status" -eq 0 ]
}

@test "ecs_wait_for_task_running times out when never running" {
    is_task_running() { return 1; }
    run ecs_wait_for_task_running 2 1
    [ "$status" -eq 1 ]
}

@test "ecs_get_task_public_ip resolves the running task's public IP end to end" {
    export AWS_REGION="eu-west-3"
    export ECS_CLUSTER="test-cluster"
    export ECS_SERVICE="test-service"

    aws() {
        case "$*" in
            *"list-tasks"*) echo '{"taskArns":["arn:aws:ecs:eu-west-3:123:task/test-cluster/abc"]}' ;;
            *"describe-tasks"*) echo '{"tasks":[{"attachments":[{"details":[{"name":"networkInterfaceId","value":"eni-abc123"}]}]}]}' ;;
            *"describe-network-interfaces"*) echo '{"NetworkInterfaces":[{"Association":{"PublicIp":"1.2.3.4"}}]}' ;;
        esac
    }

    run ecs_get_task_public_ip
    [ "$output" = "1.2.3.4" ]
}

@test "ecs_get_task_public_ip returns empty string when there is no running task" {
    export AWS_REGION="eu-west-3"
    export ECS_CLUSTER="test-cluster"
    export ECS_SERVICE="test-service"

    aws() {
        case "$*" in
            *"list-tasks"*) echo '{"taskArns":[]}' ;;
        esac
    }

    run ecs_get_task_public_ip
    [ "$output" = "" ]
}
