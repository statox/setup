#!/usr/bin/env bash

set -e

echo "Start backup at $(date)"

# /library is Immich's UPLOAD_LOCATION mounted read-only. It contains the
# original assets plus Immich's own nightly DB dumps (UPLOAD_LOCATION/backups),
# so a single sync backs up both. --delete is intentionally never used: a
# deletion in Immich must never remove the S3 copy.
aws s3 sync /library s3://statox-immich-backup/library/

echo "Backup finished at $(date)"
