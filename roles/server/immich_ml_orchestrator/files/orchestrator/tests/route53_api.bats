#!/usr/bin/env bats

setup() {
    DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    source "${DIR}/../lib/route53_api.sh"
}

@test "route53_change_batch_json builds an UPSERT change batch for an A record" {
    run route53_change_batch_json "immich-ml.statox.fr" "1.2.3.4"
    [ "$status" -eq 0 ]

    action="$(echo "${output}" | jq -r '.Changes[0].Action')"
    [ "${action}" = "UPSERT" ]

    name="$(echo "${output}" | jq -r '.Changes[0].ResourceRecordSet.Name')"
    [ "${name}" = "immich-ml.statox.fr" ]

    type="$(echo "${output}" | jq -r '.Changes[0].ResourceRecordSet.Type')"
    [ "${type}" = "A" ]

    value="$(echo "${output}" | jq -r '.Changes[0].ResourceRecordSet.ResourceRecords[0].Value')"
    [ "${value}" = "1.2.3.4" ]
}

@test "route53_update_record calls change-resource-record-sets with the zone id and change batch" {
    export AWS_REGION="eu-west-3"
    CALL_LOG="$(mktemp)"

    aws() {
        echo "$@" > "${CALL_LOG}"
    }

    route53_update_record "Z123EXAMPLE" "immich-ml.statox.fr" "1.2.3.4"

    run cat "${CALL_LOG}"
    [[ "$output" == *"change-resource-record-sets"* ]]
    [[ "$output" == *"--hosted-zone-id Z123EXAMPLE"* ]]
    [[ "$output" == *"immich-ml.statox.fr"* ]]
    [[ "$output" == *"1.2.3.4"* ]]

    rm -f "${CALL_LOG}"
}
