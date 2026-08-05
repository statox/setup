#!/usr/bin/env bash
# Talks to AWS Route53 via the aws CLI. AWS credentials are picked up by
# the aws CLI itself from AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY.

# route53_change_batch_json RECORD_NAME IP
# Builds the JSON change-batch body for an UPSERT of an A record. Pure -
# no I/O.
route53_change_batch_json() {
    local record_name="$1"
    local ip="$2"
    jq -n --arg name "${record_name}" --arg ip "${ip}" '
        {
            Changes: [
                {
                    Action: "UPSERT",
                    ResourceRecordSet: {
                        Name: $name,
                        Type: "A",
                        TTL: 30,
                        ResourceRecords: [ { Value: $ip } ]
                    }
                }
            ]
        }
    '
}

# route53_update_record ZONE_ID RECORD_NAME IP
# Upserts RECORD_NAME (an A record) in ZONE_ID to point at IP. No output
# on success. Safe to retry - UPSERT is idempotent.
route53_update_record() {
    local zone_id="$1"
    local record_name="$2"
    local ip="$3"
    aws route53 change-resource-record-sets \
        --hosted-zone-id "${zone_id}" \
        --change-batch "$(route53_change_batch_json "${record_name}" "${ip}")" \
        > /dev/null
}
